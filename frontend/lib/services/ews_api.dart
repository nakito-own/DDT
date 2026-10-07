import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:web/web.dart' as web;

import '../models/calendar_event.dart';
import '../models/colleague_calendar.dart';
import '../models/contact.dart';
import '../models/mail_inbox_options.dart';
import '../models/mail_message.dart';
import '../models/user_profile.dart';
import 'api_client.dart';
import 'owa_client.dart';

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
  EwsApi({ApiClient? client})
    : _client = client ?? apiClient,
      _owa = OwaClient(client ?? apiClient);

  static const _sessionRestoreTimeout = Duration(seconds: 25);

  final ApiClient _client;
  final OwaClient _owa;
  String? _accountEmail;

  Future<EwsSession> login({
    required String username,
    required String password,
    required String email,
    required bool rememberMe,
  }) async {
    final response = await _client.post(
      '/api/ews/auth/login',
      auth: false,
      timeout: ApiClient.loginTimeout,
      body: {
        'username': username,
        'password': password,
        'email': email,
        'remember_me': rememberMe,
      },
    );

    if (response.statusCode != 200) {
      final detail = _readError(response);
      if (response.statusCode == 401) {
        throw Exception(detail ?? 'Неверный логин или пароль');
      }
      if (response.statusCode == 502) {
        throw Exception(
          detail ??
              'Exchange временно недоступен. Проверьте VPN и попробуйте снова.',
        );
      }
      throw Exception(detail ?? 'Не удалось войти в Exchange');
    }

    final data = ApiClient.decodeMap(response);
    await _client.setSessionToken(data['session_token'] as String);
    _accountEmail = data['email'] as String?;

    return _sessionFromAuthPayload(data, rememberMe: rememberMe, connected: true);
  }

  EwsSession _sessionFromAuthPayload(
    Map<String, dynamic> data, {
    required bool rememberMe,
    required bool connected,
  }) {
    return EwsSession(
      email: data['email'] as String,
      connected: connected,
      rememberMe: rememberMe,
      expiresAt: DateTime.parse(data['expires_at'] as String),
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<void> logout() async {
    await _client.post('/api/ews/auth/logout');
    _owa.clear();
    _accountEmail = null;
    await _client.clearSessionToken();
  }

  Future<EwsSession?> restoreSession() async {
    final token = await _client.getSessionToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return await _client.runSilentlyUnauthorized(
        () => fetchMe().timeout(_sessionRestoreTimeout),
      );
    } on TimeoutException {
      await _client.clearSessionToken();
      return null;
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
    final data = ApiClient.decodeMap(response);
    _accountEmail = data['email'] as String?;
    return EwsSession.fromJson(data);
  }

  Future<MailFolders> fetchMailFolders() {
    return _owa.fetchMailFolders();
  }

  Future<List<MailMessage>> fetchInbox({
    int limit = 50,
    int offset = 0,
    MailInboxFilter filter = MailInboxFilter.all,
    MailInboxSort sort = MailInboxSort.dateDesc,
    String? folderId,
    String? search,
  }) async {
    return _owa.fetchInbox(
      limit: limit,
      offset: offset,
      filter: filter,
      sort: sort,
      folderId: folderId,
      userEmail: _accountEmail,
      search: search,
    );
  }

  Future<List<MailMessage>> fetchConversationMessages(String conversationId) {
    return _owa.fetchConversationMessages(conversationId);
  }

  Future<void> pinMessage(String itemId, {required bool pinned}) {
    return _owa.pinMessage(itemId, pinned: pinned);
  }

  Future<void> setConversationFlag({
    required String conversationId,
    required String? folderId,
    required bool flagged,
    String? itemId,
  }) {
    return _owa.setConversationFlag(
      conversationId: conversationId,
      folderId: folderId,
      flagged: flagged,
      itemId: itemId,
    );
  }

  Future<void> markConversationUnread({
    required String conversationId,
    required String? folderId,
    String? itemId,
  }) {
    return _owa.markConversationUnread(
      conversationId: conversationId,
      folderId: folderId,
      itemId: itemId,
    );
  }

  Future<void> deleteConversation({
    required String conversationId,
    required String? folderId,
    String? itemId,
  }) {
    return _owa.deleteConversation(
      conversationId: conversationId,
      folderId: folderId,
      itemId: itemId,
    );
  }

  Future<MailMessage> fetchMessage(
    String messageId, {
    bool markRead = true,
    String? folderId,
  }) {
    return _owa.fetchMessage(
      messageId,
      markRead: markRead,
      folderId: folderId,
    );
  }

  Future<void> markMessageRead(String messageId, {String? folderId}) {
    return _owa.markMessageRead(messageId);
  }

  Future<void> sendMail({
    required List<String> to,
    required String subject,
    required String body,
    List<String> cc = const [],
  }) {
    return _owa.sendMail(to: to, subject: subject, body: body, cc: cc);
  }

  Future<void> downloadAttachment(
    String messageId, {
    required String attachmentId,
    required String filename,
    required String contentType,
    String? folderId,
  }) async {
    final bytes = await _owa.fetchAttachmentBytes(attachmentId);
    _triggerBrowserDownload(
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      mimeType: contentType,
    );
  }

  Future<MailArchiveResult> archiveMessages(
    List<String> messageIds, {
    String? folderId,
  }) {
    return _owa.archiveMessages(messageIds);
  }

  Future<List<CalendarEvent>> fetchCalendarEvents({
    DateTime? start,
    DateTime? end,
  }) {
    return _owa.fetchCalendarEvents(start: start, end: end);
  }

  Future<CalendarEvent> fetchCalendarEventDetail(CalendarEvent event) {
    return _owa.fetchCalendarEventDetail(event);
  }

  Future<CalendarEvent> createCalendarEvent({
    required String subject,
    required DateTime start,
    required DateTime end,
    String? location,
    String? body,
  }) {
    return _owa.createCalendarEvent(
      subject: subject,
      start: start,
      end: end,
      location: location,
      body: body,
    );
  }

  Future<CalendarEvent> respondToCalendarEvent(
    String eventId,
    CalendarEventResponseAction action,
  ) {
    return _owa.respondToCalendarEvent(eventId, action);
  }

  Future<List<CalendarPerson>> searchCalendarPeople(String query) {
    return _owa.searchCalendarPeople(query, ownEmail: _accountEmail);
  }

  Future<ColleagueCalendar> fetchColleagueCalendar({
    required String email,
    required int colorIndex,
    bool enabled = true,
    DateTime? start,
    DateTime? end,
  }) {
    return _owa.fetchColleagueCalendar(
      email: email,
      colorIndex: colorIndex,
      enabled: enabled,
      start: start,
      end: end,
      ownEmail: _accountEmail,
    );
  }

  Future<List<ColleagueCalendar>> fetchColleagueCalendars({
    required List<ColleagueCalendar> calendars,
    DateTime? start,
    DateTime? end,
  }) {
    if (calendars.isEmpty) return Future.value(const []);
    return _owa.fetchColleagueCalendars(
      calendars: calendars,
      start: start,
      end: end,
      ownEmail: _accountEmail,
    );
  }

  Future<List<Contact>> fetchContacts({
    int limit = 100,
    String search = '',
  }) {
    return _owa.fetchContacts(limit: limit, search: search);
  }

  String? _readError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map) return data['detail']?.toString();
    } catch (_) {
      return null;
    }
    return null;
  }
}

void _triggerBrowserDownload({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) {
  final blob = web.Blob(
    <JSAny>[bytes.buffer.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

final ewsApi = EwsApi();
