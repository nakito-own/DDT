import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import '../models/colleague_calendar.dart';
import '../models/contact.dart';
import '../models/mail_inbox_options.dart';
import '../models/mail_message.dart';
import 'api_client.dart';

const owaTimeZoneId = 'Belarus Standard Time';

/// Talks to Outlook Web App `service.svc` using the same JSON actions as the
/// official OWA client. The backend only attaches NTLM credentials.
class OwaClient {
  OwaClient(this._client);

  final ApiClient _client;
  String? _calendarFolderId;

  void clear() {
    _calendarFolderId = null;
  }

  Future<MailFolders> fetchMailFolders() async {
    final inbox = await _distinguishedFolderNode('inbox');
    final sent = await _distinguishedFolderNode('sentitems');
    final root = await _distinguishedFolderNode('msgfolderroot');

    final discovered = <_OwaFolder>[];
    var offset = 0;
    for (var page = 0; page < 5; page++) {
      final found = await _call('FindFolder', _findFolderBody(offset: offset));
      final batch = _foldersFromFindFolder(found);
      discovered.addAll(batch.folders);
      if (batch.includesLast || batch.folders.isEmpty) break;
      offset = batch.nextOffset;
    }

    final byId = <String, _OwaFolder>{
      for (final folder in discovered) folder.id: folder,
    };
    if (inbox != null) byId[inbox.id] = inbox;
    if (sent != null) byId[sent.id] = sent;

    final rootId = root?.id ?? inbox?.parentId ?? '';
    return MailFolders(
      inbox: inbox?.totalCount ?? 0,
      sent: sent?.totalCount ?? 0,
      inboxFolderId: inbox?.id ?? '',
      sentFolderId: sent?.id ?? '',
      folders: _buildMailFolderTree(byId.values.toList(), rootId),
    );
  }

  Future<_OwaFolder?> _distinguishedFolderNode(String role) async {
    final json = await _call(
      'GetFolder',
      _getFolderBody([_distinguishedFolder(role)]),
    );
    final folders = _foldersFromGetFolder(json);
    if (folders.isEmpty) return null;
    final folder = folders.first;
    return _OwaFolder(
      id: folder.id,
      parentId: folder.parentId,
      name: folder.name,
      totalCount: folder.totalCount,
      unreadCount: folder.unreadCount,
    );
  }

  Future<List<MailMessage>> fetchInbox({
    int limit = 50,
    int offset = 0,
    MailInboxFilter filter = MailInboxFilter.all,
    MailInboxSort sort = MailInboxSort.dateDesc,
    String? folderId,
    String? userEmail,
    String? search,
  }) async {
    final query = search?.trim() ?? '';
    if (query.isNotEmpty) {
      return _searchConversations(
        query: query,
        folderId: folderId,
        offset: offset,
        limit: limit,
      );
    }
    if (filter == MailInboxFilter.mentions) {
      return _fetchMentions(
        limit: limit,
        offset: offset,
        sort: sort,
        folderId: folderId,
        userEmail: userEmail,
      );
    }
    final dateSort =
        sort == MailInboxSort.dateDesc || sort == MailInboxSort.dateAsc;
    if (!dateSort) {
      final items = await _findMailItems(
        folderId: folderId,
        offset: offset,
        limit: limit,
        filter: filter,
        sort: sort,
      );
      return [
        for (final item in items)
          if (mailMessageFromOwaItem(item).id.isNotEmpty)
            mailMessageFromOwaItem(item, folderId: folderId),
      ];
    }

    final conversations = await _findConversations(
      folderId: folderId,
      offset: offset,
      limit: limit,
      filter: filter,
      sort: sort,
    );
    return [
      for (final item in conversations)
        if (mailMessageFromConversation(item, folderId: folderId).id.isNotEmpty)
          mailMessageFromConversation(item, folderId: folderId),
    ];
  }

  Future<List<MailMessage>> fetchConversationMessages(
    String conversationId,
  ) async {
    final json = await _call(
      'GetConversationItems',
      _conversationItemsBody(conversationId),
    );
    return messagesFromConversationItems(json);
  }

  Future<void> pinMessage(String itemId, {required bool pinned}) {
    return _call('UpdateItem', _pinBody(itemId, pinned: pinned)).then((_) {});
  }

  Future<void> setConversationFlag({
    required String conversationId,
    required String? folderId,
    required bool flagged,
    String? itemId,
  }) {
    if (conversationId.isEmpty) {
      return _call(
        'UpdateItem',
        _flagItemBody(itemId ?? '', flagged: flagged),
      ).then((_) {});
    }
    return _call(
      'ApplyConversationAction',
      _conversationActionBody(
        conversationId: conversationId,
        folderId: folderId,
        action: 'Flag',
        flagStatus: flagged ? 'Flagged' : 'NotFlagged',
      ),
    ).then((_) {});
  }

  Future<void> markConversationUnread({
    required String conversationId,
    required String? folderId,
    String? itemId,
  }) {
    if (conversationId.isEmpty) {
      return _call(
        'UpdateItem',
        _markReadBody(itemId ?? '', isRead: false),
      ).then((_) {});
    }
    return _call(
      'ApplyConversationAction',
      _conversationActionBody(
        conversationId: conversationId,
        folderId: folderId,
        action: 'SetReadState',
        isRead: false,
      ),
    ).then((_) {});
  }

  Future<void> deleteConversation({
    required String conversationId,
    required String? folderId,
    String? itemId,
  }) {
    if (conversationId.isEmpty) {
      return _moveItems([itemId ?? ''], 'deleteditems');
    }
    return _call(
      'ApplyConversationAction',
      _conversationActionBody(
        conversationId: conversationId,
        folderId: folderId,
        action: 'Delete',
        deleteType: 'MoveToDeletedItems',
      ),
    ).then((_) {});
  }

