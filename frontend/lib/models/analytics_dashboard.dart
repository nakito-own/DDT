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
      count: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

class AnalyticsColumn {
  const AnalyticsColumn({
    required this.key,
    required this.label,
    required this.kind,
    this.options = const [],
  });

  final String key;
  final String label;
  final String kind;
  final List<AnalyticsColumnOption> options;

  bool get isDate => kind == 'date';
  bool get isEnum => kind == 'enum' || kind == 'boolean';
  bool get isSearchable => kind == 'text' || kind == 'number';
  bool get isComment {
    final lowered = '${key.toLowerCase()} ${label.toLowerCase()}';
    return lowered.contains('комментар') || lowered.contains('comment');
  }

  bool get isAuthor {
    final lowered = '${key.toLowerCase()} ${label.toLowerCase()}';
    return lowered.contains('автор') || lowered.contains('author');
  }

  bool get isFilterIgnored => isComment || isAuthor;

  factory AnalyticsColumn.fromJson(Map<String, dynamic> json) {
    return AnalyticsColumn(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? json['key'] as String? ?? '',
      kind: json['kind'] as String? ?? 'text',
      options: (json['options'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsColumnOption.fromJson)
          .toList(),
    );
  }
}

class AnalyticsCountPoint {
  const AnalyticsCountPoint({required this.label, required this.value});

  final String label;
  final int value;

