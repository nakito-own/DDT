import 'package:flutter_test/flutter_test.dart';
import 'package:ddt_frontend/models/calendar_meeting_link.dart';
import 'package:ddt_frontend/services/owa_client.dart';

void main() {
  test('calendar item keeps response and location from OWA', () {
    final event = calendarEventFromOwaItem({
      'ItemId': {'Id': 'evt-1'},
      'Subject': 'Статус',
      'Start': '2026-10-07T10:00:00+03:00',
      'End': '2026-10-07T11:00:00+03:00',
      'Location': {'DisplayName': 'Телемост'},
      'Organizer': {
        'Mailbox': {'Name': 'Анна', 'EmailAddress': 'anna@example.com'},
      },
      'IsMeeting': true,
      'IsOrganizer': false,
      'IsResponseRequested': true,
      'ResponseType': 'Accept',
      'Sensitivity': 'Normal',
      'FreeBusyType': 'Busy',
    });

    expect(event.id, 'evt-1');
    expect(event.subject, 'Статус');
    expect(event.location, 'Телемост');
    expect(event.organizer, 'Анна');
    expect(event.myResponseType, 'Accept');
    expect(event.needsResponse, isFalse);
    expect(event.start?.toUtc(), DateTime.parse('2026-10-07T07:00:00Z'));
  });

  test('calendar detail keeps html body and attendees', () {
    final event = calendarEventFromOwaItem({
      'ItemId': {'Id': 'evt-3'},
      'Subject': 'Созвон',
      'Body': {
        'BodyType': 'HTML',
        'Value': '<p>https://telemost.yandex.ru/j/1</p>',
      },
      'RequiredAttendees': [
        {
          'Mailbox': {'Name': 'Иван', 'EmailAddress': 'ivan@example.com'},
          'ResponseType': 'Accept',
        },
      ],
      'OptionalAttendees': [
        {
          'Mailbox': {'Name': 'Мария', 'EmailAddress': 'maria@example.com'},
          'ResponseType': 'NoResponseReceived',
        },
      ],
    });

    expect(event.bodyType, 'html');
    expect(event.attendees, hasLength(2));
    expect(event.attendees.first.responseLabel, 'Принято');
    expect(event.attendees.last.optional, isTrue);
    final link = meetingLinkFor(location: event.location, html: event.body);
    expect(link?.service, CalendarMeetingService.telemost);
  });

  test('meeting link prefers a known service over a plain location url', () {
    final link = meetingLinkFor(
      location: 'https://peregovorka.mos.ru/room/1',
      html: '<a href="https://itpm.mos.ru/page">wiki</a>',
    );
    expect(link?.service, CalendarMeetingService.peregovorka);
    expect(locationWithoutLinks('Кабинет 4 https://zoom.us/j/1'), 'Кабинет 4');
  });

  test('organizer response does not ask for a reply', () {
    final event = calendarEventFromOwaItem({
      'ItemId': {'Id': 'evt-2'},
      'Subject': 'Планёрка',
      'IsMeeting': true,
      'IsOrganizer': true,
      'ResponseType': 'NoResponseReceived',
    });

    expect(event.myResponseType, 'Organizer');
    expect(event.needsResponse, isFalse);
  });

  test('availability slots without a subject stay limited', () {
    final parsed = availabilityFromOwa(
      {
        'Body': {
          'Responses': [
            {
              'ResponseCode': 'NoError',
              'CalendarView': {
                'FreeBusyViewType': 'Detailed',
                'CalendarEvents': [
                  {
                    'StartTime': '2026-10-07T10:00:00+03:00',
                    'EndTime': '2026-10-07T11:00:00+03:00',
                    'BusyType': 'Busy',
                  },
                  {
                    'StartTime': '2026-10-07T12:00:00+03:00',
                    'EndTime': '2026-10-07T13:00:00+03:00',
                    'BusyType': 'Free',
                    'CalendarEventDetails': {
                      'ID': 'hidden',
                      'Subject': 'Свободно',
                    },
                  },
                ],
              },
            },
          ],
        },
      },
      email: 'colleague@example.com',
      ownerName: 'Коллега',
    );

    expect(parsed.failed, isFalse);
    expect(parsed.view, 'Detailed');
    expect(parsed.events, hasLength(1));
    expect(parsed.events.single.subject, 'Занято');
    expect(parsed.events.single.isLimited, isTrue);
    expect(parsed.events.single.isColleague, isTrue);
  });

  test('mail list item maps sender and preview', () {
    final message = mailMessageFromOwaItem({
      'ItemId': {'Id': 'msg-1'},
      'Subject': 'Тема',
      'From': {
        'Mailbox': {'Name': 'Иван', 'EmailAddress': 'ivan@example.com'},
      },
      'DateTimeReceived': '2026-10-06T15:25:03+03:00',
      'IsRead': false,
      'Preview': 'Коротко',
      'HasAttachments': true,
      'ParentFolderId': {'Id': 'inbox-id'},
    });

    expect(message.id, 'msg-1');
    expect(message.sender, 'Иван');
    expect(message.folderId, 'inbox-id');
    expect(message.isRead, isFalse);
    expect(message.hasAttachments, isTrue);
  });

  test('conversation maps topic, unread count and item id', () {
    final message = mailMessageFromConversation({
      'ConversationId': {'Id': 'conv-1'},
      'ConversationTopic': 'Согласование',
      'UniqueSenders': ['Анна', 'Иван'],
      'LastDeliveryTime': '2026-10-07T09:00:00+03:00',
      'UnreadCount': 2,
      'MessageCount': 3,
      'GlobalMessageCount': 4,
      'HasAttachments': false,
      'ItemIds': [
        {'Id': 'latest'},
        {'Id': 'older'},
      ],
    }, folderId: 'inbox-id');

    expect(message.id, 'latest');
    expect(message.conversationId, 'conv-1');
    expect(message.subject, 'Согласование');
    expect(message.sender, 'Анна, Иван');
    expect(message.isRead, isFalse);
    expect(message.messageCount, 4);
    expect(message.canExpand, isTrue);
  });

  test('conversation items flatten nodes and search reads conversations', () {
    final thread = messagesFromConversationItems({
      'Body': {
        'ResponseMessages': {
          'Items': [
            {
              'ResponseCode': 'NoError',
              'Conversation': {
                'ConversationNodes': [
                  {
                    'Items': [
                      {
                        'ItemId': {'Id': 'a'},
                        'Subject': 'Первое',
                        'IsRead': true,
                      },
                    ],
                  },
                  {
                    'Items': [
                      {
                        'ItemId': {'Id': 'b'},
                        'Subject': 'Второе',
                        'IsRead': false,
                      },
                    ],
                  },
                ],
              },
            },
          ],
        },
      },
    });
    expect(thread.map((item) => item.id), ['a', 'b']);

    final found = messagesFromSearchResults({
      'Body': {
        'SearchResults': {
          'Conversations': [
            {
              'ConversationId': {'Id': 'conv-2'},
              'ConversationTopic': 'Найдено',
              'UniqueRecipients': ['Пётр'],
              'UnreadCount': 0,
              'MessageCount': 1,
              'ItemIds': [
                {'Id': 'hit'},
              ],
            },
          ],
        },
      },
    });
    expect(found.single.id, 'hit');
    expect(found.single.sender, 'Пётр');
    expect(found.single.isRead, isTrue);
  });
}