  Future<List<MailMessage>> _fetchMentions({
    required int limit,
    required int offset,
    required MailInboxSort sort,
    required String? folderId,
    required String? userEmail,
  }) async {
    if (userEmail == null || userEmail.isEmpty) return const [];
    final matched = <MailMessage>[];
    var pageOffset = 0;
    var scanned = 0;
    while (matched.length < offset + limit && scanned < 400) {
      final items = await _findMailItems(
        folderId: folderId,
        offset: pageOffset,
        limit: 50,
        filter: MailInboxFilter.all,
        sort: sort,
      );
      if (items.isEmpty) break;
      scanned += items.length;
      for (final item in items) {
        final message = mailMessageFromOwaItem(item, folderId: folderId);
        if (message.id.isEmpty) continue;
        if (_isMention(message, userEmail)) matched.add(message);
      }
      if (items.length < 50) break;
      pageOffset += items.length;
    }
    if (matched.length <= offset) return const [];
    return matched.skip(offset).take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> _findMailItems({
    required String? folderId,
    required int offset,
    required int limit,
    required MailInboxFilter filter,
    required MailInboxSort sort,
  }) async {
    final sortSpec = _mailSort(sort);
    final json = await _call('FindItem', {
      '__type': 'FindItemJsonRequest:#Exchange',
      'Header': owaHeader('Exchange2016'),
      'Body': {
        '__type': 'FindItemRequest:#Exchange',
        'ItemShape': {
          '__type': 'ItemResponseShape:#Exchange',
          'BaseShape': 'IdOnly',
        },
        'ParentFolderIds': [
          folderId == null || folderId.isEmpty
              ? _distinguishedFolder('inbox')
              : _folderId(folderId),
        ],
        'Traversal': 'Shallow',
        'Paging': _page(offset, limit),
        'ViewFilter': _mailViewFilter(filter),
        'IsWarmUpSearch': false,
        'FocusedViewFilter': -1,
        'Grouping': null,
        'ShapeName': 'MailListItem',
        'SortOrder': [_sortOrder(sortSpec.$1, sortSpec.$2)],
      },
    });
    return findItemResults(json);
  }

  Future<List<Map<String, dynamic>>> _findConversations({
    required String? folderId,
    required int offset,
    required int limit,
    required MailInboxFilter filter,
    required MailInboxSort sort,
  }) async {
    final json = await _call('FindConversation', {
      '__type': 'FindConversationJsonRequest:#Exchange',
      'Header': owaHeader('V2016_02_03'),
      'Body': {
        '__type': 'FindConversationRequest:#Exchange',
        'ParentFolderId': {
          '__type': 'TargetFolderId:#Exchange',
          'BaseFolderId': _mailFolderRef(folderId),
        },
        'ConversationShape': {
          '__type': 'ConversationResponseShape:#Exchange',
          'BaseShape': 'IdOnly',
        },
        'ShapeName': 'ConversationListView',
        'Paging': _page(offset, limit),
        'ViewFilter': _mailViewFilter(filter),
        'FocusedViewFilter': -1,
        'SortOrder': [
          _sortOrder(
            'ConversationLastDeliveryTime',
            sort == MailInboxSort.dateAsc ? 'Ascending' : 'Descending',
          ),
        ],
      },
    });
    final raw = asMap(json['Body'])?['Conversations'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (asMap(entry) != null) asMap(entry)!,
    ];
  }

  Future<List<MailMessage>> _searchConversations({
    required String query,
    required String? folderId,
    required int offset,
    required int limit,
  }) async {
    // This Exchange build rejects ExecuteSearch, and QueryString returns an
    // empty view, so the folder is scanned through the same FindItem call the
    // mailbox list uses.
    final needle = query.toLowerCase();
    final matches = <MailMessage>[];
    final needed = offset + limit;
    const pageSize = 100;
    const maxPages = 8;
    var pageOffset = 0;
    for (var page = 0; page < maxPages && matches.length < needed; page++) {
      final items = await _findMailItems(
        folderId: folderId,
        offset: pageOffset,
        limit: pageSize,
        filter: MailInboxFilter.all,
        sort: MailInboxSort.dateDesc,
      );
      if (items.isEmpty) break;
      for (final item in items) {
        final message = mailMessageFromOwaItem(item, folderId: folderId);
        if (message.id.isEmpty) continue;
        final haystack =
            '${message.subject} ${message.sender ?? ''} ${message.preview}'
                .toLowerCase();
        if (haystack.contains(needle)) matches.add(message);
      }
      if (items.length < pageSize) break;
      pageOffset += items.length;
    }
    if (offset >= matches.length) return const [];
    return matches.skip(offset).take(limit).toList();
  }

  Future<void> _moveItems(List<String> itemIds, String distinguished) {
    return _call('MoveItem', {
      '__type': 'MoveItemJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'MoveItemRequest:#Exchange',
        'ToFolderId': {
          '__type': 'TargetFolderId:#Exchange',
          'BaseFolderId': _distinguishedFolder(distinguished),
        },
        'ItemIds': [
          for (final id in itemIds) {'__type': 'ItemId:#Exchange', 'Id': id},
        ],
      },
    }).then((_) {});
  }

  Future<MailMessage> fetchMessage(
    String messageId, {
    bool markRead = true,
    String? folderId,
  }) async {
    if (markRead) {
      await _call('UpdateItem', _markReadBody(messageId));
    }
    final json = await _call('GetItem', _getMailItemBody(messageId));
    final item = firstItem(json);
    if (item == null) {
      throw Exception('Письмо не найдено');
    }
    final normalized = asMap(item['NormalizedBody']);
    final html = normalized?['Value'] as String?;
    return mailMessageFromOwaItem(
      item,
      folderId: folderId,
      body: html ?? item['Preview'] as String? ?? '',
      bodyType: html == null ? 'text' : 'html',
      attachments: attachmentsFromOwaItem(item),
      detailLoaded: true,
    );
  }

  Future<void> markMessageRead(String messageId) {
    return _call('UpdateItem', _markReadBody(messageId)).then((_) {});
  }

