import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/blocs/calendar/calendar_bloc.dart';
import 'package:ddt_frontend/models/calendar_event.dart';
import 'package:ddt_frontend/models/colleague_calendar.dart';
import 'package:ddt_frontend/services/ews_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CalendarEvent eventOn(DateTime start) {
    return CalendarEvent(
      id: 'evt-${start.millisecondsSinceEpoch}',
      subject: 'Встреча',
      start: start,
      end: start.add(const Duration(hours: 1)),
      location: null,
      organizer: null,
    );
  }

  test('view mode switch does not show a refresh animation', () async {
    final api = _FakeEwsApi();
    final bloc = CalendarBloc(api: api);
    addTearDown(bloc.close);

    api.nextEvents = [eventOn(DateTime(2026, 10, 6, 10))];
    bloc.add(const CalendarEventsLoadRequested());
    await bloc.stream.firstWhere((state) => !state.isLoading);

    api.nextEvents = [eventOn(DateTime(2026, 10, 6, 11))];
    bloc.add(const CalendarViewModeChanged(CalendarViewMode.day));

    final inFlight = await bloc.stream.firstWhere(
      (state) => state.viewMode == CalendarViewMode.day,
    );
    expect(inFlight.isRefreshing, isFalse);
    expect(inFlight.isLoading, isFalse);

    final settled = await bloc.stream.firstWhere(
      (state) =>
          state.viewMode == CalendarViewMode.day &&
          state.events.any((event) => event.subject == 'Встреча') &&
          !state.isLoading,
    );
    expect(settled.isRefreshing, isFalse);
    expect(settled.isLoading, isFalse);
  });

  test('forced refresh is the only path that sets isRefreshing', () async {
    final api = _FakeEwsApi();
    final bloc = CalendarBloc(api: api);
    addTearDown(bloc.close);

    api.holdNextFetch = Completer<void>();
    api.nextEvents = [eventOn(DateTime(2026, 10, 6, 10))];
    bloc.add(const CalendarEventsLoadRequested());
    await bloc.stream.firstWhere((state) => state.isLoading);
    api.holdNextFetch!.complete();
    await bloc.stream.firstWhere((state) => !state.isLoading);

    api.holdNextFetch = Completer<void>();
    bloc.add(const CalendarEventsRefreshRequested(showAnimation: true));
    final refreshing = await bloc.stream.firstWhere(
      (state) => state.isRefreshing,
    );
    expect(refreshing.isRefreshing, isTrue);

    api.holdNextFetch!.complete();
    final done = await bloc.stream.firstWhere((state) => !state.isRefreshing);
    expect(done.isRefreshing, isFalse);
  });

  test(
    'scrolling to the same month does not emit a new focused date',
    () async {
      final api = _FakeEwsApi();
      final bloc = CalendarBloc(api: api);
      addTearDown(bloc.close);

      bloc.add(const CalendarViewModeChanged(CalendarViewMode.month));
      bloc.add(CalendarVisibleMonthChanged(DateTime(2026, 3, 1)));
      await bloc.stream.firstWhere(
        (state) =>
            state.viewMode == CalendarViewMode.month &&
            state.focusedDate?.year == 2026 &&
            state.focusedDate?.month == 3,
      );

      bloc.add(CalendarVisibleMonthChanged(DateTime(2026, 3, 18)));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.effectiveFocusedDate.month, 3);
      expect(bloc.state.effectiveFocusedDate.day, 1);
    },
  );

  test('enabled colleague calendar appears in visible events', () async {
    final api = _FakeEwsApi();
    final bloc = CalendarBloc(api: api);
    addTearDown(bloc.close);

    api.nextEvents = [eventOn(DateTime(2026, 10, 6, 10))];
    api.colleagueEvents['ivanov@mos.ru'] = [
      CalendarEvent(
        id: 'col-1',
        subject: 'Планёрка',
        start: DateTime(2026, 10, 6, 12),
        end: DateTime(2026, 10, 6, 13),
        location: null,
        organizer: 'ivanov@mos.ru',
      ),
    ];

    bloc.add(const CalendarEventsLoadRequested());
    await bloc.stream.firstWhere((state) => !state.isLoading);

    bloc.add(
      const CalendarColleagueAdded(
        email: 'ivanov@mos.ru',
        displayName: 'Иванов',
      ),
    );
    final withColleague = await bloc.stream.firstWhere(
      (state) =>
          state.colleagues.any((calendar) => calendar.email == 'ivanov@mos.ru') &&
          !state.colleagues.first.isLoading,
    );
    expect(withColleague.visibleEvents.any((event) => event.subject == 'Планёрка'), isTrue);
    expect(withColleague.visibleEvents.any((event) => event.subject == 'Встреча'), isTrue);

    bloc.add(
      const CalendarColleagueToggled(email: 'ivanov@mos.ru', enabled: false),
    );
    final hidden = await bloc.stream.firstWhere(
      (state) => state.colleagues.any((calendar) => !calendar.enabled),
    );
    expect(hidden.visibleEvents.any((event) => event.subject == 'Планёрка'), isFalse);
    expect(hidden.visibleEvents.any((event) => event.subject == 'Встреча'), isTrue);

    bloc.add(const CalendarOwnToggled(enabled: false));
    final ownHidden = await bloc.stream.firstWhere(
      (state) => !state.ownCalendarEnabled,
    );
    expect(ownHidden.visibleEvents, isEmpty);
  });
}

class _FakeEwsApi extends EwsApi {
  _FakeEwsApi();

  List<CalendarEvent> nextEvents = const [];
  Completer<void>? holdNextFetch;
  final Map<String, List<CalendarEvent>> colleagueEvents = {};

  @override
  Future<List<CalendarEvent>> fetchCalendarEvents({
    DateTime? start,
    DateTime? end,
  }) async {
    final hold = holdNextFetch;
    if (hold != null) {
      await hold.future;
    }
    return List<CalendarEvent>.of(nextEvents);
  }

  @override
  Future<ColleagueCalendar> fetchColleagueCalendar({
    required String email,
    required int colorIndex,
    bool enabled = true,
    DateTime? start,
    DateTime? end,
  }) async {
    final events = colleagueEvents[email.toLowerCase()] ?? const [];
    return ColleagueCalendar(
      email: email.toLowerCase(),
      displayName: email,
      colorIndex: colorIndex,
      enabled: enabled,
      events: [
        for (final event in events)
          event.copyWith(
            isColleague: true,
            colorIndex: colorIndex,
            mailbox: email.toLowerCase(),
          ),
      ],
    );
  }

  @override
  Future<List<ColleagueCalendar>> fetchColleagueCalendars({
    required List<ColleagueCalendar> calendars,
    DateTime? start,
    DateTime? end,
  }) async {
    return [
      for (final calendar in calendars)
        await fetchColleagueCalendar(
          email: calendar.email,
          colorIndex: calendar.colorIndex,
          enabled: calendar.enabled,
          start: start,
          end: end,
        ),
    ];
  }
}
