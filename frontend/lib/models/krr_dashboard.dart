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
    this.createdWork = const KrrTrendSeries(),
    this.changedWork = const KrrTrendSeries(),
    this.createdCard = const KrrTrendSeries(),
    this.changedCard = const KrrTrendSeries(),
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
  final KrrTrendSeries createdWork;
  final KrrTrendSeries changedWork;
  final KrrTrendSeries createdCard;
  final KrrTrendSeries changedCard;
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
      createdWork: KrrTrendSeries.fromJson(json['created_work']),
      changedWork: KrrTrendSeries.fromJson(json['changed_work']),
      createdCard: KrrTrendSeries.fromJson(json['created_card']),
      changedCard: KrrTrendSeries.fromJson(json['changed_card']),
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
    this.insights = const KrrInsights(),
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
  final KrrInsights insights;

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
      insights: KrrInsights.fromJson(
        json['insights'] is Map<String, dynamic>
            ? json['insights'] as Map<String, dynamic>
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

double? _double(Object? raw) => (raw as num?)?.toDouble();

class KrrSchedule {
  const KrrSchedule({
    this.early = 0,
    this.onTime = 0,
    this.late = 0,
    this.unfinished = 0,
    this.incompleteDates = 0,
    this.overdueOpen = 0,
    this.datedCompleted = 0,
    this.earlyShare,
    this.onTimeShare,
    this.lateShare,
    this.avgDeviationDays,
    this.avgDurationDays,
  });

  final int early;
  final int onTime;
  final int late;
  final int unfinished;
  final int incompleteDates;
  final int overdueOpen;
  final int datedCompleted;
  final double? earlyShare;
  final double? onTimeShare;
  final double? lateShare;
  final double? avgDeviationDays;
  final double? avgDurationDays;

  factory KrrSchedule.fromJson(Map<String, dynamic> json) {
    return KrrSchedule(
      early: _int(json['early']),
      onTime: _int(json['on_time']),
      late: _int(json['late']),
      unfinished: _int(json['unfinished']),
      incompleteDates: _int(json['incomplete_dates']),
      overdueOpen: _int(json['overdue_open']),
      datedCompleted: _int(json['dated_completed']),
      earlyShare: _double(json['early_share']),
      onTimeShare: _double(json['on_time_share']),
      lateShare: _double(json['late_share']),
      avgDeviationDays: _double(json['avg_deviation_days']),
      avgDurationDays: _double(json['avg_duration_days']),
    );
  }
}

class KrrQualityIndex {
  const KrrQualityIndex({
    this.score,
    this.completeness,
    this.correctness,
    this.consistency,
    this.freshness,
    this.uniqueness,
    this.weights = const {},
  });

  final double? score;
  final double? completeness;
  final double? correctness;
  final double? consistency;
  final double? freshness;
  final double? uniqueness;
  final Map<String, double> weights;

  factory KrrQualityIndex.fromJson(Map<String, dynamic> json) {
    final raw = json['weights'];
    final weights = <String, double>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is num) weights[entry.key.toString()] = value.toDouble();
      }
    }
    return KrrQualityIndex(
      score: _double(json['score']),
      completeness: _double(json['completeness']),
      correctness: _double(json['correctness']),
      consistency: _double(json['consistency']),
      freshness: _double(json['freshness']),
      uniqueness: _double(json['uniqueness']),
      weights: weights,
    );
  }
}

class KrrFieldFill {
  const KrrFieldFill({
    required this.key,
    required this.label,
    required this.filled,
    required this.empty,
    required this.applicable,
    this.percent,
  });

  final String key;
  final String label;
  final int filled;
  final int empty;
  final int applicable;
  final double? percent;

  factory KrrFieldFill.fromJson(Map<String, dynamic> json) {
    return KrrFieldFill(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      filled: _int(json['filled']),
      empty: _int(json['empty']),
      applicable: _int(json['applicable']),
      percent: _double(json['percent']),
    );
  }
}