  Future<void> sendMail({
    required List<String> to,
    required String subject,
    required String body,
    List<String> cc = const [],
  }) {
    return _call('CreateItem', {
      '__type': 'CreateItemJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'CreateItemRequest:#Exchange',
        'MessageDisposition': 'SendAndSaveCopy',
        'Items': [
          {
            '__type': 'Message:#Exchange',
            'Subject': subject,
            'Body': {
              '__type': 'BodyContentType:#Exchange',
              'BodyType': 'Text',
              'Value': body,
            },
            'ToRecipients': [for (final address in to) _emailAddress(address)],
            if (cc.isNotEmpty)
              'CcRecipients': [
                for (final address in cc) _emailAddress(address),
              ],
          },
        ],
      },
    }).then((_) {});
  }

  Future<List<int>> fetchAttachmentBytes(String attachmentId) async {
    final json = await _call('GetAttachment', {
      '__type': 'GetAttachmentJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'GetAttachmentRequest:#Exchange',
        'AttachmentShape': {
          '__type': 'AttachmentResponseShape:#Exchange',
          'IncludeMimeContent': true,
        },
        'AttachmentIds': [
          {'__type': 'AttachmentId:#Exchange', 'Id': attachmentId},
        ],
      },
    });
    final content = _attachmentContent(json);
    if (content == null || content.isEmpty) {
      throw Exception('Вложение пустое');
    }
    return base64Decode(content);
  }

  Future<MailArchiveResult> archiveMessages(List<String> messageIds) async {
    final json = await _call('MoveItem', {
      '__type': 'MoveItemJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'MoveItemRequest:#Exchange',
        'ToFolderId': {
          '__type': 'TargetFolderId:#Exchange',
          'BaseFolderId': _distinguishedFolder('archive'),
        },
        'ItemIds': [
          for (final id in messageIds) {'__type': 'ItemId:#Exchange', 'Id': id},
        ],
      },
    }, strict: false);

    final messages = responseMessages(json);
    final archived = <String>[];
    final errors = <String, String>{};
    if (messages.isEmpty) {
      final code = asMap(json['Body'])?['ResponseCode'];
      final message = asMap(json['Body'])?['MessageText']?.toString();
      if (code is String && code != 'NoError') {
        for (final id in messageIds) {
          errors[id] = message ?? 'Не удалось архивировать';
        }
        return MailArchiveResult(archivedIds: archived, errors: errors);
      }
    }
    for (var index = 0; index < messageIds.length; index++) {
      final id = messageIds[index];
      final message = index < messages.length ? messages[index] : null;
      final code = message?['ResponseCode'];
      if (message == null || code == null || code == 'NoError') {
        archived.add(id);
      } else {
        errors[id] =
            message['MessageText']?.toString() ?? 'Не удалось архивировать';
      }
    }
    return MailArchiveResult(archivedIds: archived, errors: errors);
  }

  Future<List<CalendarEvent>> fetchCalendarEvents({
    DateTime? start,
    DateTime? end,
  }) async {
    final folderId = await _ownCalendarFolderId();
    final rangeStart = start ?? DateTime.now();
    final rangeEnd = end ?? rangeStart.add(const Duration(days: 7));
    final json = await _call(
      'GetCalendarView',
      _calendarViewBody(folderId, rangeStart, rangeEnd),
    );
    final raw = asMap(json['Body'])?['Items'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (asMap(entry) != null) calendarEventFromOwaItem(asMap(entry)!),
    ].where((event) => event.id.isNotEmpty).toList();
  }

  Future<CalendarEvent> fetchCalendarEventDetail(CalendarEvent event) async {
    if (event.isColleague || event.isLimited || event.id.isEmpty) return event;
    final json = await _call('GetItem', _calendarItemBody(event.id));
    final item = firstItem(json);
    if (item == null) return event;
    final detailed = calendarEventFromOwaItem(item);
    return event.copyWith(
      subject: detailed.subject,
      start: detailed.start ?? event.start,
      end: detailed.end ?? event.end,
      location: detailed.location ?? event.location,
      organizer: detailed.organizer ?? event.organizer,
      myResponseType: detailed.myResponseType ?? event.myResponseType,
      isMeeting: detailed.isMeeting || event.isMeeting,
      body: detailed.body,
      bodyType: detailed.bodyType,
      attendees: detailed.attendees,
      detailLoaded: true,
    );
  }

  Future<CalendarEvent> createCalendarEvent({
    required String subject,
    required DateTime start,
    required DateTime end,
    String? location,
    String? body,
  }) async {
    if (!end.isAfter(start)) {
      throw Exception('Окончание должно быть позже начала');
    }
    final json = await _call('CreateItem', {
      '__type': 'CreateItemJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'CreateItemRequest:#Exchange',
        'SendMeetingInvitations': 'SendToNone',
        'SavedItemFolderId': {
          '__type': 'TargetFolderId:#Exchange',
          'BaseFolderId': _distinguishedFolder('calendar'),
        },
        'Items': [
          {
            '__type': 'CalendarItem:#Exchange',
            'Subject': subject,
            'Start': owaTimestamp(start),
            'End': owaTimestamp(end),
            if (location != null && location.isNotEmpty)
              'Location': {
                '__type': 'EnhancedLocation:#Exchange',
                'DisplayName': location,
              },
            if (body != null && body.isNotEmpty)
              'Body': {
                '__type': 'BodyContentType:#Exchange',
                'BodyType': 'Text',
                'Value': body,
              },
          },
        ],
      },
    });
    final created = firstItem(json);
    if (created != null && itemIdOf(created) != null) {
      final event = calendarEventFromOwaItem(created);
      final returnedSubject = (created['Subject'] as String?)?.trim() ?? '';
      if (returnedSubject.isNotEmpty) return event;
      return event.copyWith(
        subject: subject,
        start: event.start ?? start,
        end: event.end ?? end,
        location: event.location ?? location,
      );
    }
    final id = created == null ? '' : itemIdOf(created) ?? '';
    return CalendarEvent(
      id: id,
      subject: subject,
      start: start,
      end: end,
      location: location,
      organizer: null,
    );
  }

  Future<CalendarEvent> respondToCalendarEvent(
    String eventId,
    CalendarEventResponseAction action,
  ) async {
    final typeName = switch (action) {
      CalendarEventResponseAction.accept => 'AcceptItem:#Exchange',
      CalendarEventResponseAction.decline => 'DeclineItem:#Exchange',
      CalendarEventResponseAction.tentative =>
        'TentativelyAcceptItem:#Exchange',
    };
    await _call('CreateItem', {
      '__type': 'CreateItemJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'CreateItemRequest:#Exchange',
        'MessageDisposition': 'SendAndSaveCopy',
        'Items': [
          {
            '__type': typeName,
            'ReferenceItemId': {'__type': 'ItemId:#Exchange', 'Id': eventId},
          },
        ],
      },
    });
    final json = await _call('GetItem', {
      '__type': 'GetItemJsonRequest:#Exchange',
      'Header': owaHeader('V2017_08_18'),
      'Body': {
        '__type': 'GetItemRequest:#Exchange',
        'ItemShape': {
          '__type': 'ItemResponseShape:#Exchange',
          'BaseShape': 'Default',
        },
        'ItemIds': [
          {'__type': 'ItemId:#Exchange', 'Id': eventId},
        ],
      },
    });
    final item = firstItem(json);
    if (item == null) {
      throw Exception('Событие не найдено');
    }
    return calendarEventFromOwaItem(item);
  }

  Future<List<CalendarPerson>> searchCalendarPeople(
    String query, {
    String? ownEmail,
    int limit = 20,
  }) async {
    final needle = query.trim();
    if (needle.isEmpty) return const [];
    final json = await _call('FindPeople', {
      '__type': 'FindPeopleJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'FindPeopleRequest:#Exchange',
        'IndexedPageItemView': _page(0, limit),
        'QueryString': needle,
        'ParentFolderId': {
          '__type': 'TargetFolderId:#Exchange',
          'BaseFolderId': _distinguishedFolder('directory'),
        },
        'PersonaShape': {
          '__type': 'PersonaResponseShape:#Exchange',
          'BaseShape': 'Default',
        },
        'ShouldResolveOneOffEmailAddress': false,
        'SearchPeopleSuggestionIndex': false,
      },
    });
    final raw = asMap(json['Body'])?['ResultSet'];
    if (raw is! List) return const [];
    final own = ownEmail?.toLowerCase();
    final people = <CalendarPerson>[];
    final seen = <String>{};
    for (final entry in raw) {
      final persona = asMap(entry);
      if (persona == null) continue;
      final mailbox = asMap(persona['EmailAddress']);
      final email = (mailbox?['EmailAddress'] as String?)?.toLowerCase();
      if (email == null ||
          email.isEmpty ||
          email == own ||
          seen.contains(email)) {
        continue;
      }
      final mailboxType = mailbox?['MailboxType']?.toString() ?? '';
      if (mailboxType.isNotEmpty &&
          mailboxType != 'Mailbox' &&
          mailboxType != 'OneOff') {
        continue;
      }
      seen.add(email);
      people.add(
        CalendarPerson(
          email: email,
          displayName: persona['DisplayName'] as String? ?? email,
        ),
      );
      if (people.length >= limit) break;
    }
    return people;
  }

  Future<ColleagueCalendar> fetchColleagueCalendar({
    required String email,
    required int colorIndex,
    bool enabled = true,
    DateTime? start,
    DateTime? end,
    String? ownEmail,
    String? displayName,
  }) async {
    final results = await fetchColleagueCalendars(
      calendars: [
        ColleagueCalendar(
          email: email,
          displayName: displayName ?? email,
          colorIndex: colorIndex,
          enabled: enabled,
        ),
      ],
      start: start,
      end: end,
      ownEmail: ownEmail,
    );
    if (results.isEmpty) {
      throw Exception(
        'Нельзя открыть собственный календарь как календарь коллеги',
      );
    }
    return results.first;
  }

  Future<List<ColleagueCalendar>> fetchColleagueCalendars({
    required List<ColleagueCalendar> calendars,
    DateTime? start,
    DateTime? end,
    String? ownEmail,
  }) async {
    final own = ownEmail?.toLowerCase();
    final rangeStart = start ?? DateTime.now();
    final rangeEnd = end ?? rangeStart.add(const Duration(days: 7));
    final ownFolderId = await _ownCalendarFolderId();
    final results = <ColleagueCalendar>[];
    for (final calendar in calendars) {
      final email = calendar.email.toLowerCase();
      if (own != null && email == own) continue;
      results.add(
        await _loadColleague(
          calendar: calendar.copyWith(email: email),
          start: rangeStart,
          end: rangeEnd,
          ownFolderId: ownFolderId,
        ),
      );
    }
    return results;
  }

  Future<ColleagueCalendar> _loadColleague({
    required ColleagueCalendar calendar,
    required DateTime start,
    required DateTime end,
    required String ownFolderId,
  }) async {
    final shared = await _sharedColleagueEvents(
      email: calendar.email,
      ownerName: calendar.displayName,
      start: start,
      end: end,
      ownFolderId: ownFolderId,
    );
    if (shared != null) {
      return calendar.copyWith(
        isLoading: false,
        available: true,
        view: 'Calendar',
        error: () => null,
        events: [
          for (final event in shared)
            event.copyWith(
              isColleague: true,
              colorIndex: calendar.colorIndex,
              mailbox: calendar.email,
              ownerName: calendar.displayName,
            ),
        ],
      );
    }

    try {
      final window = availabilityWindow(start, end);
      final json = await _call(
        'GetUserAvailabilityInternal',
        _availabilityBody(calendar.email, window.$1, window.$2),
      );
      final parsed = availabilityFromOwa(
        json,
        email: calendar.email,
        ownerName: calendar.displayName,
      );
      if (parsed.failed) {
        return calendar.copyWith(
          isLoading: false,
          available: false,
          view: 'None',
          error: () => 'Нет доступа к календарю коллеги',
          events: const [],
        );
      }
      return calendar.copyWith(
        isLoading: false,
        available: true,
        view: parsed.view,
        error: () => null,
        events: [
          for (final event in parsed.events)
            event.copyWith(
              isColleague: true,
              colorIndex: calendar.colorIndex,
              mailbox: calendar.email,
              ownerName: calendar.displayName,
            ),
        ],
      );
    } catch (_) {
      return calendar.copyWith(
        isLoading: false,
        available: false,
        view: 'None',
        error: () => 'Нет доступа к календарю коллеги',
        events: const [],
      );
    }
  }

  Future<List<CalendarEvent>?> _sharedColleagueEvents({
    required String email,
    required String ownerName,
    required DateTime start,
    required DateTime end,
    required String ownFolderId,
  }) async {
    try {
      final config = await _call('GetCalendarFolderConfiguration', {
        'request': {
          '__type': 'GetCalendarFolderConfigurationRequest:#Exchange',
          'FolderId': {
            '__type': 'DistinguishedFolderId:#Exchange',
            'Id': 'calendar',
            'Mailbox': {
              '__type': 'EmailAddress:#Exchange',
              'EmailAddress': email,
            },
          },
        },
      });
      if (config['WasSuccessful'] == false) return null;
      final folder = asMap(config['CalendarFolder']);
      final rights = asMap(folder?['EffectiveRights']);
      if (rights != null && rights['Read'] == false) return null;
      final folderId = asMap(folder?['FolderId'])?['Id'] as String?;
      if (folderId == null || folderId.isEmpty || folderId == ownFolderId) {
        return null;
      }
      final view = await _call(
        'GetCalendarView',
        _calendarViewBody(folderId, start, end),
      );
      final raw = asMap(view['Body'])?['Items'];
      if (raw is! List) return const [];
      return [
        for (final entry in raw)
          if (asMap(entry) != null)
            calendarEventFromOwaItem(
              asMap(entry)!,
              mailbox: email,
              ownerName: ownerName,
              includeResponse: false,
              idPrefix: email,
            ),
      ].where((event) => event.id.isNotEmpty).toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<Contact>> fetchContacts({
    int limit = 100,
    String search = '',
  }) async {
    final json = await _call('FindItem', {
      '__type': 'FindItemJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'FindItemRequest:#Exchange',
        'ItemShape': {
          '__type': 'ItemResponseShape:#Exchange',
          'BaseShape': 'Default',
        },
        'ParentFolderIds': [_distinguishedFolder('contacts')],
        'Traversal': 'Shallow',
        'Paging': _page(0, limit),
        'ViewFilter': 'All',
      },
    });
    final needle = search.trim().toLowerCase();
    final contacts = <Contact>[];
    for (final item in findItemResults(json)) {
      final contact = contactFromOwaItem(item);
      if (contact.id.isEmpty) continue;
      if (needle.isNotEmpty) {
        final haystack = [
          contact.displayName,
          ...contact.emails,
          ...contact.phones,
        ].join(' ').toLowerCase();
        if (!haystack.contains(needle)) continue;
      }
      contacts.add(contact);
      if (contacts.length >= limit) break;
    }
    return contacts;
  }

  Future<String> _ownCalendarFolderId() async {
    final cached = _calendarFolderId;
    if (cached != null && cached.isNotEmpty) return cached;
    final json = await _call('GetCalendarFolders', const {});
    final raw = json['CalendarFolders'];
    if (raw is! List || raw.isEmpty) {
      throw Exception('Календарь не найден');
    }
    Map<String, dynamic>? preferred;
    for (final entry in raw) {
      final folder = asMap(entry);
      if (folder == null) continue;
      final name = folder['DisplayName']?.toString();
      if (name == 'Календарь' || name == 'Calendar') {
        preferred = folder;
        break;
      }
      preferred ??= folder;
    }
    final id = asMap(preferred?['FolderId'])?['Id'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('Календарь не найден');
    }
    _calendarFolderId = id;
    return id;
  }

  Future<Map<String, dynamic>> _call(
    String action,
    Map<String, dynamic> body, {
    bool strict = true,
  }) async {
    final response = await _client.post(
      '/api/owa/service',
      query: {'action': action},
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_readError(response) ?? 'Ошибка запроса к OWA');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('OWA вернул не JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неожиданный ответ OWA');
    }
    if (strict) {
      ensureOwaSuccess(decoded);
    }
    return decoded;
  }
}

