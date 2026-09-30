List<Map<String, dynamic>> _maps(Object? raw) =>
    (raw as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

Map<String, dynamic> _map(Object? raw) =>
    raw is Map<String, dynamic> ? raw : const {};

List<int> _ints(Object? raw) => [
  for (final value in raw as List<dynamic>? ?? const [])
    (value as num?)?.toInt() ?? 0,
];

List<String> _strings(Object? raw) => [
  for (final value in raw as List<dynamic>? ?? const []) value.toString(),
];

double? _double(Object? raw) => (raw as num?)?.toDouble();

int _int(Object? raw) => (raw as num?)?.toInt() ?? 0;

DateTime? _dateTime(Object? raw) =>
    raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;

class AnalyticsColumnOption {
  const AnalyticsColumnOption({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;

  factory AnalyticsColumnOption.fromJson(Map<String, dynamic> json) {
    return AnalyticsColumnOption(
      key: json['key'] as String? ?? json['label'] as String? ?? '',
      label: json['label'] as String? ?? '',
      count: _int(json['value']),
    );
  }
}

class AnalyticsColumn {
  const AnalyticsColumn({
    required this.key,
    required this.label,
    required this.kind,
    this.computed = false,
    this.options = const [],
  });

  final String key;
  final String label;
  final String kind;
  final bool computed;
  final List<AnalyticsColumnOption> options;

  bool get isDate => kind == 'date';

  factory AnalyticsColumn.fromJson(Map<String, dynamic> json) {
    return AnalyticsColumn(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? json['key'] as String? ?? '',
      kind: json['kind'] as String? ?? 'text',
      computed: json['computed'] as bool? ?? false,
      options: _maps(
        json['options'],
      ).map(AnalyticsColumnOption.fromJson).toList(),
    );
  }
}

class AnalyticsDateBounds {
  const AnalyticsDateBounds({required this.min, required this.max});

  final DateTime min;
  final DateTime max;

  static AnalyticsDateBounds? fromJson(Map<String, dynamic> json) {
    final min = _dateTime(json['min']);
    final max = _dateTime(json['max']);
    if (min == null || max == null) return null;
    return AnalyticsDateBounds(min: min, max: max);
  }
}

class AnalyticsCountPoint {
  const AnalyticsCountPoint({required this.label, required this.value});

  final String label;
  final int value;

  factory AnalyticsCountPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsCountPoint(
      label: json['label'] as String? ?? '',
      value: _int(json['value']),
    );
  }

  static List<AnalyticsCountPoint> listFromJson(Object? raw) =>
      _maps(raw).map(AnalyticsCountPoint.fromJson).toList();
}

class AnalyticsHoursPoint {
  const AnalyticsHoursPoint({required this.label, required this.hours});

  final String label;
  final double hours;

  factory AnalyticsHoursPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsHoursPoint(
      label: json['label'] as String? ?? '',
      hours: _double(json['hours']) ?? 0,
    );
  }
}

class AnalyticsKpi {
  const AnalyticsKpi({
    required this.total,
    required this.open,
    required this.closed,
    required this.slaOk,
    required this.slaKnown,
    required this.confirmed,
    required this.overdueOpen,
    required this.reactionCount,
    required this.errors,
    required this.waitingOpen,
    this.medianResolutionHours,
    this.medianReactionHours,
    this.topWaitingOiv,
    this.topWaitingOivHours,
    this.topWaitingOivOpen = 0,
  });

  final int total;
  final int open;
  final int closed;
  final int slaOk;
  final int slaKnown;
  final int confirmed;
  final int overdueOpen;
  final int reactionCount;
  final int errors;
  final int waitingOpen;
  final double? medianResolutionHours;
  final double? medianReactionHours;
  final String? topWaitingOiv;
  final double? topWaitingOivHours;
  final int topWaitingOivOpen;

  factory AnalyticsKpi.fromJson(Map<String, dynamic> json) {
    return AnalyticsKpi(
      total: _int(json['total']),
      open: _int(json['open']),
      closed: _int(json['closed']),
      slaOk: _int(json['sla_ok']),
      slaKnown: _int(json['sla_known']),
      confirmed: _int(json['confirmed']),
      overdueOpen: _int(json['overdue_open']),
      reactionCount: _int(json['reaction_count']),
      errors: _int(json['errors']),
      waitingOpen: _int(json['waiting_open']),
      medianResolutionHours: _double(json['median_resolution_hours']),
      medianReactionHours: _double(json['median_reaction_hours']),
      topWaitingOiv: json['top_waiting_oiv'] as String?,
      topWaitingOivHours: _double(json['top_waiting_oiv_hours']),
      topWaitingOivOpen: _int(json['top_waiting_oiv_open']),
    );
  }
}

enum AnalyticsTrendGroupBy {
  day('day'),
  week('week'),
  month('month');

  const AnalyticsTrendGroupBy(this.apiKey);

  final String apiKey;
}

class AnalyticsTrendBuckets {
  const AnalyticsTrendBuckets({
    this.labels = const [],
    this.created = const [],
    this.closed = const [],
  });

  final List<String> labels;
  final List<int> created;
  final List<int> closed;

  bool get isEmpty =>
      labels.isEmpty ||
      (created.every((v) => v == 0) && closed.every((v) => v == 0));

  factory AnalyticsTrendBuckets.fromJson(Map<String, dynamic> json) {
    return AnalyticsTrendBuckets(
      labels: _strings(json['labels']),
      created: _ints(json['created']),
      closed: _ints(json['closed']),
    );
  }
}

class AnalyticsDailyBucket {
  const AnalyticsDailyBucket({
    required this.day,
    required this.created,
    required this.closed,
    this.avgReactionHours,
  });

  final String day;
  final int created;
  final int closed;
  final double? avgReactionHours;

  factory AnalyticsDailyBucket.fromJson(Map<String, dynamic> json) {
    return AnalyticsDailyBucket(
      day: json['day'] as String? ?? '',
      created: _int(json['created']),
      closed: _int(json['closed']),
      avgReactionHours: _double(json['avg_reaction_hours']),
    );
  }
}

class AnalyticsStatusByCategory {
  const AnalyticsStatusByCategory({
    this.categories = const [],
    this.closed = const [],
    this.inProgress = const [],
    this.waiting = const [],
  });

  final List<String> categories;
  final List<int> closed;
  final List<int> inProgress;
  final List<int> waiting;

  bool get isEmpty => categories.isEmpty;

  factory AnalyticsStatusByCategory.fromJson(Map<String, dynamic> json) {
    return AnalyticsStatusByCategory(
      categories: _strings(json['categories']),
      closed: _ints(json['closed']),
      inProgress: _ints(json['in_progress']),
      waiting: _ints(json['waiting']),
    );
  }
}

class AnalyticsSolvedBuckets {
  const AnalyticsSolvedBuckets({
    this.labels = const [],
    this.solved = const [],
    this.confirmed = const [],
  });

  final List<String> labels;
  final List<int> solved;
  final List<int> confirmed;

  bool get isEmpty => labels.isEmpty;

  factory AnalyticsSolvedBuckets.fromJson(Map<String, dynamic> json) {
    return AnalyticsSolvedBuckets(
      labels: _strings(json['labels']),
      solved: _ints(json['solved']),
      confirmed: _ints(json['confirmed']),
    );
  }
}

class AnalyticsCharts {
  const AnalyticsCharts({
    required this.trend,
    required this.type,
    required this.block,
    required this.oiv,
    required this.module,
    required this.problemCategory,
    required this.statusGroup,
    required this.errorSide,
    required this.oivWaiting,
    required this.dailyDetail,
    required this.statusByCategory,
    required this.solved,
  });

  final Map<AnalyticsTrendGroupBy, AnalyticsTrendBuckets> trend;
  final List<AnalyticsCountPoint> type;
  final List<AnalyticsCountPoint> block;
  final List<AnalyticsCountPoint> oiv;
  final List<AnalyticsCountPoint> module;
  final List<AnalyticsCountPoint> problemCategory;
  final List<AnalyticsCountPoint> statusGroup;
  final List<AnalyticsCountPoint> errorSide;
  final List<AnalyticsHoursPoint> oivWaiting;
  final List<AnalyticsDailyBucket> dailyDetail;
  final AnalyticsStatusByCategory statusByCategory;
  final AnalyticsSolvedBuckets solved;

  AnalyticsTrendBuckets trendFor(AnalyticsTrendGroupBy groupBy) =>
      trend[groupBy] ?? const AnalyticsTrendBuckets();

  factory AnalyticsCharts.fromJson(Map<String, dynamic> json) {
    final trend = _map(json['trend']);
    return AnalyticsCharts(
      trend: {
        for (final groupBy in AnalyticsTrendGroupBy.values)
          groupBy: AnalyticsTrendBuckets.fromJson(_map(trend[groupBy.apiKey])),
      },
      type: AnalyticsCountPoint.listFromJson(json['type']),
      block: AnalyticsCountPoint.listFromJson(json['block']),
      oiv: AnalyticsCountPoint.listFromJson(json['oiv']),
      module: AnalyticsCountPoint.listFromJson(json['module']),
      problemCategory: AnalyticsCountPoint.listFromJson(
        json['problem_category'],
      ),
      statusGroup: AnalyticsCountPoint.listFromJson(json['status_group']),
      errorSide: AnalyticsCountPoint.listFromJson(json['error_side']),
      oivWaiting: _maps(
        json['oiv_waiting'],
      ).map(AnalyticsHoursPoint.fromJson).toList(),
      dailyDetail: _maps(
        json['daily_detail'],
      ).map(AnalyticsDailyBucket.fromJson).toList(),
      statusByCategory: AnalyticsStatusByCategory.fromJson(
        _map(json['status_by_category']),
      ),
      solved: AnalyticsSolvedBuckets.fromJson(_map(json['solved'])),
    );
  }
}

class AnalyticsGroupRow {
  const AnalyticsGroupRow({
    required this.name,
    required this.count,
    required this.share,
    required this.closed,
    required this.inProgress,
    required this.waiting,
    required this.exampleIds,
    this.avgResolutionHours,
    this.avgReactionHours,
    this.errorSide,
  });

  final String name;
  final int count;
  final double share;
  final int closed;
  final int inProgress;
  final int waiting;
  final List<String> exampleIds;
  final double? avgResolutionHours;
  final double? avgReactionHours;
  final String? errorSide;

  factory AnalyticsGroupRow.fromJson(Map<String, dynamic> json) {
    return AnalyticsGroupRow(
      name: json['name'] as String? ?? '—',
      count: _int(json['count']),
      share: _double(json['share']) ?? 0,
      closed: _int(json['closed']),
      inProgress: _int(json['in_progress']),
      waiting: _int(json['waiting']),
      exampleIds: _strings(json['example_ids']),
      avgResolutionHours: _double(json['avg_resolution_hours']),
      avgReactionHours: _double(json['avg_reaction_hours']),
      errorSide: json['error_side'] as String?,
    );
  }

  static List<AnalyticsGroupRow> listFromJson(Object? raw) =>
      _maps(raw).map(AnalyticsGroupRow.fromJson).toList();
}

class AnalyticsOivWaitingRow {
  const AnalyticsOivWaitingRow({
    required this.name,
    required this.episodeCount,
    required this.openWaiting,
    required this.exampleIds,
    this.avgWaitingHours,
    this.medianWaitingHours,
    this.maxWaitingHours,
  });

  final String name;
  final int episodeCount;
  final int openWaiting;
  final List<String> exampleIds;
  final double? avgWaitingHours;
  final double? medianWaitingHours;
  final double? maxWaitingHours;

  factory AnalyticsOivWaitingRow.fromJson(Map<String, dynamic> json) {
    return AnalyticsOivWaitingRow(
      name: json['name'] as String? ?? '—',
      episodeCount: _int(json['episode_count']),
      openWaiting: _int(json['open_waiting']),
      exampleIds: _strings(json['example_ids']),
      avgWaitingHours: _double(json['avg_waiting_hours']),
      medianWaitingHours: _double(json['median_waiting_hours']),
      maxWaitingHours: _double(json['max_waiting_hours']),
    );
  }
}

class AnalyticsCrossMatrix {
  const AnalyticsCrossMatrix({
    this.rows = const [],
    this.cols = const [],
    this.values = const [],
  });

  final List<String> rows;
  final List<String> cols;
  final List<List<int>> values;

  bool get isEmpty => rows.isEmpty || cols.isEmpty;

  factory AnalyticsCrossMatrix.fromJson(Map<String, dynamic> json) {
    return AnalyticsCrossMatrix(
      rows: _strings(json['rows']),
      cols: _strings(json['cols']),
      values: [
        for (final row in json['values'] as List<dynamic>? ?? const [])
          _ints(row),
      ],
    );
  }
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.category,
    required this.block,
    required this.errorSide,
    required this.oivWaiting,
    required this.crossMatrix,
  });

  final List<AnalyticsGroupRow> category;
  final List<AnalyticsGroupRow> block;
  final List<AnalyticsGroupRow> errorSide;
  final List<AnalyticsOivWaitingRow> oivWaiting;
  final AnalyticsCrossMatrix crossMatrix;

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      category: AnalyticsGroupRow.listFromJson(json['category']),
      block: AnalyticsGroupRow.listFromJson(json['block']),
      errorSide: AnalyticsGroupRow.listFromJson(json['error_side']),
      oivWaiting: _maps(
        json['oiv_waiting'],
      ).map(AnalyticsOivWaitingRow.fromJson).toList(),
      crossMatrix: AnalyticsCrossMatrix.fromJson(_map(json['cross_matrix'])),
    );
  }
}