class KrrQualityRule {
  const KrrQualityRule({
    required this.code,
    required this.title,
    required this.description,
    required this.count,
    required this.severity,
    required this.group,
  });

  final String code;
  final String title;
  final String description;
  final int count;
  final String severity;
  final String group;

  factory KrrQualityRule.fromJson(Map<String, dynamic> json) {
    return KrrQualityRule(
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      count: _int(json['count']),
      severity: json['severity'] as String? ?? 'info',
      group: json['group'] as String? ?? '',
    );
  }
}

class KrrIssueRow {
  const KrrIssueRow({
    required this.idUnique,
    this.idWork,
    this.name,
    this.address,
    this.stage,
    this.problem = '',
    this.link,
  });

  final int idUnique;
  final int? idWork;
  final String? name;
  final String? address;
  final String? stage;
  final String problem;
  final String? link;

  factory KrrIssueRow.fromJson(Map<String, dynamic> json) {
    return KrrIssueRow(
      idUnique: _int(json['id_unique']),
      idWork: json['id_work'] == null ? null : _int(json['id_work']),
      name: json['name_work_version'] as String?,
      address: json['address'] as String?,
      stage: json['stage'] as String?,
      problem: json['problem'] as String? ?? '',
      link: json['link'] as String?,
    );
  }
}

class KrrIssuePage {
  const KrrIssuePage({
    required this.total,
    required this.problem,
    required this.items,
  });

  final int total;
  final String problem;
  final List<KrrIssueRow> items;

  factory KrrIssuePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return KrrIssuePage(
      total: _int(json['total']),
      problem: json['problem'] as String? ?? '',
      items: [
        for (final item in raw is List ? raw : const [])
          if (item is Map<String, dynamic>) KrrIssueRow.fromJson(item),
      ],
    );
  }
}

class KrrInsights {
  const KrrInsights({
    this.works = 0,
    this.rowsWithoutWorkId = 0,
    this.completed = 0,
    this.inProgress = 0,
    this.cancelled = 0,
    this.otherStage = 0,
    this.squareSum,
    this.squareAvg,
    this.squareKnown = 0,
    this.stageBuckets = const [],
    this.oiv = const [],
    this.yearVersions = const [],
    this.yearWorks = const [],
    this.yearSquare = const [],
    this.cancelReasons = const [],
    this.categories = const {},
    this.schedule = const KrrSchedule(),
    this.quality = const KrrQualityIndex(),
    this.fields = const [],
    this.rules = const [],
    this.versionBuckets = const [],
    this.duplicateIdUnique = 0,
    this.repeatedVersionWorks = 0,
    this.worksMissingFirstVersion,
    this.multipleWithoutArchive,
    this.actualFlagAvailable = false,
    this.freshness = const [],
    this.freshnessAvgDays,
    this.freshnessKnown = 0,
    this.staleByOiv = const [],
    this.missingAreaTotal = 0,
    this.missingArea = const [],
    this.unavailable = const [],
    this.snapshotNote = '',
  });

  final int works;
  final int rowsWithoutWorkId;
  final int completed;
  final int inProgress;
  final int cancelled;
  final int otherStage;
  final double? squareSum;
  final double? squareAvg;
  final int squareKnown;
  final List<AnalyticsCountPoint> stageBuckets;
  final List<AnalyticsCountPoint> oiv;
  final List<AnalyticsCountPoint> yearVersions;
  final List<AnalyticsCountPoint> yearWorks;
  final List<AnalyticsCountPoint> yearSquare;
  final List<AnalyticsCountPoint> cancelReasons;
  final Map<String, List<AnalyticsCountPoint>> categories;
  final KrrSchedule schedule;
  final KrrQualityIndex quality;
  final List<KrrFieldFill> fields;
  final List<KrrQualityRule> rules;
  final List<AnalyticsCountPoint> versionBuckets;
  final int duplicateIdUnique;
  final int repeatedVersionWorks;
  final int? worksMissingFirstVersion;
  final int? multipleWithoutArchive;
  final bool actualFlagAvailable;
  final List<AnalyticsCountPoint> freshness;
  final double? freshnessAvgDays;
  final int freshnessKnown;
  final List<AnalyticsCountPoint> staleByOiv;
  final int missingAreaTotal;
  final List<KrrIssueRow> missingArea;
  final List<String> unavailable;
  final String snapshotNote;

