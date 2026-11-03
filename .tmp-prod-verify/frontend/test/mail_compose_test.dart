import 'package:ddt_frontend/models/mail_message.dart';
import 'package:ddt_frontend/services/owa_client.dart';
import 'package:ddt_frontend/utils/mail_compose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reply draft addresses the sender and quotes a short excerpt', () {
    final draft = MailComposeDraft.replyTo(
      const MailMessage(
        id: 'msg-1',
        folderId: 'inbox',
        subject: 'Счёт',
        sender: 'Иван Петров',
        senderEmail: 'Ivan@Example.com',
        datetimeReceived: null,
        isRead: true,
        preview: 'Проверьте вложение до пятницы, пожалуйста.',
      ),
    );

    expect(draft.subject, 'Re: Счёт');
    expect(draft.to, hasLength(1));
    expect(draft.to.single.email, 'ivan@example.com');
    expect(draft.to.single.displayName, 'Иван Петров');
    expect(draft.body, contains('Иван Петров:'));
    expect(draft.body, contains('> Проверьте вложение до пятницы'));
    expect(draft.recipientHint, isNull);
  });

  test('reply keeps an existing Re subject and falls back to a name hint', () {
    final draft = MailComposeDraft.replyTo(
      const MailMessage(
        id: 'msg-2',
        folderId: 'inbox',
        subject: 'Re: Счёт',
        sender: 'Анна',
        datetimeReceived: null,
        isRead: false,
        preview: '',
      ),
    );

    expect(draft.subject, 'Re: Счёт');
    expect(draft.to, isEmpty);
    expect(draft.recipientHint, 'Анна');
    expect(draft.body, isEmpty);
  });

  test('create attachment response keeps the parent change key', () {
    final identity = createdMailIdentity({
      'Body': {
        'ResponseMessages': {
          'Items': [
            {
              'ResponseCode': 'NoError',
              'Attachments': [
                {
                  'AttachmentId': {
                    'RootItemId': 'draft-1',
                    'RootItemChangeKey': 'ck-2',
                    'Id': 'att-1',
                  },
                },
              ],
            },
          ],
        },
      },
    });

    expect(identity.id, 'draft-1');
    expect(identity.changeKey, 'ck-2');
  });
}
