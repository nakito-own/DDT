enum AppNotificationCategory {
  newMail('new_mail'),
  mailUpdated('mail_updated'),
  calendarUpdated('calendar_updated'),
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

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.timestamp,
    this.itemId,
    this.read = false,
  });

  final String id;
  final AppNotificationCategory category;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? itemId;
  final bool read;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      category: AppNotificationCategory.fromApi(
        json['category'] as String? ?? 'system',
      ),
      title: json['title'] as String? ?? 'Уведомление',
      body: json['body'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      itemId: json['item_id'] as String?,
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
  );
}
