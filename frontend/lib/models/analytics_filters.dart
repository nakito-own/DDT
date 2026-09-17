import 'package:equatable/equatable.dart';

import '../models/analytics_dashboard.dart';

class AnalyticsFilters extends Equatable {
  const AnalyticsFilters({
    this.dateColumnKey,
    this.periodStart,
    this.periodEnd,
    this.selectedValues = const {},
    this.queries = const {},
  });

  final String? dateColumnKey;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final Map<String, Set<String>> selectedValues;
  final Map<String, String> queries;

  bool get hasPeriod => periodStart != null || periodEnd != null;

  bool get hasColumnFilters =>
      selectedValues.values.any((values) => values.isNotEmpty) ||
      queries.values.any((query) => query.trim().isNotEmpty);

  bool get isActive => hasPeriod || hasColumnFilters || dateColumnKey != null;

  String resolvedDateColumn(List<AnalyticsColumn> columns) {
    if (dateColumnKey != null &&
        columns.any((column) => column.key == dateColumnKey)) {
      return dateColumnKey!;
    }
    for (final hint in [
      'Дата создания',
      'Дата закрытия',
      'Дата последнего обновления',
    ]) {
      for (final column in columns.where(
        (item) => item.isDate && !item.isFilterIgnored,
      )) {
        if (column.key == hint) return column.key;
      }
    }
    final firstDate = columns.where(
      (column) => column.isDate && !column.isFilterIgnored,
    );
    return firstDate.isEmpty ? '' : firstDate.first.key;
  }

  AnalyticsFilters copyWith({
    String? Function()? dateColumnKey,
    DateTime? Function()? periodStart,
    DateTime? Function()? periodEnd,
    Map<String, Set<String>>? selectedValues,
    Map<String, String>? queries,
  }) {
    return AnalyticsFilters(
      dateColumnKey: dateColumnKey != null ? dateColumnKey() : this.dateColumnKey,
      periodStart: periodStart != null ? periodStart() : this.periodStart,
      periodEnd: periodEnd != null ? periodEnd() : this.periodEnd,
      selectedValues: selectedValues ?? this.selectedValues,
      queries: queries ?? this.queries,
    );
  }

  AnalyticsFilters toggleValue(String columnKey, String valueKey) {
    final current = {...(selectedValues[columnKey] ?? <String>{})};
    if (!current.add(valueKey)) {
      current.remove(valueKey);
    }
    final next = Map<String, Set<String>>.from(selectedValues);
    if (current.isEmpty) {
      next.remove(columnKey);
    } else {
      next[columnKey] = current;
    }
    return copyWith(selectedValues: next);
  }

  AnalyticsFilters setQuery(String columnKey, String query) {
    final next = Map<String, String>.from(queries);
    if (query.trim().isEmpty) {
      next.remove(columnKey);
    } else {
      next[columnKey] = query;
    }
    return copyWith(queries: next);
  }

  bool matches(AnalyticsTicket ticket, List<AnalyticsColumn> columns) {
    if (hasPeriod) {
      final date = ticket.dateValue(resolvedDateColumn(columns));
      if (date == null) return false;
      final day = DateTime(date.year, date.month, date.day);
      if (periodStart != null &&
          day.isBefore(
            DateTime(periodStart!.year, periodStart!.month, periodStart!.day),
          )) {
        return false;
      }
      if (periodEnd != null &&
          day.isAfter(
            DateTime(periodEnd!.year, periodEnd!.month, periodEnd!.day),
          )) {
        return false;
      }
    }

    for (final entry in selectedValues.entries) {
      if (entry.value.isEmpty) continue;
      final field = ticket.fieldValue(entry.key);
      if (!entry.value.contains(field)) return false;
    }

    for (final entry in queries.entries) {
      final query = entry.value.trim().toLowerCase();
      if (query.isEmpty) continue;
      if (!ticket.fieldValue(entry.key).toLowerCase().contains(query)) {
        return false;
      }
    }
    return true;
  }

  @override
  List<Object?> get props => [
    dateColumnKey,
    periodStart,
    periodEnd,
    selectedValues,
    queries,
  ];
}
