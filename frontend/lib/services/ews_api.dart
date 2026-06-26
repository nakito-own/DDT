import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import '../models/contact.dart';
import '../models/mail_message.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

class EwsSession {
  const EwsSession({
    required this.email,
    required this.connected,
    required this.rememberMe,
    required this.expiresAt,
    required this.user,
  });

  final String email;
  final bool connected;
  final bool rememberMe;
  final DateTime expiresAt;
  final UserProfile user;

  factory EwsSession.fromJson(Map<String, dynamic> json) {
    return EwsSession(
      email: json['email'] as String,
      connected: json['connected'] as bool? ?? false,
      rememberMe: json['remember_me'] as bool? ?? false,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class EwsApi {
  EwsApi({ApiClient? client}) : _client = client ?? apiClient;

  final ApiClient _client;

  Future<EwsSession> login({
    required String username,
    required String password,
    required String email,
    required bool rememberMe,
  }) async {
    final response = await _client.post(
      '/api/ews/auth/login',
      auth: false,
      body: {
        'username': username,
        'password': password,
        'email': email,
        'remember_me': rememberMe,
      },
    );

    if (response.statusCode != 200) {
      final detail = _readError(response);
      throw Exception(detail ?? 'Не удалось войти в Exchange');
    }

    final data = ApiClient.decodeMap(response);
    await _client.setSessionToken(data['session_token'] as String);

    return fetchMe();
  }

  Future<void> logout() async {
    await _client.post('/api/ews/auth/logout');
    await _client.clearSessionToken();
  }

  Future<EwsSession?> restoreSession() async {
    final token = await _client.getSessionToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return await fetchMe();
    } catch (_) {
      await _client.clearSessionToken();
      return null;
    }
  }

  Future<EwsSession> fetchMe() async {
    final response = await _client.get('/api/ews/auth/me');
    if (response.statusCode != 200) {
      throw Exception('Session is invalid');
    }
    return EwsSession.fromJson(ApiClient.decodeMap(response));
  }

  Future<MailFolders> fetchMailFolders() async {
    final response = await _client.get('/api/ews/mail/folders');
    _ensureSuccess(response);
    return MailFolders.fromJson(ApiClient.decodeMap(response));
  }

  Future<List<MailMessage>> fetchInbox({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.get(
      '/api/ews/mail/inbox',
      query: {
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    _ensureSuccess(response);
    return ApiClient.decodeList(response).map(MailMessage.fromJson).toList();
  }

  Future<MailMessage> fetchMessage(
    String messageId, {
    bool markRead = true,
  }) async {
    final encodedId = Uri.encodeComponent(messageId);
    final response = await _client.get(
      '/api/ews/mail/messages/$encodedId',
      query: {
        'mark_read': '$markRead',
      },
    );
    _ensureSuccess(response);
    return MailMessage.fromJson(ApiClient.decodeMap(response));
  }

  Future<void> markMessageRead(String messageId) async {
    final encodedId = Uri.encodeComponent(messageId);
    final response = await _client.post(
      '/api/ews/mail/messages/$encodedId/read',
    );
    _ensureSuccess(response);
  }

  Future<void> sendMail({
    required List<String> to,
    required String subject,
    required String body,
    List<String> cc = const [],
  }) async {
    final response = await _client.post(
      '/api/ews/mail/send',
      body: {
        'to': to,
        'cc': cc,
        'subject': subject,
        'body': body,
      },
    );
    _ensureSuccess(response);
  }

  Future<List<CalendarEvent>> fetchCalendarEvents({
    DateTime? start,
    DateTime? end,
  }) async {
    final query = <String, String>{};
    if (start != null) {
      query['start'] = start.toUtc().toIso8601String();
    }
    if (end != null) {
      query['end'] = end.toUtc().toIso8601String();
    }

    final response = await _client.get('/api/ews/calendar/events', query: query);
    _ensureSuccess(response);
    return ApiClient.decodeList(response).map(CalendarEvent.fromJson).toList();
  }

  Future<CalendarEvent> createCalendarEvent({
    required String subject,
    required DateTime start,
    required DateTime end,
    String? location,
    String? body,
  }) async {
    final response = await _client.post(
      '/api/ews/calendar/events',
      body: {
        'subject': subject,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        if (location != null && location.isNotEmpty) 'location': location,
        if (body != null && body.isNotEmpty) 'body': body,
      },
    );
    _ensureSuccess(response);
    return CalendarEvent.fromJson(ApiClient.decodeMap(response));
  }

  Future<CalendarEvent> respondToCalendarEvent(
    String eventId,
    CalendarEventResponseAction action,
  ) async {
    final encodedId = Uri.encodeComponent(eventId);
    final response = await _client.post(
      '/api/ews/calendar/events/$encodedId/response',
      body: {
        'response': action.apiValue,
      },
    );
    _ensureSuccess(response);
    return CalendarEvent.fromJson(ApiClient.decodeMap(response));
  }

  Future<List<Contact>> fetchContacts({
    int limit = 100,
    String search = '',
  }) async {
    final response = await _client.get(
      '/api/ews/contacts',
      query: {
        'limit': '$limit',
        if (search.isNotEmpty) 'search': search,
      },
    );
    _ensureSuccess(response);
    return ApiClient.decodeList(response).map(Contact.fromJson).toList();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw Exception(_readError(response) ?? 'Ошибка запроса к Exchange');
  }

  String? _readError(http.Response response) {
    try {
      final data = ApiClient.decodeMap(response);
      return data['detail']?.toString();
    } catch (_) {
      return null;
    }
  }
}

final ewsApi = EwsApi();
