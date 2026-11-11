enum AppNotificationCategory {
  newMail('new_mail'),
  mailUpdated('mail_updated'),
  calendarUpdated('calendar_updated'),
  taskAssigned('task_assigned'),
  taskUpdated('task_updated'),
  system('system');

  const AppNotificationCategory(this.apiValue);

  final String apiValue;

  static AppNotificationCategory fromApi(String value) {
    return AppNotificationCategory.values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => AppNotificationCategory.system,
    );
  }
}

enum AppNotificationTarget { mail, calendar, task, none }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.timestamp,
    this.itemId,
    this.read = false,
    this.targetKind,
    this.taskKey,
    this.spaceKey,
    this.focusAt,
    this.matchSubject,
  });

  final String id;
  final AppNotificationCategory category;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? itemId;
  final bool read;
  final String? targetKind;
  final String? taskKey;
  final String? spaceKey;
  final DateTime? focusAt;
  final String? matchSubject;

  AppNotificationTarget get target {
    switch (targetKind) {
      case 'mail':
        return AppNotificationTarget.mail;
      case 'calendar':
        return AppNotificationTarget.calendar;
      case 'task':
        return AppNotificationTarget.task;
      default:
        break;
    }
    switch (category) {
      case AppNotificationCategory.newMail:
      case AppNotificationCategory.mailUpdated:
        return AppNotificationTarget.mail;
      case AppNotificationCategory.calendarUpdated:
        return AppNotificationTarget.calendar;
      case AppNotificationCategory.taskAssigned:
      case AppNotificationCategory.taskUpdated:
        return AppNotificationTarget.task;
      case AppNotificationCategory.system:
        return AppNotificationTarget.none;
    }
  }

  bool get opensObject {
    if (target == AppNotificationTarget.none) return false;
    if (taskKey != null && taskKey!.isNotEmpty) return true;
    return itemId != null && itemId!.isNotEmpty;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final focusRaw = json['focus_at'];
    return AppNotification(
      id: json['id'] as String,
      category: AppNotificationCategory.fromApi(
        json['category'] as String? ?? 'system',
      ),
      title: json['title'] as String? ?? 'Уведомление',
      body: json['body'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      itemId: json['item_id'] as String?,
      targetKind: json['target_kind'] as String?,
      taskKey: json['task_key'] as String?,
      spaceKey: json['space_key'] as String?,
      focusAt: focusRaw == null ? null : DateTime.parse(focusRaw as String),
      matchSubject: json['match_subject'] as String?,
    );
  }

  AppNotification markRead() => AppNotification(
    id: id,
    category: category,
    title: title,
    body: body,
    timestamp: timestamp,
    itemId: itemId,
    read: true,
    targetKind: targetKind,
    taskKey: taskKey,
    spaceKey: spaceKey,
    focusAt: focusAt,
    matchSubject: matchSubject,
  );
}