class AnalyticsTableRow {
  const AnalyticsTableRow({
    required this.id,
    required this.state,
    required this.stateLabel,
    this.permalink,
    this.type,
    this.block,
    this.problemCategory,
    this.subject,
    this.member,
    this.requestedBy,
    this.oiv,
    this.createdAt,
    this.completedAt,
    this.resolutionHours,
    this.reactionHours,
    this.errorSide,
    this.slaMet,
    this.isOverdue = false,
  });

  final String id;
  final String state;
  final String stateLabel;
  final String? permalink;
  final String? type;
  final String? block;
  final String? problemCategory;
  final String? subject;
  final String? member;
  final String? requestedBy;
  final String? oiv;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final double? resolutionHours;
  final double? reactionHours;
  final String? errorSide;
  final bool? slaMet;
  final bool isOverdue;

  bool get isClosed => state == 'closed';

  factory AnalyticsTableRow.fromJson(Map<String, dynamic> json) {
    return AnalyticsTableRow(
      id: json['id'] as String? ?? '',
      state: json['state'] as String? ?? 'open',
      stateLabel: json['state_label'] as String? ?? '',
      permalink: json['permalink'] as String?,
      type: json['type'] as String?,
      block: json['block'] as String?,
      problemCategory: json['problem_category'] as String?,
      subject: json['subject'] as String?,
      member: json['member'] as String?,
      requestedBy: json['requested_by'] as String?,
      oiv: json['oiv'] as String?,
      createdAt: _dateTime(json['created_at']),
      completedAt: _dateTime(json['completed_at']),
      resolutionHours: _double(json['resolution_hours']),
      reactionHours: _double(json['reaction_hours']),
      errorSide: json['error_side'] as String?,
      slaMet: json['sla_met'] as bool?,
      isOverdue: json['is_overdue'] as bool? ?? false,
    );
  }
}