Map<String, dynamic>? asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return null;
}

String owaTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  String three(int number) => number.toString().padLeft(3, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}'
      'T${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
      '.${three(local.millisecond)}';
}

(DateTime, DateTime) availabilityWindow(DateTime start, DateTime end) {
  if (!end.isAfter(start)) {
    return (start, start.add(const Duration(days: 1)));
  }
  if (end.difference(start) <= const Duration(days: 42)) {
    return (start, end);
  }
  return (start, start.add(const Duration(days: 42)));
}

Map<String, dynamic> owaHeader([String version = 'Exchange2013']) {
  return {
    '__type': 'JsonRequestHeaders:#Exchange',
    'RequestServerVersion': version,
    'TimeZoneContext': {
      '__type': 'TimeZoneContext:#Exchange',
      'TimeZoneDefinition': {
        '__type': 'TimeZoneDefinitionType:#Exchange',
        'Id': owaTimeZoneId,
      },
    },
  };
}

void ensureOwaSuccess(Map<String, dynamic> json) {
  if (json['WasSuccessful'] == false) {
    throw Exception(json['ErrorMessage']?.toString() ?? 'OWA отклонил запрос');
  }
  final body = asMap(json['Body']);
  if (body == null) return;
  final code = body['ResponseCode'];
  if (code is String && code != 'NoError') {
    throw Exception(body['MessageText']?.toString() ?? code);
  }
  for (final message in responseMessages(json)) {
    final itemCode = message['ResponseCode'];
    if (itemCode is String && itemCode != 'NoError') {
      throw Exception(message['MessageText']?.toString() ?? itemCode);
    }
  }
}

List<Map<String, dynamic>> responseMessages(Map<String, dynamic> json) {
  final raw = asMap(asMap(json['Body'])?['ResponseMessages'])?['Items'];
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (asMap(entry) != null) asMap(entry)!,
  ];
}

