import '../models/analytics_dashboard.dart';
import '../models/analytics_filters.dart';

const _statusOrder = [
  'Назначено',
  'В процессе',
  'Ожидание действий от клиента',
  'Завершено',
];

const _monthsRu = [
  'янв',
  'фев',
  'мар',
  'апр',
  'май',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];

class AnalyticsAggregator {
  const AnalyticsAggregator._();

  static AnalyticsDashboard filter(
    AnalyticsDashboard source,
    AnalyticsFilters filters,
  ) {
    if (source.applications.isEmpty) return source;
    final tickets = source.applications
        .where((ticket) => filters.matches(ticket, source.columns))
        .toList();
    final unfiltered = !filters.hasPeriod && !filters.hasColumnFilters;

    final dateKey = filters.resolvedDateColumn(source.columns);
    return AnalyticsDashboard(
      spreadsheetId: source.spreadsheetId,
      sheetName: source.sheetName,
      fetchedAt: source.fetchedAt,
      kpis: _kpis(
        tickets,
        sheetTotal: unfiltered ? source.kpis.sheetTotal : null,
        sheetWaitingLeft: unfiltered ? source.kpis.sheetWaitingLeft : null,
      ),
      series: _series(tickets, dateKey: dateKey),
      recent: _recent(tickets, dateKey: dateKey),
      applications: tickets,
      columns: source.columns,
    );
  }

  static AnalyticsKpis _kpis(
    List<AnalyticsTicket> tickets, {
    int? sheetTotal,
    int? sheetWaitingLeft,
  }) {
    final buckets = <String, int>{};
    var resolved = 0;
    var confirmed = 0;
    final closeDays = <int>[];

    for (final ticket in tickets) {
      final bucket = ticket.statusBucket ?? 'Другое';
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
      if (ticket.resolved == true) resolved += 1;
      if (ticket.userConfirmed == true) confirmed += 1;
      final created = ticket.createdAt;
      final closed = ticket.closedAt;
      if (created != null && closed != null && !closed.isBefore(created)) {
        closeDays.add(closed.difference(created).inDays);
      }
    }

    final assigned = buckets['Назначено'] ?? 0;
    final inProgress = buckets['В процессе'] ?? 0;
    final waiting = buckets['Ожидание действий от клиента'] ?? 0;
    final completed = buckets['Завершено'] ?? 0;
    final avgClose = closeDays.isEmpty
        ? null
        : (closeDays.reduce((a, b) => a + b) / closeDays.length);

    return AnalyticsKpis(
      total: tickets.length,
      assigned: assigned,
      inProgress: inProgress,
      waitingCustomer: waiting,
      completed: completed,
      open: assigned + inProgress + waiting,
      resolved: resolved,
      unresolved: tickets.length - resolved,
      userConfirmed: confirmed,
      avgCloseDays: avgClose == null ? null : (avgClose * 10).round() / 10,
      sheetTotal: sheetTotal,
      sheetWaitingLeft: sheetWaitingLeft,
    );
  }

  static AnalyticsSeries _series(
    List<AnalyticsTicket> tickets, {
    String dateKey = '',
  }) {
    final buckets = <String, int>{};
    for (final ticket in tickets) {
      final bucket = ticket.statusBucket ?? 'Другое';
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }

    final status = [
      for (final label in _statusOrder)
        if ((buckets[label] ?? 0) > 0)
          AnalyticsCountPoint(label: label, value: buckets[label]!),
      for (final entry in buckets.entries)
        if (!_statusOrder.contains(entry.key))
          AnalyticsCountPoint(label: entry.key, value: entry.value),
    ];

    final weekly = <DateTime, int>{};
    final labels = <DateTime, String>{};
    for (final ticket in tickets) {
      final created = ticket.dateValue(dateKey.isEmpty ? null : dateKey);
      if (created == null) continue;
      final start = DateTime(created.year, created.month, created.day)
          .subtract(Duration(days: created.weekday - 1));
      weekly[start] = (weekly[start] ?? 0) + 1;
      labels[start] = _weekLabel(start);
    }
    final weeks = weekly.keys.toList()..sort();

    return AnalyticsSeries(
      status: status,
      type: _count(tickets.map((ticket) => ticket.type)),
      block: _count(tickets.map((ticket) => ticket.block)),
      category: _count(tickets.map((ticket) => ticket.category), limit: 12),
      topics: _count(tickets.map((ticket) => ticket.topicLabel), limit: 12),
      createdWeekly: [
        for (final start in weeks)
          AnalyticsCountPoint(label: labels[start]!, value: weekly[start]!),
      ],
    );
  }

  static List<AnalyticsTicket> _recent(
    List<AnalyticsTicket> tickets, {
    String dateKey = '',
  }) {
    final sorted = [...tickets]
      ..sort((left, right) {
        final leftDate =
            left.dateValue(dateKey.isEmpty ? null : dateKey) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final rightDate =
            right.dateValue(dateKey.isEmpty ? null : dateKey) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final byDate = rightDate.compareTo(leftDate);
        if (byDate != 0) return byDate;
        return right.ticketId.compareTo(left.ticketId);
      });
    return sorted.take(12).toList();
  }

  static List<AnalyticsCountPoint> _count(
    Iterable<String?> values, {
    int? limit,
  }) {
    final counts = <String, int>{};
    for (final value in values) {
      final label = value?.trim() ?? '';
      if (label.isEmpty) continue;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final sliced = limit == null ? entries : entries.take(limit);
    return [
      for (final entry in sliced)
        AnalyticsCountPoint(label: entry.key, value: entry.value),
    ];
  }

  static String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${_monthsRu[start.month - 1]}';
    }
    return '${start.day} ${_monthsRu[start.month - 1]} – ${end.day} ${_monthsRu[end.month - 1]}';
  }
}