  factory KrrInsights.fromJson(Map<String, dynamic> json) {
    List<AnalyticsCountPoint> points(String key) =>
        AnalyticsCountPoint.listFromJson(json[key]);
    final categoriesRaw = json['categories'];
    final categories = <String, List<AnalyticsCountPoint>>{};
    if (categoriesRaw is Map) {
      for (final entry in categoriesRaw.entries) {
        categories[entry.key.toString()] = AnalyticsCountPoint.listFromJson(
          entry.value,
        );
      }
    }
    final rulesRaw = json['rules'];
    final fieldsRaw = json['fields'];
    final areaRaw = json['missing_area'];
    final notesRaw = json['unavailable'];
    return KrrInsights(
      works: _int(json['works']),
      rowsWithoutWorkId: _int(json['rows_without_work_id']),
      completed: _int(json['completed']),
      inProgress: _int(json['in_progress']),
      cancelled: _int(json['cancelled']),
      otherStage: _int(json['other_stage']),
      squareSum: _double(json['square_sum']),
      squareAvg: _double(json['square_avg']),
      squareKnown: _int(json['square_known']),
      stageBuckets: points('stage_buckets'),
      oiv: points('oiv'),
      yearVersions: points('year_versions'),
      yearWorks: points('year_works'),
      yearSquare: points('year_square'),
      cancelReasons: points('cancel_reasons'),
      categories: categories,
      schedule: KrrSchedule.fromJson(
        json['schedule'] is Map<String, dynamic>
            ? json['schedule'] as Map<String, dynamic>
            : const {},
      ),
      quality: KrrQualityIndex.fromJson(
        json['quality'] is Map<String, dynamic>
            ? json['quality'] as Map<String, dynamic>
            : const {},
      ),
      fields: [
        for (final item in fieldsRaw is List ? fieldsRaw : const [])
          if (item is Map<String, dynamic>) KrrFieldFill.fromJson(item),
      ],
      rules: [
        for (final item in rulesRaw is List ? rulesRaw : const [])
          if (item is Map<String, dynamic>) KrrQualityRule.fromJson(item),
      ],
      versionBuckets: points('version_buckets'),
      duplicateIdUnique: _int(json['duplicate_id_unique']),
      repeatedVersionWorks: _int(json['repeated_version_works']),
      worksMissingFirstVersion: json['works_missing_first_version'] == null
          ? null
          : _int(json['works_missing_first_version']),
      multipleWithoutArchive: json['multiple_without_archive'] == null
          ? null
          : _int(json['multiple_without_archive']),
      actualFlagAvailable: json['actual_flag_available'] == true,
      freshness: points('freshness'),
      freshnessAvgDays: _double(json['freshness_avg_days']),
      freshnessKnown: _int(json['freshness_known']),
      staleByOiv: points('stale_by_oiv'),
      missingAreaTotal: _int(json['missing_area_total']),
      missingArea: [
        for (final item in areaRaw is List ? areaRaw : const [])
          if (item is Map<String, dynamic>) KrrIssueRow.fromJson(item),
      ],
      unavailable: [
        for (final item in notesRaw is List ? notesRaw : const [])
          item.toString(),
      ],
      snapshotNote: json['snapshot_note'] as String? ?? '',
    );
  }
}

DateTime? _dateTime(Object? raw) =>
    raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;