List<Map<String, dynamic>> findItemResults(Map<String, dynamic> json) {
  final messages = responseMessages(json);
  if (messages.isEmpty) return const [];
  final raw = asMap(messages.first['RootFolder'])?['Items'];
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (asMap(entry) != null) asMap(entry)!,
  ];
}

Map<String, dynamic>? firstItem(Map<String, dynamic> json) {
  final messages = responseMessages(json);
  if (messages.isEmpty) return null;
  final raw = messages.first['Items'];
  if (raw is List && raw.isNotEmpty) return asMap(raw.first);
  final attachments = messages.first['Attachments'];
  if (attachments is List && attachments.isNotEmpty) {
    return asMap(attachments.first);
  }
  return null;
}

String? itemIdOf(Map<String, dynamic> item) {
  return asMap(item['ItemId'])?['Id'] as String?;
}

DateTime? parseOwaDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? locationOf(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  final name = asMap(value)?['DisplayName'] as String?;
  if (name == null || name.trim().isEmpty) return null;
  return name.trim();
}

String? _bodyValue(Map<String, dynamic> item) {
  for (final key in ['NormalizedBody', 'Body', 'UniqueBody']) {
    final body = asMap(item[key]);
    final value = body?['Value'];
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return null;
}

String _bodyType(Map<String, dynamic> item) {
  for (final key in ['NormalizedBody', 'Body', 'UniqueBody']) {
    final type = asMap(item[key])?['BodyType'];
    if (type is String && type.isNotEmpty) return type.toLowerCase();
  }
  return 'text';
}

List<CalendarAttendee> attendeesFromOwaItem(Map<String, dynamic> item) {
  return [
    ..._attendeesOf(item['RequiredAttendees'], optional: false),
    ..._attendeesOf(item['OptionalAttendees'], optional: true),
  ];
}

List<CalendarAttendee> _attendeesOf(dynamic raw, {required bool optional}) {
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (asMap(entry) != null)
        CalendarAttendee(
          name: personNameOf(asMap(entry)!['Mailbox']) ??
              personEmailOf(asMap(entry)!['Mailbox']) ??
              '',
          email: personEmailOf(asMap(entry)!['Mailbox']),
          responseType: asMap(entry)!['ResponseType'] as String?,
          optional: optional,
        ),
  ].where((attendee) => attendee.name.isNotEmpty).toList();
}

String? personEmailOf(dynamic value) {
  final map = asMap(value);
  final mailbox = asMap(map?['Mailbox']) ?? map;
  final email = mailbox?['EmailAddress'] as String?;
  if (email == null || email.trim().isEmpty) return null;
  return email.trim();
}

String? personNameOf(dynamic value) {
  final map = asMap(value);
  final mailbox = asMap(map?['Mailbox']) ?? map;
  if (mailbox == null) return null;
  final name = mailbox['Name'] as String?;
  if (name != null && name.trim().isNotEmpty) return name.trim();
  final email = mailbox['EmailAddress'] as String?;
  if (email == null || email.trim().isEmpty) return null;
  return email.trim();
}

MailMessage mailMessageFromOwaItem(
  Map<String, dynamic> item, {
  String? folderId,
  String? body,
  String bodyType = 'text',
  List<MailAttachment> attachments = const [],
  bool detailLoaded = false,
}) {
  final parentId = asMap(item['ParentFolderId'])?['Id'] as String?;
  return MailMessage(
    id: itemIdOf(item) ?? '',
    folderId: (folderId != null && folderId.isNotEmpty)
        ? folderId
        : parentId ?? '',
    subject: item['Subject'] as String? ?? '(без темы)',
    sender: personNameOf(item['From']) ?? personNameOf(item['Sender']),
    datetimeReceived: parseOwaDate(item['DateTimeReceived']),
    isRead: item['IsRead'] == true,
    preview: item['Preview'] as String? ?? '',
    hasAttachments: item['HasAttachments'] == true || attachments.isNotEmpty,
    isFlagged: asMap(item['Flag'])?['FlagStatus'] == 'Flagged',
    conversationId: asMap(item['ConversationId'])?['Id'] as String?,
    body: body,
    bodyType: bodyType,
    attachments: attachments,
    detailLoaded: detailLoaded,
  );
}

MailMessage mailMessageFromConversation(
  Map<String, dynamic> conversation, {
  String? folderId,
}) {
  final itemIds = conversation['ItemIds'] ?? conversation['GlobalItemIds'];
  String id = '';
  if (itemIds is List && itemIds.isNotEmpty) {
    id = asMap(itemIds.first)?['Id'] as String? ?? '';
  }
  final unread =
      (conversation['UnreadCount'] as num?)?.toInt() ??
      (conversation['GlobalUnreadCount'] as num?)?.toInt() ??
      0;
  final messageCount =
      (conversation['GlobalMessageCount'] as num?)?.toInt() ??
      (conversation['MessageCount'] as num?)?.toInt() ??
      1;
  return MailMessage(
    id: id,
    folderId: folderId ?? '',
    subject: conversation['ConversationTopic'] as String? ?? '(без темы)',
    sender:
        _nameList(conversation['UniqueSenders']) ??
        _nameList(conversation['UniqueRecipients']),
    datetimeReceived: parseOwaDate(
      conversation['LastDeliveryTime'] ??
          conversation['LastDeliveryOrRenewTime'],
    ),
    isRead: unread == 0,
    preview: conversation['Preview'] as String? ?? '',
    hasAttachments: conversation['HasAttachments'] == true,
    conversationId: asMap(conversation['ConversationId'])?['Id'] as String?,
    messageCount: messageCount < 1 ? 1 : messageCount,
    isFlagged: conversation['FlagStatus'] == 'Flagged',
  );
}

List<MailMessage> messagesFromConversationItems(Map<String, dynamic> json) {
  final messages = responseMessages(json);
  if (messages.isEmpty) return const [];
  final nodes = asMap(messages.first['Conversation'])?['ConversationNodes'];
  if (nodes is! List) return const [];
  final items = <MailMessage>[];
  for (final node in nodes) {
    final raw = asMap(node)?['Items'];
    if (raw is! List) continue;
    for (final entry in raw) {
      final item = asMap(entry);
      if (item == null) continue;
      final message = mailMessageFromOwaItem(item);
      if (message.id.isEmpty) continue;
      items.add(message);
    }
  }
  return items;
}

List<MailMessage> messagesFromSearchResults(
  Map<String, dynamic> json, {
  String? folderId,
}) {
  final body = asMap(json['Body']);
  final results = asMap(body?['SearchResults']) ?? body;
  final conversations = results?['Conversations'];
  if (conversations is List) {
    return [
      for (final entry in conversations)
        if (asMap(entry) != null)
          mailMessageFromConversation(asMap(entry)!, folderId: folderId),
    ].where((message) => message.id.isNotEmpty).toList();
  }
  final items = results?['Items'];
  if (items is List) {
    return [
      for (final entry in items)
        if (asMap(entry) != null)
          if (asMap(entry)!['ConversationTopic'] != null)
            mailMessageFromConversation(asMap(entry)!, folderId: folderId)
          else
            mailMessageFromOwaItem(asMap(entry)!, folderId: folderId),
    ].where((message) => message.id.isNotEmpty).toList();
  }
  return const [];
}

String? _nameList(dynamic raw) {
  if (raw is! List) return null;
  final names = [
    for (final entry in raw)
      if (entry is String && entry.trim().isNotEmpty) entry.trim(),
  ];
  if (names.isEmpty) return null;
  return names.join(', ');
}

