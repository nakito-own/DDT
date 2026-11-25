import 'task_status.dart';
import 'task_type.dart';

class TaskFieldValue {
  const TaskFieldValue({
    required this.fieldId,
    required this.name,
    required this.fieldType,
    this.listMultiple = false,
    this.options = const [],
    this.value,
  });

  final int fieldId;
  final String name;
  final String fieldType;
  final bool listMultiple;
  final List<String> options;
  final Object? value;

  bool get isEmpty {
    if (value == null) return true;
    if (value is String && (value as String).trim().isEmpty) return true;
    if (value is List && (value as List).isEmpty) return true;
    return false;
  }

  String get displayValue {
    if (value is List) return (value as List).join(', ');
    if (value is bool) return value == true ? 'Да' : 'Нет';
    return '${value ?? ''}';
  }

  factory TaskFieldValue.fromJson(Map<String, dynamic> json) {
    return TaskFieldValue(
      fieldId: json['field_id'] as int,
      name: json['name'] as String? ?? '',
      fieldType: json['field_type'] as String? ?? 'text',
      listMultiple: json['list_multiple'] == true,
      options: [
        for (final item in json['options'] as List<dynamic>? ?? const [])
          item.toString(),
      ],
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() => {'field_id': fieldId, 'value': value};
}

class TaskComponentRef {
  const TaskComponentRef({required this.id, required this.name});

  final int id;
  final String name;

  factory TaskComponentRef.fromJson(Map<String, dynamic> json) {
    return TaskComponentRef(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
    );
  }
}

class TaskNotifications {
  const TaskNotifications({
    this.notifyAssigned = true,
    this.notifyUpdated = true,
    this.notifyComment = true,
    this.notifyDeleted = true,
    this.deadlineReminderHours,
  });

  final bool notifyAssigned;
  final bool notifyUpdated;
  final bool notifyComment;
  final bool notifyDeleted;
  final int? deadlineReminderHours;

  factory TaskNotifications.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TaskNotifications();
    return TaskNotifications(
      notifyAssigned: json['notify_assigned'] != false,
      notifyUpdated: json['notify_updated'] != false,
      notifyComment: json['notify_comment'] != false,
      notifyDeleted: json['notify_deleted'] != false,
      deadlineReminderHours: json['deadline_reminder_hours'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'notify_assigned': notifyAssigned,
    'notify_updated': notifyUpdated,
    'notify_comment': notifyComment,
    'notify_deleted': notifyDeleted,
    'deadline_reminder_hours': deadlineReminderHours,
  };

  TaskNotifications copyWith({
    bool? notifyAssigned,
    bool? notifyUpdated,
    bool? notifyComment,
    bool? notifyDeleted,
    int? deadlineReminderHours,
    bool clearReminder = false,
  }) {
    return TaskNotifications(
      notifyAssigned: notifyAssigned ?? this.notifyAssigned,
      notifyUpdated: notifyUpdated ?? this.notifyUpdated,
      notifyComment: notifyComment ?? this.notifyComment,
      notifyDeleted: notifyDeleted ?? this.notifyDeleted,
      deadlineReminderHours: clearReminder
          ? null
          : (deadlineReminderHours ?? this.deadlineReminderHours),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TaskNotifications &&
        other.notifyAssigned == notifyAssigned &&
        other.notifyUpdated == notifyUpdated &&
        other.notifyComment == notifyComment &&
        other.notifyDeleted == notifyDeleted &&
        other.deadlineReminderHours == deadlineReminderHours;
  }

  @override
  int get hashCode => Object.hash(
    notifyAssigned,
    notifyUpdated,
    notifyComment,
    notifyDeleted,
    deadlineReminderHours,
  );
}

class QueueField {
  const QueueField({
    required this.name,
    required this.fieldType,
    this.id,
    this.listMultiple = false,
    this.options = const [],
    this.defaultValue,
  });

  final int? id;
  final String name;
  final String fieldType;
  final bool listMultiple;
  final List<String> options;
  final Object? defaultValue;

  factory QueueField.fromJson(Map<String, dynamic> json) {
    return QueueField(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      fieldType: json['field_type'] as String? ?? 'text',
      listMultiple: json['list_multiple'] == true,
      options: [
        for (final item in json['options'] as List<dynamic>? ?? const [])
          item.toString(),
      ],
      defaultValue: json['default_value'],
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'field_type': fieldType,
    'list_multiple': listMultiple,
    'options': options,
    'default_value': defaultValue,
  };

  TaskFieldValue toValue() {
    return TaskFieldValue(
      fieldId: id ?? 0,
      name: name,
      fieldType: fieldType,
      listMultiple: listMultiple,
      options: options,
      value: defaultValue,
    );
  }
}

class QueueComponent {
  const QueueComponent({
    required this.name,
    this.id,
    this.isDefault = false,
  });

  final int? id;
  final String name;
  final bool isDefault;

  factory QueueComponent.fromJson(Map<String, dynamic> json) {
    return QueueComponent(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      isDefault: json['is_default'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'is_default': isDefault,
  };
}

class QueueSettings {
  const QueueSettings({
    required this.id,
    required this.statuses,
    required this.types,
    this.fields = const [],
    this.components = const [],
    this.defaultStatusKey = 'todo',
    this.defaultTypeId,
    this.defaultTypeName,
    this.defaultDeadlineDays,
    this.defaultPriority,
    this.notifyAssigned = true,
    this.notifyUpdated = true,
    this.notifyComment = true,
    this.notifyDeleted = true,
    this.deadlineReminderHours,
    this.defaultComponentIds = const [],
  });

  final int id;
  final List<TaskStatus> statuses;
  final List<TaskType> types;
  final List<QueueField> fields;
  final List<QueueComponent> components;
  final String defaultStatusKey;
  final int? defaultTypeId;
  final String? defaultTypeName;
  final int? defaultDeadlineDays;
  final String? defaultPriority;
  final bool notifyAssigned;
  final bool notifyUpdated;
  final bool notifyComment;
  final bool notifyDeleted;
  final int? deadlineReminderHours;
  final List<int> defaultComponentIds;

  TaskStatus get defaultStatus {
    for (final status in statuses) {
      if (status.value == defaultStatusKey) return status;
    }
    return statuses.isEmpty ? TaskStatus.todo : statuses.first;
  }

  TaskNotifications get defaultNotifications => TaskNotifications(
    notifyAssigned: notifyAssigned,
    notifyUpdated: notifyUpdated,
    notifyComment: notifyComment,
    notifyDeleted: notifyDeleted,
    deadlineReminderHours: deadlineReminderHours,
  );

  factory QueueSettings.fallback() {
    return const QueueSettings(
      id: 0,
      statuses: TaskStatus.values,
      types: [],
      defaultStatusKey: 'todo',
      defaultTypeName: 'Задача',
    );
  }

  factory QueueSettings.fromJson(Map<String, dynamic> json) {
    return QueueSettings(
      id: json['id'] as int? ?? 0,
      statuses: [
        for (final item in json['statuses'] as List<dynamic>? ?? const [])
          TaskStatus.fromQueueJson(item as Map<String, dynamic>),
      ],
      types: [
        for (final item in json['types'] as List<dynamic>? ?? const [])
          TaskType.fromJson(item as Map<String, dynamic>),
      ],
      fields: [
        for (final item in json['fields'] as List<dynamic>? ?? const [])
          QueueField.fromJson(item as Map<String, dynamic>),
      ],
      components: [
        for (final item in json['components'] as List<dynamic>? ?? const [])
          QueueComponent.fromJson(item as Map<String, dynamic>),
      ],
      defaultStatusKey: json['default_status_key'] as String? ?? 'todo',
      defaultTypeId: json['default_type_id'] as int?,
      defaultTypeName: json['default_type_name'] as String?,
      defaultDeadlineDays: json['default_deadline_days'] as int?,
      defaultPriority: json['default_priority'] as String?,
      notifyAssigned: json['notify_assigned'] != false,
      notifyUpdated: json['notify_updated'] != false,
      notifyComment: json['notify_comment'] != false,
      notifyDeleted: json['notify_deleted'] != false,
      deadlineReminderHours: json['deadline_reminder_hours'] as int?,
      defaultComponentIds: [
        for (final item
            in json['default_component_ids'] as List<dynamic>? ?? const [])
          if (item is num) item.toInt(),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'default_status_key': defaultStatusKey,
      'default_type_name': defaultTypeName ?? types.first.name,
      'default_deadline_days': defaultDeadlineDays,
      'default_priority': defaultPriority,
      'notify_assigned': notifyAssigned,
      'notify_updated': notifyUpdated,
      'notify_comment': notifyComment,
      'notify_deleted': notifyDeleted,
      'deadline_reminder_hours': deadlineReminderHours,
      'statuses': [
        for (final status in statuses) status.toQueueJson(),
      ],
      'types': [
        for (var i = 0; i < types.length; i++)
          {'id': types[i].id, 'name': types[i].name, 'sort_order': i},
      ],
      'fields': [
        for (final field in fields) field.toJson(),
      ],
      'components': [
        for (final component in components) component.toJson(),
      ],
    };
  }

  QueueSettings copyWith({
    List<TaskStatus>? statuses,
    List<TaskType>? types,
    List<QueueField>? fields,
    List<QueueComponent>? components,
    String? defaultStatusKey,
    int? defaultTypeId,
    String? defaultTypeName,
    int? defaultDeadlineDays,
    bool clearDeadline = false,
    String? defaultPriority,
    bool clearPriority = false,
    bool? notifyAssigned,
    bool? notifyUpdated,
    bool? notifyComment,
    bool? notifyDeleted,
    int? deadlineReminderHours,
    bool clearReminder = false,
    List<int>? defaultComponentIds,
  }) {
    return QueueSettings(
      id: id,
      statuses: statuses ?? this.statuses,
      types: types ?? this.types,
      fields: fields ?? this.fields,
      components: components ?? this.components,
      defaultStatusKey: defaultStatusKey ?? this.defaultStatusKey,
      defaultTypeId: defaultTypeId ?? this.defaultTypeId,
      defaultTypeName: defaultTypeName ?? this.defaultTypeName,
      defaultDeadlineDays: clearDeadline
          ? null
          : (defaultDeadlineDays ?? this.defaultDeadlineDays),
      defaultPriority: clearPriority
          ? null
          : (defaultPriority ?? this.defaultPriority),
      notifyAssigned: notifyAssigned ?? this.notifyAssigned,
      notifyUpdated: notifyUpdated ?? this.notifyUpdated,
      notifyComment: notifyComment ?? this.notifyComment,
      notifyDeleted: notifyDeleted ?? this.notifyDeleted,
      deadlineReminderHours: clearReminder
          ? null
          : (deadlineReminderHours ?? this.deadlineReminderHours),
      defaultComponentIds: defaultComponentIds ?? this.defaultComponentIds,
    );
  }
}
