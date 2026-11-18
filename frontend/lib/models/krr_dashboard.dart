import 'analytics_dashboard.dart';

class KrrKpi {
  const KrrKpi({
    required this.versions,
    required this.uniqueWorks,
    required this.oivCount,
    required this.balanceHolders,
    required this.delta,
    required this.dkCount,
    required this.lastChanged,
    required this.fillPercent,
  });

  final int versions;
  final int uniqueWorks;
  final int oivCount;
  final int balanceHolders;
  final int? delta;
  final int dkCount;
  final DateTime? lastChanged;
  final double fillPercent;

  factory KrrKpi.fromJson(Map<String, dynamic> json) {
    return KrrKpi(
      versions: _int(json['versions']),
      uniqueWorks: _int(json['unique_works']),
      oivCount: _int(json['oiv_count']),
      balanceHolders: _int(json['balance_holders']),
      delta: json['delta'] == null ? null : _int(json['delta']),
      dkCount: _int(json['dk_count']),
      lastChanged: _dateTime(json['last_changed']),
      fillPercent: (json['fill_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class KrrTrendSeries {
  const KrrTrendSeries({
    this.day = const [],
    this.week = const [],
    this.month = const [],
  });

  final List<AnalyticsCountPoint> day;
  final List<AnalyticsCountPoint> week;
  final List<AnalyticsCountPoint> month;

  List<AnalyticsCountPoint> forGroup(AnalyticsTrendGroupBy groupBy) {
    return switch (groupBy) {
      AnalyticsTrendGroupBy.day => day,
      AnalyticsTrendGroupBy.week => week,
      AnalyticsTrendGroupBy.month => month,
    };
  }

  factory KrrTrendSeries.fromJson(Object? raw) {
    if (raw is List) {
      final points = AnalyticsCountPoint.listFromJson(raw);
      return KrrTrendSeries(day: points, week: points, month: points);
    }
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return KrrTrendSeries(
      day: AnalyticsCountPoint.listFromJson(json['day']),
      week: AnalyticsCountPoint.listFromJson(json['week']),
      month: AnalyticsCountPoint.listFromJson(json['month']),
    );
  }
}

class KrrCharts {
  const KrrCharts({
    required this.created,
    required this.changed,
    required this.oivClass,
    required this.stage,
    required this.district,
    required this.program,
    required this.status,
    required this.year,
    required this.activation,
  });

  final KrrTrendSeries created;
  final KrrTrendSeries changed;
  final List<AnalyticsCountPoint> oivClass;
  final List<AnalyticsCountPoint> stage;
  final List<AnalyticsCountPoint> district;
  final List<AnalyticsCountPoint> program;
  final List<AnalyticsCountPoint> status;
  final List<AnalyticsCountPoint> year;
  final List<AnalyticsCountPoint> activation;

  factory KrrCharts.fromJson(Map<String, dynamic> json) {
    List<AnalyticsCountPoint> points(String key) =>
        AnalyticsCountPoint.listFromJson(json[key]);
    return KrrCharts(
      created: KrrTrendSeries.fromJson(json['created']),
      changed: KrrTrendSeries.fromJson(json['changed']),
      oivClass: points('oiv_class'),
      stage: points('stage'),
      district: points('district'),
      program: points('program'),
      status: points('status'),
      year: points('year'),
      activation: points('activation'),
    );
  }
}

class KrrDashboardRecords {
  const KrrDashboardRecords({
    required this.items,
    required this.total,
    required this.limit,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int limit;

  bool get hasMore => items.length < total;

  factory KrrDashboardRecords.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return KrrDashboardRecords(
      items: [
        for (final item in raw is List ? raw : const [])
          if (item is Map<String, dynamic>) item,
      ],
      total: _int(json['total']),
      limit: _int(json['limit']),
    );
  }
}

class KrrDashboard {
  const KrrDashboard({
    required this.snapshotDate,
    required this.fetchedAt,
    required this.title,
    required this.totalCount,
    required this.filteredCount,
    required this.dateColumn,
    required this.columns,
    required this.dateBounds,
    required this.kpi,
    required this.charts,
    required this.records,
  });

  final DateTime? snapshotDate;
  final DateTime fetchedAt;
  final String title;
  final int totalCount;
  final int filteredCount;
  final String dateColumn;
  final List<AnalyticsColumn> columns;
  final Map<String, AnalyticsDateBounds> dateBounds;
  final KrrKpi kpi;
  final KrrCharts charts;
  final KrrDashboardRecords records;

  factory KrrDashboard.fromJson(Map<String, dynamic> json) {
    final boundsRaw = json['date_bounds'];
    final bounds = <String, AnalyticsDateBounds>{};
    if (boundsRaw is Map) {
      for (final entry in boundsRaw.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final parsed = AnalyticsDateBounds.fromJson(value);
          if (parsed != null) bounds[entry.key.toString()] = parsed;
        }
      }
    }
    final columnsRaw = json['columns'];
    return KrrDashboard(
      snapshotDate: _dateTime(json['snapshot_date']),
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      title: json['title'] as String? ?? 'Версии работ КРР МР',
      totalCount: _int(json['total_count']),
      filteredCount: _int(json['filtered_count']),
      dateColumn: json['date_column'] as String? ?? '',
      columns: [
        for (final item in columnsRaw is List ? columnsRaw : const [])
          if (item is Map<String, dynamic>) AnalyticsColumn.fromJson(item),
      ],
      dateBounds: bounds,
      kpi: KrrKpi.fromJson(
        json['kpi'] is Map<String, dynamic>
            ? json['kpi'] as Map<String, dynamic>
            : const {},
      ),
      charts: KrrCharts.fromJson(
        json['charts'] is Map<String, dynamic>
            ? json['charts'] as Map<String, dynamic>
            : const {},
      ),
      records: KrrDashboardRecords.fromJson(
        json['records'] is Map<String, dynamic>
            ? json['records'] as Map<String, dynamic>
            : const {},
      ),
    );
  }
}

int _int(Object? raw) => (raw as num?)?.toInt() ?? 0;

DateTime? _dateTime(Object? raw) =>
    raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;