List<MailAttachment> attachmentsFromOwaItem(Map<String, dynamic> item) {
  final raw = item['Attachments'];
  if (raw is! List) return const [];
  final attachments = <MailAttachment>[];
  for (final entry in raw) {
    final map = asMap(entry);
    if (map == null) continue;
    final id =
        asMap(map['AttachmentId'])?['Id'] as String? ?? map['Id'] as String?;
    if (id == null || id.isEmpty) continue;
    attachments.add(
      MailAttachment(
        id: id,
        name: map['Name'] as String? ?? 'attachment',
        size: (map['Size'] as num?)?.toInt() ?? 0,
        contentType:
            map['ContentType'] as String? ?? 'application/octet-stream',
      ),
    );
  }
  return attachments;
}

CalendarEvent calendarEventFromOwaItem(
  Map<String, dynamic> item, {
  String? mailbox,
  String? ownerName,
  bool includeResponse = true,
  bool isLimited = false,
  String? idPrefix,
}) {
  final sensitivity = (item['Sensitivity'] as String? ?? '').toLowerCase();
  final isPrivate = sensitivity == 'private';
  var subject = (item['Subject'] as String? ?? '').trim();
  if (isPrivate && subject.isEmpty) subject = 'Частное';
  if (subject.isEmpty) subject = '(без темы)';
  final busy = item['FreeBusyType'] ?? item['LegacyFreeBusyStatus'];
  final id = itemIdOf(item) ?? '';
  final response = includeResponse ? _responseType(item) : null;
  return CalendarEvent(
    id: idPrefix != null && id.isNotEmpty ? '$idPrefix:$id' : id,
    subject: subject,
    start: parseOwaDate(item['Start']),
    end: parseOwaDate(item['End']),
    location: locationOf(item['Location']),
    organizer: personNameOf(item['Organizer']),
    myResponseType: response,
    isMeeting: item['IsMeeting'] == true,
    isResponseRequested: includeResponse
        ? item['IsResponseRequested'] as bool?
        : null,
    needsResponse: includeResponse && _needsResponse(item),
    mailbox: mailbox,
    ownerName: ownerName,
    busyStatus: busy?.toString(),
    isPrivate: isPrivate,
    isLimited: isLimited,
    body: _bodyValue(item),
    bodyType: _bodyType(item),
    attendees: attendeesFromOwaItem(item),
    detailLoaded: _bodyValue(item) != null || attendeesFromOwaItem(item).isNotEmpty,
  );
}

AvailabilityParse availabilityFromOwa(
  Map<String, dynamic> json, {
  required String email,
  required String ownerName,
}) {
  final responses = asMap(json['Body'])?['Responses'];
  if (responses is! List || responses.isEmpty) {
    return const AvailabilityParse(view: 'None', events: [], failed: true);
  }
  final first = asMap(responses.first);
  if (first == null) {
    return const AvailabilityParse(view: 'None', events: [], failed: true);
  }
  final code = first['ResponseCode']?.toString();
  if (code != null && code != 'NoError') {
    return const AvailabilityParse(view: 'None', events: [], failed: true);
  }
  final view = asMap(first['CalendarView']);
  final viewType = view?['FreeBusyViewType']?.toString() ?? 'None';
  if (viewType == 'None' || viewType.isEmpty) {
    return const AvailabilityParse(view: 'None', events: [], failed: true);
  }
  final raw = view?['CalendarEvents'] ?? view?['Items'];
  if (raw is! List) {
    return AvailabilityParse(view: viewType, events: const [], failed: false);
  }
  final events = <CalendarEvent>[];
  for (final entry in raw) {
    final slot = asMap(entry);
    if (slot == null) continue;
    final event = _eventFromAvailabilitySlot(
      slot,
      email: email,
      ownerName: ownerName,
    );
    if (event != null) events.add(event);
  }
  return AvailabilityParse(view: viewType, events: events, failed: false);
}

class AvailabilityParse {
  const AvailabilityParse({
    required this.view,
    required this.events,
    required this.failed,
  });

  final String view;
  final List<CalendarEvent> events;
  final bool failed;
}

Contact contactFromOwaItem(Map<String, dynamic> item) {
  return Contact(
    id: itemIdOf(item) ?? asMap(item['PersonaId'])?['Id'] as String? ?? '',
    displayName: item['DisplayName'] as String? ?? 'Без имени',
    emails: _stringList(item['EmailAddresses'] ?? item['EmailAddress']),
    phones: _stringList(item['PhoneNumbers'] ?? item['PhoneNumber']),
  );
}

List<MailFolderNode> _buildMailFolderTree(
  List<_OwaFolder> folders,
  String rootId,
) {
  final byParent = <String, List<_OwaFolder>>{};
  for (final folder in folders) {
    if (folder.id.isEmpty || folder.id == rootId) continue;
    byParent.putIfAbsent(folder.parentId, () => []).add(folder);
  }

  List<MailFolderNode> walk(String parentId, int depth) {
    if (depth > 3) return const [];
    final children = byParent[parentId] ?? const <_OwaFolder>[];
    return [
      for (final child in children)
        MailFolderNode(
          id: child.id,
          name: child.name,
          totalCount: child.totalCount,
          unreadCount: child.unreadCount,
          children: walk(child.id, depth + 1),
        ),
    ];
  }

  return walk(rootId, 1);
}

class _OwaFolder {
  const _OwaFolder({
    required this.id,
    required this.parentId,
    required this.name,
    required this.totalCount,
    required this.unreadCount,
  });

  final String id;
  final String parentId;
  final String name;
  final int totalCount;
  final int unreadCount;
}

class _FindFolderPage {
  const _FindFolderPage({
    required this.folders,
    required this.includesLast,
    required this.nextOffset,
  });

  final List<_OwaFolder> folders;
  final bool includesLast;
  final int nextOffset;
}

_OwaFolder? _folderFromMap(Map<String, dynamic> folder) {
  final id = asMap(folder['FolderId'])?['Id'] as String?;
  if (id == null || id.isEmpty) return null;
  return _OwaFolder(
    id: id,
    parentId: asMap(folder['ParentFolderId'])?['Id'] as String? ?? '',
    name: folder['DisplayName'] as String? ?? 'Без имени',
    totalCount: (folder['TotalCount'] as num?)?.toInt() ?? 0,
    unreadCount: (folder['UnreadCount'] as num?)?.toInt() ?? 0,
  );
}

List<_OwaFolder> _foldersFromGetFolder(Map<String, dynamic> json) {
  final folders = <_OwaFolder>[];
  for (final message in responseMessages(json)) {
    final raw = message['Folders'];
    if (raw is! List) continue;
    for (final entry in raw) {
      final folder = asMap(entry);
      if (folder == null) continue;
      final parsed = _folderFromMap(folder);
      if (parsed != null) folders.add(parsed);
    }
  }
  return folders;
}

_FindFolderPage _foldersFromFindFolder(Map<String, dynamic> json) {
  final messages = responseMessages(json);
  if (messages.isEmpty) {
    return const _FindFolderPage(
      folders: [],
      includesLast: true,
      nextOffset: 0,
    );
  }
  final root = asMap(messages.first['RootFolder']);
  final raw = root?['Folders'];
  final folders = <_OwaFolder>[];
  if (raw is List) {
    for (final entry in raw) {
      final folder = asMap(entry);
      if (folder == null) continue;
      final parsed = _folderFromMap(folder);
      if (parsed != null) folders.add(parsed);
    }
  }
  final includesLast = root?['IncludesLastItemInRange'] != false;
  final nextOffset =
      (root?['IndexedPagingOffset'] as num?)?.toInt() ?? folders.length;
  return _FindFolderPage(
    folders: folders,
    includesLast: includesLast,
    nextOffset: nextOffset,
  );
}

