class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.subject,
    required this.start,
    required this.end,
    required this.location,
    required this.organizer,
    this.myResponseType,
    this.isMeeting = false,
    this.isResponseRequested,
    this.needsResponse = false,
  });

  final String id;
  final String subject;
  final DateTime? start;
  final DateTime? end;
  final String? location;
  final String? organizer;
  final String? myResponseType;
  final bool isMeeting;
  final bool? isResponseRequested;
  final bool needsResponse;

  bool get isAccepted => myResponseType == 'Accept';
  bool get isDeclined => myResponseType == 'Decline';
  bool get isTentative => myResponseType == 'Tentative';
  bool get isOrganizer => myResponseType == 'Organizer';

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
      myResponseType: json['my_response_type'] as String?,
      isMeeting: json['is_meeting'] as bool? ?? false,
      isResponseRequested: json['is_response_requested'] as bool?,
      needsResponse: json['needs_response'] as bool? ?? false,
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? subject,
    DateTime? start,
    DateTime? end,
    String? location,
    String? organizer,
    String? myResponseType,
    bool? isMeeting,
    bool? isResponseRequested,
    bool? needsResponse,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      start: start ?? this.start,
      end: end ?? this.end,
      location: location ?? this.location,
      organizer: organizer ?? this.organizer,
      myResponseType: myResponseType ?? this.myResponseType,
      isMeeting: isMeeting ?? this.isMeeting,
      isResponseRequested: isResponseRequested ?? this.isResponseRequested,
      needsResponse: needsResponse ?? this.needsResponse,
    );
  }
}

enum CalendarEventResponseAction {
  accept('accept'),
  decline('decline'),
  tentative('tentative');

  const CalendarEventResponseAction(this.apiValue);

  final String apiValue;
}
