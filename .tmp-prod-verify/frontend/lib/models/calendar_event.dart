class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.subject,
    required this.start,
    required this.end,
    required this.location,
    required this.organizer,
    this.organizerEmail,
    this.myResponseType,
    this.isMeeting = false,
    this.isResponseRequested,
    this.needsResponse = false,
    this.mailbox,
    this.ownerName,
    this.busyStatus,
    this.isPrivate = false,
    this.isLimited = false,
    this.isColleague = false,
    this.colorIndex,
    this.body,
    this.bodyType = 'text',
    this.attendees = const [],
    this.detailLoaded = false,
    this.isRecurring = false,
  });

  final String id;
  final String subject;
  final DateTime? start;
  final DateTime? end;
  final String? location;
  final String? organizer;
  final String? organizerEmail;
  final String? myResponseType;
  final bool isMeeting;
  final bool? isResponseRequested;
  final bool needsResponse;
  final String? mailbox;
  final String? ownerName;
  final String? busyStatus;
  final bool isPrivate;
  final bool isLimited;
  final bool isColleague;
  final int? colorIndex;
  final String? body;
  final String bodyType;
  final List<CalendarAttendee> attendees;
  final bool detailLoaded;
  final bool isRecurring;

  bool get isAccepted => myResponseType == 'Accept';
  bool get isDeclined => myResponseType == 'Decline';
  bool get isTentative => myResponseType == 'Tentative';
  bool get isOrganizer => myResponseType == 'Organizer';

  bool authoredBy({String? email, String? displayName}) {
    if (isColleague) return false;
    if (isOrganizer) return true;
    final organizerName = organizer?.trim() ?? '';
    if (!isMeeting &&
        organizerName.isEmpty &&
        (organizerEmail ?? '').trim().isEmpty) {
      return true;
    }
    final ownerEmail = email?.trim().toLowerCase();
    final mail = organizerEmail?.trim().toLowerCase();
    if (ownerEmail != null &&
        ownerEmail.isNotEmpty &&
        mail != null &&
        mail == ownerEmail) {
      return true;
    }
    final ownerName = displayName?.trim().toLowerCase();
    final name = organizerName.toLowerCase();
    if (ownerName != null && ownerName.isNotEmpty && name == ownerName) {
      return true;
    }
    return false;
  }

  String get plainBody {
    final raw = body?.trim() ?? '';
    if (raw.isEmpty || bodyType != 'html') return raw;
    return raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String get responseLabel => switch (myResponseType) {
    'Accept' => 'Принято',
    'Decline' => 'Отклонено',
    'Tentative' => 'Предварительно',
    'Organizer' => 'Организатор',
    'NoResponseReceived' => 'Ожидает ответа',
    'Unknown' => 'Неизвестно',
    _ => '—',
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? '(без темы)',
      start: json['start'] != null
          ? DateTime.parse(json['start'] as String)
          : null,
      end: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
      location: json['location'] as String?,
      organizer: json['organizer'] as String?,
      organizerEmail: json['organizer_email'] as String?,
      myResponseType: json['my_response_type'] as String?,
      isMeeting: json['is_meeting'] as bool? ?? false,
      isResponseRequested: json['is_response_requested'] as bool?,
      needsResponse: json['needs_response'] as bool? ?? false,
      mailbox: json['mailbox'] as String?,
      ownerName: json['owner_name'] as String?,
      busyStatus: json['busy_status'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      isLimited: json['is_limited'] as bool? ?? false,
      body: json['body'] as String?,
      bodyType: json['body_type'] as String? ?? 'text',
      isRecurring: json['is_recurring'] as bool? ?? false,
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? subject,
    DateTime? start,
    DateTime? end,
    String? location,
    String? organizer,
    String? organizerEmail,
    String? myResponseType,
    bool? isMeeting,
    bool? isResponseRequested,
    bool? needsResponse,
    String? mailbox,
    String? ownerName,
    String? busyStatus,
    bool? isPrivate,
    bool? isLimited,
    bool? isColleague,
    int? colorIndex,
    String? body,
    String? bodyType,
    List<CalendarAttendee>? attendees,
    bool? detailLoaded,
    bool? isRecurring,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      start: start ?? this.start,
      end: end ?? this.end,
      location: location ?? this.location,
      organizer: organizer ?? this.organizer,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      myResponseType: myResponseType ?? this.myResponseType,
      isMeeting: isMeeting ?? this.isMeeting,
      isResponseRequested: isResponseRequested ?? this.isResponseRequested,
      needsResponse: needsResponse ?? this.needsResponse,
      mailbox: mailbox ?? this.mailbox,
      ownerName: ownerName ?? this.ownerName,
      busyStatus: busyStatus ?? this.busyStatus,
      isPrivate: isPrivate ?? this.isPrivate,
      isLimited: isLimited ?? this.isLimited,
      isColleague: isColleague ?? this.isColleague,
      colorIndex: colorIndex ?? this.colorIndex,
      body: body ?? this.body,
      bodyType: bodyType ?? this.bodyType,
      attendees: attendees ?? this.attendees,
      detailLoaded: detailLoaded ?? this.detailLoaded,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }
}

class CalendarAttendee {
  const CalendarAttendee({
    required this.name,
    this.email,
    this.responseType,
    this.optional = false,
  });

  final String name;
  final String? email;
  final String? responseType;
  final bool optional;

  String get responseLabel => switch (responseType) {
    'Accept' => 'Принято',
    'Decline' => 'Отклонено',
    'Tentative' => 'Предварительно',
    'Organizer' => 'Организатор',
    'NoResponseReceived' || 'Unknown' => 'Нет ответа',
    _ => '',
  };
}

enum CalendarEventResponseAction {
  accept('accept'),
  decline('decline'),
  tentative('tentative');

  const CalendarEventResponseAction(this.apiValue);

  final String apiValue;
}
