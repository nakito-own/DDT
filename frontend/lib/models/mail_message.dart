class MailAttachment {
  const MailAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.contentType,
  });

  final String id;
  final String name;
  final int size;
  final String contentType;

  factory MailAttachment.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) {
      throw FormatException('Mail attachment id is missing');
    }
    return MailAttachment(
      id: id,
      name: json['name'] as String? ?? 'attachment',
      size: (json['size'] as num?)?.toInt() ?? 0,
      contentType:
          json['content_type'] as String? ?? 'application/octet-stream',
    );
  }

  String get displaySize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MailArchiveResult {
  const MailArchiveResult({required this.archivedIds, required this.errors});

  final List<String> archivedIds;
  final Map<String, String> errors;

  factory MailArchiveResult.fromJson(Map<String, dynamic> json) {
    return MailArchiveResult(
      archivedIds: (json['archived_ids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      errors: (json['errors'] as Map<String, dynamic>? ?? const {}).map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }
}

class MailMessage {
  const MailMessage({
    required this.id,
    required this.folderId,
    required this.subject,
    required this.sender,
    required this.datetimeReceived,
    required this.isRead,
    required this.preview,
    this.hasAttachments = false,
    this.body,
    this.bodyType = 'text',
    this.attachments = const [],
    this.detailLoaded = false,
  });

  final String id;
  final String folderId;
  final String subject;
  final String? sender;
  final DateTime? datetimeReceived;
  final bool isRead;
  final String preview;
  final bool hasAttachments;
  final String? body;
  final String bodyType;
  final List<MailAttachment> attachments;
  final bool detailLoaded;

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    final attachments = <MailAttachment>[];
    for (final entry in json['attachments'] as List<dynamic>? ?? const []) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        attachments.add(MailAttachment.fromJson(entry));
      } catch (_) {
        // Skip malformed attachment entries instead of failing the whole message.
      }
    }

    return MailMessage(
      id: json['id'] as String,
      folderId: json['folder_id'] as String? ?? '',
      subject: json['subject'] as String? ?? '(без темы)',
      sender: json['sender'] as String?,
      datetimeReceived: json['datetime_received'] != null
          ? DateTime.parse(json['datetime_received'] as String)
          : null,
      isRead: json['is_read'] as bool? ?? false,
      preview: json['preview'] as String? ?? '',
      hasAttachments: json['has_attachments'] as bool? ?? false,
      body: json['body'] as String?,
      bodyType: json['body_type'] as String? ?? 'text',
      attachments: attachments,
      detailLoaded: json['body'] != null,
    );
  }

  MailMessage copyWith({
    String? id,
    String? folderId,
    String? subject,
    String? sender,
    DateTime? datetimeReceived,
    bool? isRead,
    String? preview,
    bool? hasAttachments,
    String? body,
    String? bodyType,
    List<MailAttachment>? attachments,
    bool? detailLoaded,
  }) {
    return MailMessage(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      subject: subject ?? this.subject,
      sender: sender ?? this.sender,
      datetimeReceived: datetimeReceived ?? this.datetimeReceived,
      isRead: isRead ?? this.isRead,
      preview: preview ?? this.preview,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      body: body ?? this.body,
      bodyType: bodyType ?? this.bodyType,
      attachments: attachments ?? this.attachments,
      detailLoaded: detailLoaded ?? this.detailLoaded,
    );
  }
}

class MailFolders {
  const MailFolders({
    required this.inbox,
    required this.sent,
    required this.inboxFolderId,
    required this.sentFolderId,
    required this.folders,
  });

  final int inbox;
  final int sent;
  final String inboxFolderId;
  final String sentFolderId;
  final List<MailFolderNode> folders;

  factory MailFolders.fromJson(Map<String, dynamic> json) {
    return MailFolders(
      inbox: json['inbox'] as int? ?? 0,
      sent: json['sent'] as int? ?? 0,
      inboxFolderId: json['inbox_folder_id'] as String? ?? '',
      sentFolderId: json['sent_folder_id'] as String? ?? '',
      folders: (json['folders'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MailFolderNode.fromJson)
          .toList(),
    );
  }
}

class MailFolderNode {
  const MailFolderNode({
    required this.id,
    required this.name,
    required this.totalCount,
    required this.unreadCount,
    required this.children,
  });

  final String id;
  final String name;
  final int totalCount;
  final int unreadCount;
  final List<MailFolderNode> children;

  factory MailFolderNode.fromJson(Map<String, dynamic> json) {
    return MailFolderNode(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Без имени',
      totalCount: json['total_count'] as int? ?? 0,
      unreadCount: json['unread_count'] as int? ?? 0,
      children: (json['children'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MailFolderNode.fromJson)
          .toList(),
    );
  }
}