Map<String, dynamic> _distinguishedFolder(String id) => {
  '__type': 'DistinguishedFolderId:#Exchange',
  'Id': id,
};

Map<String, dynamic> _folderId(String id) => {
  '__type': 'FolderId:#Exchange',
  'Id': id,
};

Map<String, dynamic> _page(int offset, int limit) => {
  '__type': 'IndexedPageView:#Exchange',
  'BasePoint': 'Beginning',
  'Offset': offset,
  'MaxEntriesReturned': limit,
};

Map<String, dynamic> _sortOrder(String field, String order) => {
  '__type': 'SortResults:#Exchange',
  'Order': order,
  'Path': {'__type': 'PropertyUri:#Exchange', 'FieldURI': field},
};

Map<String, dynamic> _emailAddress(String address) => {
  '__type': 'EmailAddress:#Exchange',
  'EmailAddress': address,
};

(String, String) _mailSort(MailInboxSort sort) {
  return switch (sort) {
    MailInboxSort.dateAsc => ('DateTimeReceived', 'Ascending'),
    MailInboxSort.dateDesc => ('DateTimeReceived', 'Descending'),
    MailInboxSort.fromAddress => ('From', 'Ascending'),
    MailInboxSort.toAddress => ('DisplayTo', 'Ascending'),
    MailInboxSort.subject => ('Subject', 'Ascending'),
    MailInboxSort.attachments => ('HasAttachments', 'Descending'),
    MailInboxSort.importance => ('Importance', 'Descending'),
  };
}

String _mailViewFilter(MailInboxFilter filter) {
  return switch (filter) {
    MailInboxFilter.all => 'All',
    MailInboxFilter.toMe => 'ToOrCcMe',
    MailInboxFilter.flagged => 'Flagged',
    MailInboxFilter.mentions => 'All',
  };
}

Map<String, dynamic> _mailFolderShape() {
  // Default shape omits ParentFolderId, so the tree cannot be attached to
  // the mailbox root and the folder list stays empty.
  return {
    '__type': 'FolderResponseShape:#Exchange',
    'BaseShape': 'Default',
    'AdditionalProperties': [
      {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'ParentFolderId'},
    ],
  };
}

Map<String, dynamic> _getFolderBody(List<Map<String, dynamic>> ids) {
  return {
    '__type': 'GetFolderJsonRequest:#Exchange',
    'Header': owaHeader(),
    'Body': {
      '__type': 'GetFolderRequest:#Exchange',
      'FolderShape': _mailFolderShape(),
      'FolderIds': ids,
    },
  };
}

Map<String, dynamic> _findFolderBody({required int offset}) {
  return {
    '__type': 'FindFolderJsonRequest:#Exchange',
    'Header': owaHeader(),
    'Body': {
      '__type': 'FindFolderRequest:#Exchange',
      'FolderShape': _mailFolderShape(),
      'ParentFolderIds': [_distinguishedFolder('msgfolderroot')],
      'Traversal': 'Deep',
      'Paging': _page(offset, 200),
    },
  };
}

Map<String, dynamic> _getMailItemBody(String messageId) {
  return {
    '__type': 'GetItemJsonRequest:#Exchange',
    'Header': owaHeader('V2017_08_18'),
    'Body': {
      '__type': 'GetItemRequest:#Exchange',
      'ItemShape': {
        '__type': 'ItemResponseShape:#Exchange',
        'BaseShape': 'IdOnly',
        'FilterHtmlContent': true,
        'AddBlankTargetToLinks': true,
        'MaximumBodySize': 2097152,
      },
      'ItemIds': [
        {'__type': 'ItemId:#Exchange', 'Id': messageId},
      ],
      'ShapeName': 'ItemNormalizedBody',
    },
  };
}

Map<String, dynamic> _markReadBody(String messageId, {bool isRead = true}) {
  return {
    '__type': 'UpdateItemJsonRequest:#Exchange',
    'Header': owaHeader(),
    'Body': {
      '__type': 'UpdateItemRequest:#Exchange',
      'ConflictResolution': 'AlwaysOverwrite',
      'MessageDisposition': 'SaveOnly',
      'ItemChanges': [
        {
          '__type': 'ItemChange:#Exchange',
          'ItemId': {'__type': 'ItemId:#Exchange', 'Id': messageId},
          'Updates': [
            {
              '__type': 'SetItemField:#Exchange',
              'Path': {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'IsRead'},
              'Item': {'__type': 'Message:#Exchange', 'IsRead': isRead},
            },
          ],
        },
      ],
    },
  };
}

Map<String, dynamic> _mailFolderRef(String? folderId) {
  if (folderId == null || folderId.isEmpty)
    return _distinguishedFolder('inbox');
  return _folderId(folderId);
}

Map<String, dynamic> _conversationItemsBody(String conversationId) {
  return {
    '__type': 'GetConversationItemsJsonRequest:#Exchange',
    'Header': owaHeader('V2017_08_18'),
    'Body': {
      '__type': 'GetConversationItemsRequest:#Exchange',
      'Conversations': [
        {
          '__type': 'ConversationRequestType:#Exchange',
          'ConversationId': {
            '__type': 'ItemId:#Exchange',
            'Id': conversationId,
          },
          'SyncState': '',
        },
      ],
      'ItemShape': {
        '__type': 'ItemResponseShape:#Exchange',
        'BaseShape': 'IdOnly',
        'FilterHtmlContent': true,
        'AddBlankTargetToLinks': true,
        'MaximumBodySize': 2097152,
        'CalculateOnlyFirstBody': true,
      },
      'ShapeName': 'ItemPart',
      'SortOrder': 'DateOrderDescending',
      'MaxItemsToReturn': 20,
    },
  };
}

Map<String, dynamic> _conversationActionBody({
  required String conversationId,
  required String? folderId,
  required String action,
  bool? isRead,
  String? flagStatus,
  String? deleteType,
}) {
  return {
    '__type': 'ApplyConversationActionJsonRequest:#Exchange',
    'Header': owaHeader(),
    'Body': {
      '__type': 'ApplyConversationActionRequest:#Exchange',
      'ConversationActions': [
        {
          '__type': 'ConversationAction:#Exchange',
          'Action': action,
          'ConversationId': {
            '__type': 'ItemId:#Exchange',
            'Id': conversationId,
          },
          'ContextFolderId': {
            '__type': 'TargetFolderId:#Exchange',
            'BaseFolderId': _mailFolderRef(folderId),
          },
          'IsRead': ?isRead,
          'Flag': ?(flagStatus == null
              ? null
              : {'__type': 'FlagType:#Exchange', 'FlagStatus': flagStatus}),
          'DeleteType': ?deleteType,
        },
      ],
    },
  };
}

Map<String, dynamic> _pinBody(String itemId, {required bool pinned}) {
  const property = {
    '__type': 'ExtendedPropertyUri:#Exchange',
    'DistinguishedPropertySetId': 'Common',
    'PropertyName': 'IsPinned',
    'PropertyType': 'Boolean',
  };
  return {
    '__type': 'UpdateItemJsonRequest:#Exchange',
    'Header': owaHeader(),
    'Body': {
      '__type': 'UpdateItemRequest:#Exchange',
      'ConflictResolution': 'AlwaysOverwrite',
      'MessageDisposition': 'SaveOnly',
      'ItemChanges': [
        {
          '__type': 'ItemChange:#Exchange',
          'ItemId': {'__type': 'ItemId:#Exchange', 'Id': itemId},
          'Updates': [
            {
              '__type': 'SetItemField:#Exchange',
              'Path': property,
              'Item': {
                '__type': 'Message:#Exchange',
                'ExtendedProperty': [
                  {
                    '__type': 'ExtendedPropertyType:#Exchange',
                    'ExtendedFieldURI': property,
                    'Value': pinned ? 'true' : 'false',
                  },
                ],
              },
            },
          ],
        },
      ],
    },
  };
}