class AnalyticsRecordsPage {
  const AnalyticsRecordsPage({
    this.items = const [],
    this.total = 0,
    this.limit = 0,
    this.offset = 0,
  });

  final List<AnalyticsTableRow> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  factory AnalyticsRecordsPage.fromJson(Map<String, dynamic> json) {
    return AnalyticsRecordsPage(
      items: _maps(json['items']).map(AnalyticsTableRow.fromJson).toList(),
      total: _int(json['total']),
      limit: _int(json['limit']),
      offset: _int(json['offset']),
    );
  }
}

class AnalyticsDashboard {
  const AnalyticsDashboard({
    required this.spreadsheetId,
    required this.sheetName,
    required this.fetchedAt,
    required this.itsmBaseUrl,
    required this.totalCount,
    required this.filteredCount,
    required this.dateColumn,
    required this.columns,
    required this.dateBounds,
    required this.kpi,
    required this.charts,
    required this.summary,
    required this.records,
  });

  final String spreadsheetId;
  final String sheetName;
  final DateTime fetchedAt;
  final String itsmBaseUrl;
  final int totalCount;
  final int filteredCount;
  final String dateColumn;
  final List<AnalyticsColumn> columns;
  final Map<String, AnalyticsDateBounds> dateBounds;
  final AnalyticsKpi kpi;
  final AnalyticsCharts charts;
  final AnalyticsSummary summary;
  final AnalyticsRecordsPage records;

  factory AnalyticsDashboard.fromJson(Map<String, dynamic> json) {
    return AnalyticsDashboard(
      spreadsheetId: json['spreadsheet_id'] as String? ?? '',
      sheetName: json['sheet_name'] as String? ?? '',
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      itsmBaseUrl: json['itsm_base_url'] as String? ?? '',
      totalCount: _int(json['total_count']),
      filteredCount: _int(json['filtered_count']),
      dateColumn: json['date_column'] as String? ?? '',
      columns: _maps(json['columns']).map(AnalyticsColumn.fromJson).toList(),
      dateBounds: {
        for (final entry in _map(json['date_bounds']).entries)
          entry.key: ?AnalyticsDateBounds.fromJson(_map(entry.value)),
      },
      kpi: AnalyticsKpi.fromJson(_map(json['kpi'])),
      charts: AnalyticsCharts.fromJson(_map(json['charts'])),
      summary: AnalyticsSummary.fromJson(_map(json['summary'])),
      records: AnalyticsRecordsPage.fromJson(_map(json['records'])),
    );
  }
}
