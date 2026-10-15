import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/blocs/mail/mail_bloc.dart';
import 'package:ddt_frontend/models/mail_inbox_options.dart';
import 'package:ddt_frontend/models/mail_message.dart';
import 'package:ddt_frontend/services/ews_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('background refresh keeps the open message when its id rotates', () async {
    final api = _FakeEwsApi(
      messages: [
        _message(id: 'old-id', folderId: '', conversationId: 'conv-1'),
      ],
    );
    final bloc = MailBloc(api: api);
    addTearDown(bloc.close);

    final loaded = bloc.stream.firstWhere(
      (state) => state.messages.isNotEmpty,
    );
    bloc.add(const MailInboxLoadRequested());
    await loaded;

    final opened = bloc.stream.firstWhere(
      (state) => state.selectedMessage?.body == 'Текст письма',
    );
    bloc.add(MailMessageSelected(bloc.state.messages.single));
    await opened;

    api.messages = [
      _message(id: 'new-id', folderId: 'inbox-id', conversationId: 'conv-1'),
    ];
    final refreshedFuture = bloc.stream.firstWhere(
      (state) => state.messages.any((message) => message.id == 'new-id'),
    );
    bloc.add(const MailInboxRefreshRequested());
    final refreshed = await refreshedFuture;

    expect(refreshed.selectedMessage, isNotNull);
    expect(refreshed.selectedMessage!.id, 'new-id');
    expect(refreshed.selectedMessage!.body, 'Текст письма');
    expect(refreshed.selectedFolderId, 'inbox-id');
  });

  test('switching folders closes the open message', () async {
    final api = _FakeEwsApi(
      messages: [
        _message(id: 'inbox-mail', folderId: '', conversationId: 'conv-1'),
      ],
    );
    final bloc = MailBloc(api: api);
    addTearDown(bloc.close);

    final loaded = bloc.stream.firstWhere(
      (state) => state.messages.isNotEmpty,
    );
    bloc.add(const MailInboxLoadRequested());
    await loaded;
    final opened = bloc.stream.firstWhere(
      (state) => state.selectedMessage != null,
    );
    bloc.add(MailMessageSelected(bloc.state.messages.single));
    await opened;

    api.messages = [
      _message(id: 'sent-mail', folderId: 'sent-id', conversationId: 'conv-2'),
    ];
    final switched = bloc.stream.firstWhere(
      (state) => state.messages.any((message) => message.id == 'sent-mail'),
    );
    bloc.add(const MailInboxQueryChanged(folderId: 'sent-id'));
    final next = await switched;

    expect(next.selectedMessage, isNull);
    expect(next.messages.single.id, 'sent-mail');
  });
}

MailMessage _message({
  required String id,
  required String folderId,
  required String conversationId,
}) {
  return MailMessage(
    id: id,
    folderId: folderId,
    conversationId: conversationId,
    subject: 'Тема',
    sender: 'Автор',
    datetimeReceived: DateTime.utc(2026, 10, 15),
    isRead: false,
    preview: 'Превью',
  );
}

class _FakeEwsApi extends EwsApi {
  _FakeEwsApi({required this.messages});

  List<MailMessage> messages;

  @override
  Future<MailFolders> fetchMailFolders() async {
    return const MailFolders(
      inbox: 1,
      sent: 1,
      inboxFolderId: 'inbox-id',
      sentFolderId: 'sent-id',
      folders: [],
    );
  }

  @override
  Future<List<MailMessage>> fetchInbox({
    int limit = 50,
    int offset = 0,
    MailInboxFilter filter = MailInboxFilter.all,
    MailInboxSort sort = MailInboxSort.dateDesc,
    String? folderId,
    String? search,
  }) async {
    return messages;
  }

  @override
  Future<MailMessage> fetchMessage(
    String messageId, {
    bool markRead = true,
    String? folderId,
  }) async {
    final current = messages.firstWhere((message) => message.id == messageId);
    return current.copyWith(
      body: 'Текст письма',
      bodyType: 'text',
      isRead: true,
      detailLoaded: true,
    );
  }

  @override
  Future<void> markMessageRead(String messageId, {String? folderId}) async {}
}