Map<String, dynamic> _flagItemBody(String itemId, {required bool flagged}) {
  return {
    '__type': 'UpdateItemJsonRequest:#Exchange',
    'Header': owaHeader(),
    'Body': {
      '__type': 'UpdateItemRequest:#Exchange',
      'ConflictResolution': 'AlwaysOverwrite',
      'MessageDisposition': 'SaveOnly',
      'ItemChanges': [
        {
          '__type': 'ItemChange:#Exchange',
          'ItemId': {'__type': 'ItemId:#Exchange', 'Id': itemId},
          'Updates': [
            {
              '__type': 'SetItemField:#Exchange',
              'Path': {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'Flag'},
              'Item': {
                '__type': 'Message:#Exchange',
                'Flag': {
                  '__type': 'FlagType:#Exchange',
                  'FlagStatus': flagged ? 'Flagged' : 'NotFlagged',
                },
              },
            },
          ],
        },
      ],
    },
  };
}

Map<String, dynamic> _calendarItemBody(String eventId) {
  return {
    '__type': 'GetItemJsonRequest:#Exchange',
    'Header': owaHeader(),
    'Body': {
      '__type': 'GetItemRequest:#Exchange',
      'ItemShape': {
        '__type': 'ItemResponseShape:#Exchange',
        'BaseShape': 'IdOnly',
        'BodyType': 'HTML',
        'FilterHtmlContent': true,
        'AddBlankTargetToLinks': true,
        'MaximumBodySize': 2097152,
        'AdditionalProperties': [
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'item:Body'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'item:Subject'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:Start'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:End'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:Location'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:Organizer'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:RequiredAttendees'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:OptionalAttendees'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:IsMeeting'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:MyResponseType'},
          {'__type': 'PropertyUri:#Exchange', 'FieldURI': 'calendar:IsOrganizer'},
        ],
      },
      'ItemIds': [
        {'__type': 'ItemId:#Exchange', 'Id': eventId},
      ],
    },
  };
}

Map<String, dynamic> _calendarViewBody(
  String folderId,
  DateTime start,
  DateTime end,
) {
  return {
    '__type': 'GetCalendarViewJsonRequest:#Exchange',
    'Header': owaHeader('V2017_08_18'),
    'Body': {
      '__type': 'GetCalendarViewRequest:#Exchange',
      'CalendarId': {
        '__type': 'TargetFolderId:#Exchange',
        'BaseFolderId': _folderId(folderId),
      },
      'RangeStart': owaTimestamp(start),
      'RangeEnd': owaTimestamp(end),
    },
  };
}

Map<String, dynamic> _availabilityBody(
  String email,
  DateTime start,
  DateTime end,
) {
  return {
    'request': {
      '__type': 'GetUserAvailabilityInternalJsonRequest:#Exchange',
      'Header': owaHeader(),
      'Body': {
        '__type': 'GetUserAvailabilityRequest:#Exchange',
        'MailboxDataArray': [
          {
            '__type': 'MailboxData:#Exchange',
            'Email': {'__type': 'EmailAddress:#Exchange', 'Address': email},
            'AttendeeType': 'Required',
          },
        ],
        'FreeBusyViewOptions': {
          '__type': 'FreeBusyViewOptions:#Exchange',
          'RequestedView': 'Detailed',
          'TimeWindow': {
            '__type': 'Duration:#Exchange',
            'StartTime': owaTimestamp(start),
            'EndTime': owaTimestamp(end),
          },
        },
      },
    },
  };
}

String? _attachmentContent(Map<String, dynamic> json) {
  final item = firstItem(json);
  final content = item?['Content'];
  if (content is String && content.isNotEmpty) return content;
  return null;
}

String? _responseType(Map<String, dynamic> item) {
  if (item['IsOrganizer'] == true) return 'Organizer';
  final value = item['ResponseType'] ?? item['MyResponseType'];
  if (value == null || value == 'None') return null;
  return value.toString();
}

bool _needsResponse(Map<String, dynamic> item) {
  if (item['IsMeeting'] != true || item['IsOrganizer'] == true) return false;
  final response = item['ResponseType'] ?? item['MyResponseType'];
  return response == 'NoResponseReceived' || response == 'Unknown';
}

bool _isMention(MailMessage message, String email) {
  final normalized = email.toLowerCase();
  final local = normalized.split('@').first;
  final haystack = '${message.subject} ${message.preview}'.toLowerCase();
  return haystack.contains('@$local') || haystack.contains('@$normalized');
}

const _busyLabels = {
  'Busy': 'Занято',
  'Tentative': 'Под вопросом',
  'OOF': 'Нет на месте',
  'Oof': 'Нет на месте',
  'WorkingElsewhere': 'Работает вне офиса',
};

CalendarEvent? _eventFromAvailabilitySlot(
  Map<String, dynamic> slot, {
  required String email,
  required String ownerName,
}) {
  final busy = (slot['BusyType'] ?? slot['LegacyFreeBusyStatus'] ?? 'Busy')
      .toString();
  if (busy == 'Free' || busy == 'NoData') return null;
  final details = asMap(slot['CalendarEventDetails']);
  final isPrivate = details?['IsPrivate'] == true;
  var subject = (details?['Subject'] as String?)?.trim();
  if (isPrivate && (subject == null || subject.isEmpty)) subject = 'Частное';
  if (subject == null || subject.isEmpty) {
    subject = _busyLabels[busy] ?? 'Занято';
  }
  final start = parseOwaDate(slot['StartTime'] ?? slot['Start']);
  final end = parseOwaDate(slot['EndTime'] ?? slot['End']);
  if (start == null) return null;
  final detailId = details?['ID'] ?? details?['Id'];
  final id = detailId == null
      ? 'avail:$email:${start.toIso8601String()}:${end?.toIso8601String() ?? ''}'
      : '$email:$detailId';
  final limited =
      details == null || ((details['Subject'] as String?) ?? '').trim().isEmpty;
  return CalendarEvent(
    id: id,
    subject: subject,
    start: start,
    end: end,
    location: locationOf(details?['Location']),
    organizer: email,
    isMeeting: details?['IsMeeting'] == true,
    mailbox: email,
    ownerName: ownerName,
    busyStatus: busy,
    isPrivate: isPrivate,
    isLimited: limited,
    isColleague: true,
  );
}

List<String> _stringList(dynamic raw) {
  if (raw is String && raw.isNotEmpty) return [raw];
  if (raw is! List) {
    final single = asMap(raw);
    final value = _contactValue(single);
    return value == null ? const [] : [value];
  }
  final values = <String>[];
  for (final entry in raw) {
    if (entry is String && entry.isNotEmpty) {
      values.add(entry);
      continue;
    }
    final value = _contactValue(asMap(entry));
    if (value != null) values.add(value);
  }
  return values;
}

String? _contactValue(Map<String, dynamic>? map) {
  if (map == null) return null;
  for (final key in [
    'EmailAddress',
    'Address',
    'Number',
    'PhoneNumber',
    'Name',
  ]) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
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