  factory AnalyticsCountPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsCountPoint(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

class AnalyticsKpis {
  const AnalyticsKpis({
    required this.total,
    this.assigned = 0,
    this.inProgress = 0,
    this.waitingCustomer = 0,
    this.completed = 0,
    this.open = 0,
    this.resolved = 0,
    this.unresolved = 0,
    this.userConfirmed = 0,
    this.avgCloseDays,
    this.sheetTotal,
    this.sheetWaitingLeft,
  });

  final int total;
  final int assigned;
  final int inProgress;
  final int waitingCustomer;
  final int completed;
  final int open;
  final int resolved;
  final int unresolved;
  final int userConfirmed;
  final double? avgCloseDays;
  final int? sheetTotal;
  final int? sheetWaitingLeft;

  factory AnalyticsKpis.fromJson(Map<String, dynamic> json) {
    return AnalyticsKpis(
      total: (json['total'] as num?)?.toInt() ?? 0,
      assigned: (json['assigned'] as num?)?.toInt() ?? 0,
      inProgress: (json['in_progress'] as num?)?.toInt() ?? 0,
      waitingCustomer: (json['waiting_customer'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 0,
      unresolved: (json['unresolved'] as num?)?.toInt() ?? 0,
      userConfirmed: (json['user_confirmed'] as num?)?.toInt() ?? 0,
      avgCloseDays: (json['avg_close_days'] as num?)?.toDouble(),
      sheetTotal: (json['sheet_total'] as num?)?.toInt(),
      sheetWaitingLeft: (json['sheet_waiting_left'] as num?)?.toInt(),
    );
  }
}

class AnalyticsSeries {
  const AnalyticsSeries({
    this.status = const [],
    this.type = const [],
    this.block = const [],
    this.category = const [],
    this.topics = const [],
    this.createdWeekly = const [],
  });

  final List<AnalyticsCountPoint> status;
  final List<AnalyticsCountPoint> type;
  final List<AnalyticsCountPoint> block;
  final List<AnalyticsCountPoint> category;
  final List<AnalyticsCountPoint> topics;
  final List<AnalyticsCountPoint> createdWeekly;

  factory AnalyticsSeries.fromJson(Map<String, dynamic> json) {
    List<AnalyticsCountPoint> parse(String key) {
      final raw = json[key] as List<dynamic>? ?? [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsCountPoint.fromJson)
          .toList();
    }

    return AnalyticsSeries(
      status: parse('status'),
      type: parse('type'),
      block: parse('block'),
      category: parse('category'),
      topics: parse('topics'),
      createdWeekly: parse('created_weekly'),
    );
  }
}

class AnalyticsTicket {
  const AnalyticsTicket({
    required this.ticketId,
    this.number,
    this.createdAt,
    this.closedAt,
    this.subject,
    this.type,
    this.block,
    this.category,
    this.status,
    this.status4me,
    this.resolved,
    this.userConfirmed,
    this.statusBucket,
    this.topic,
    this.fields = const {},
    this.dates = const {},
  });

  final String ticketId;
  final String? number;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final String? subject;
  final String? type;
  final String? block;
  final String? category;
  final String? status;
  final String? status4me;
  final bool? resolved;
  final bool? userConfirmed;
  final String? statusBucket;
  final String? topic;
  final Map<String, String> fields;
  final Map<String, DateTime> dates;

  String get topicLabel {
    final value = topic?.trim() ?? '';
    return value.isEmpty ? 'Без темы' : value;
  }

  String fieldValue(String key) => fields[key] ?? '';

  DateTime? dateValue(String? key) {
    if (key == null || key.isEmpty) return createdAt;
    return dates[key] ?? (key == 'Дата создания' ? createdAt : null) ??
        (key == 'Дата закрытия' ? closedAt : null);
  }

  factory AnalyticsTicket.fromJson(Map<String, dynamic> json) {
    return AnalyticsTicket(
      ticketId: json['ticket_id'] as String? ?? '',
      number: json['number'] as String?,
      createdAt: _parseDate(json['created_at'] as String?),
      closedAt: _parseDate(json['closed_at'] as String?),
      subject: json['subject'] as String?,
      type: json['type'] as String?,
      block: json['block'] as String?,
      category: json['category'] as String?,
      status: json['status'] as String?,
      status4me: json['status_4me'] as String?,
      resolved: json['resolved'] as bool?,
      userConfirmed: json['user_confirmed'] as bool?,
      statusBucket: json['status_bucket'] as String?,
      topic: json['topic'] as String?,
      fields: {
        for (final entry
            in (json['fields'] as Map<String, dynamic>? ?? {}).entries)
          entry.key: entry.value?.toString() ?? '',
      },
      dates: {
        for (final entry
            in (json['dates'] as Map<String, dynamic>? ?? {}).entries)
          if (entry.value is String && DateTime.tryParse(entry.value as String) != null)
            entry.key: DateTime.parse(entry.value as String),
      },
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class AnalyticsDashboard {
  const AnalyticsDashboard({
    required this.spreadsheetId,
    required this.sheetName,
    required this.fetchedAt,
    required this.kpis,
    required this.series,
    this.recent = const [],
    this.applications = const [],
    this.columns = const [],
  });

  final String spreadsheetId;
  final String sheetName;
  final DateTime fetchedAt;
  final AnalyticsKpis kpis;
  final AnalyticsSeries series;
  final List<AnalyticsTicket> recent;
  final List<AnalyticsTicket> applications;
  final List<AnalyticsColumn> columns;

  factory AnalyticsDashboard.fromJson(Map<String, dynamic> json) {
    final rawRecent = json['recent'] as List<dynamic>? ?? [];
    final rawApplications = json['applications'] as List<dynamic>? ?? [];
    return AnalyticsDashboard(
      spreadsheetId: json['spreadsheet_id'] as String? ?? '',
      sheetName: json['sheet_name'] as String? ?? '',
      fetchedAt: DateTime.parse(json['fetched_at'] as String),
      kpis: AnalyticsKpis.fromJson(
        json['kpis'] as Map<String, dynamic>? ?? const {},
      ),
      series: AnalyticsSeries.fromJson(
        json['series'] as Map<String, dynamic>? ?? const {},
      ),
      recent: rawRecent
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsTicket.fromJson)
          .toList(),
      applications: rawApplications
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsTicket.fromJson)
          .toList(),
      columns: (json['columns'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AnalyticsColumn.fromJson)
          .toList(),
    );
  }
}
