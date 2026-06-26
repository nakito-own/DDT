class MailMessage {
  const MailMessage({
    required this.id,
    required this.subject,
    required this.sender,
    required this.datetimeReceived,
    required this.isRead,
    required this.preview,
    this.body,
    this.bodyType = 'text',
  });

  final String id;
  final String subject;
  final String? sender;
  final DateTime? datetimeReceived;
  final bool isRead;
  final String preview;
  final String? body;
  final String bodyType;

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    return MailMessage(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? '(без темы)',
      sender: json['sender'] as String?,
      datetimeReceived: json['datetime_received'] != null
          ? DateTime.parse(json['datetime_received'] as String)
          : null,
      isRead: json['is_read'] as bool? ?? false,
      preview: json['preview'] as String? ?? '',
      body: json['body'] as String?,
      bodyType: json['body_type'] as String? ?? 'text',
    );
  }

  MailMessage copyWith({
    String? id,
    String? subject,
    String? sender,
    DateTime? datetimeReceived,
    bool? isRead,
    String? preview,
    String? body,
    String? bodyType,
  }) {
    return MailMessage(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      sender: sender ?? this.sender,
      datetimeReceived: datetimeReceived ?? this.datetimeReceived,
      isRead: isRead ?? this.isRead,
      preview: preview ?? this.preview,
      body: body ?? this.body,
      bodyType: bodyType ?? this.bodyType,
    );
  }
}

class MailFolders {
  const MailFolders({required this.inbox, required this.sent});

  final int inbox;
  final int sent;

  factory MailFolders.fromJson(Map<String, dynamic> json) {
    return MailFolders(
      inbox: json['inbox'] as int? ?? 0,
      sent: json['sent'] as int? ?? 0,
    );
  }
}
