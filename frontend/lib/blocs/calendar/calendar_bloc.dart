import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';

import '../../models/calendar_event.dart';
import '../../models/colleague_calendar.dart';
import '../../services/ews_api.dart';

part 'calendar_event.dart';
part 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarBlocEvent, CalendarState> {
  CalendarBloc({EwsApi? api, GetStorage? storage})
    : _api = api ?? ewsApi,
      _storage = storage,
      super(CalendarState(focusedDate: DateTime.now())) {
    on<CalendarSessionCleared>(_onSessionCleared);
    on<CalendarOwnerConfigured>(_onOwnerConfigured);
    on<CalendarEventsLoadRequested>(_onEventsLoadRequested);
    on<CalendarEventsRefreshRequested>(_onEventsRefreshRequested);
    on<CalendarViewModeChanged>(_onViewModeChanged);
    on<CalendarGoToTodayRequested>(_onGoToTodayRequested);
    on<CalendarGoPreviousRequested>(_onGoPreviousRequested);
    on<CalendarGoNextRequested>(_onGoNextRequested);
    on<CalendarVisibleMonthChanged>(_onVisibleMonthChanged);
    on<CalendarPlannerDayChanged>(_onPlannerDayChanged);
    on<CalendarEventCreateRequested>(_onEventCreateRequested);
    on<CalendarEventRespondRequested>(_onEventRespondRequested);
    on<CalendarOwnToggled>(_onOwnToggled);
    on<CalendarColleagueToggled>(_onColleagueToggled);
    on<CalendarColleagueAdded>(_onColleagueAdded);
    on<CalendarColleagueRemoved>(_onColleagueRemoved);
    on<CalendarPeopleSearchRequested>(_onPeopleSearchRequested);
  }

  final EwsApi _api;
  final GetStorage? _storage;

  DateTime? _loadedStart;
  DateTime? _loadedEnd;
  int _requestGeneration = 0;
  int _sessionGeneration = 0;
  bool _backgroundRefreshInFlight = false;
  bool _backgroundRefreshQueued = false;

  // ─── Load / Refresh ───────────────────────────────────────────────────────

  void _onSessionCleared(
    CalendarSessionCleared event,
    Emitter<CalendarState> emit,
  ) {
    _requestGeneration++;
    _sessionGeneration++;
    _backgroundRefreshQueued = false;
    _loadedStart = null;
    _loadedEnd = null;
    emit(CalendarState(focusedDate: DateTime.now()));
  }

  void _onOwnerConfigured(
    CalendarOwnerConfigured event,
    Emitter<CalendarState> emit,
  ) {
    final email = event.email.trim().toLowerCase();
    if (email.isEmpty) return;
    if (state.ownerEmail == email &&
        state.ownerDisplayName == event.displayName) {
      return;
    }
    final saved = _readSavedSources(email);
    emit(
      state.copyWith(
        ownerEmail: () => email,
        ownerDisplayName: () => event.displayName,
        ownCalendarEnabled: saved.ownEnabled,
        colleagues: saved.colleagues,
        peopleQuery: '',
        peopleResults: const [],
      ),
    );
  }

  Future<void> _onEventsLoadRequested(
    CalendarEventsLoadRequested event,
    Emitter<CalendarState> emit,
  ) async {
    if (state.events.isEmpty) {
      emit(state.copyWith(isLoading: true, errorMessage: () => null));
    }
    await _fetchEvents(emit);
  }

  Future<void> _onEventsRefreshRequested(
    CalendarEventsRefreshRequested event,
    Emitter<CalendarState> emit,
  ) async {
    if (event.showAnimation) {
      emit(state.copyWith(isRefreshing: true, errorMessage: () => null));
      await _fetchEvents(emit);
      return;
    }
    if (_backgroundRefreshInFlight) {
      _backgroundRefreshQueued = true;
      return;
    }
    _backgroundRefreshInFlight = true;
    final sessionGeneration = _sessionGeneration;
    try {
      await _fetchEvents(emit);
    } finally {
      _backgroundRefreshInFlight = false;
    }
    if (_backgroundRefreshQueued && sessionGeneration == _sessionGeneration) {
      _backgroundRefreshQueued = false;
      add(const CalendarEventsRefreshRequested());
    }
  }

  Future<void> _fetchEvents(Emitter<CalendarState> emit) async {
    final generation = ++_requestGeneration;
    try {
      final range = _fetchRangeFor(state.effectiveFocusedDate, state.viewMode);
      final pendingColleagues = [
        for (final calendar in state.colleagues)
          calendar.enabled
              ? calendar.copyWith(isLoading: true, error: () => null)
              : calendar,
      ];
      if (pendingColleagues.any((calendar) => calendar.isLoading)) {
        emit(state.copyWith(colleagues: pendingColleagues));
      }
      final result = await _api.fetchCalendarEvents(
        start: range.start,
        end: range.end,
      );
      if (generation != _requestGeneration) return;
      final sorted = List<CalendarEvent>.of(result)
        ..sort((a, b) {
          final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aStart.compareTo(bStart);
        });
      _loadedStart = range.start;
      _loadedEnd = range.end;
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          events: sorted,
          errorMessage: () => null,
        ),
      );
      final colleagues = await _fetchColleagueCalendars(
        calendars: pendingColleagues,
        start: range.start,
        end: range.end,
      );
      if (generation != _requestGeneration) return;
      emit(state.copyWith(colleagues: colleagues));
    } catch (error) {
      if (generation != _requestGeneration) return;
      emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<List<ColleagueCalendar>> _fetchColleagueCalendars({
    required List<ColleagueCalendar> calendars,
    required DateTime start,
    required DateTime end,
  }) async {
    final enabled = [
      for (final calendar in calendars)
        if (calendar.enabled) calendar,
    ];
    if (enabled.isEmpty) {
      return [
        for (final calendar in calendars) calendar.copyWith(isLoading: false),
      ];
    }
    try {
      final fetched = await _api.fetchColleagueCalendars(
        calendars: enabled,
        start: start,
        end: end,
      );
      final byEmail = {
        for (final calendar in fetched) calendar.email.toLowerCase(): calendar,
      };
      return [
        for (final calendar in calendars)
          if (calendar.enabled)
            (byEmail[calendar.email.toLowerCase()] ?? calendar).copyWith(
              isLoading: false,
            )
          else
            calendar.copyWith(isLoading: false),
      ];
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      return [
        for (final calendar in calendars)
          calendar.enabled
              ? calendar.copyWith(isLoading: false, error: () => message)
              : calendar,
      ];
    }
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _onViewModeChanged(
    CalendarViewModeChanged event,
    Emitter<CalendarState> emit,
  ) {
    if (state.viewMode == event.mode) return;
    emit(state.copyWith(viewMode: event.mode));
    add(const CalendarEventsLoadRequested());
  }

  void _onGoToTodayRequested(
    CalendarGoToTodayRequested event,
    Emitter<CalendarState> emit,
  ) {
    emit(state.copyWith(focusedDate: () => DateTime.now()));
    add(const CalendarEventsLoadRequested());
  }

  void _onGoPreviousRequested(
    CalendarGoPreviousRequested event,
    Emitter<CalendarState> emit,
  ) {
    final current = state.effectiveFocusedDate;
    final next = switch (state.viewMode) {
      CalendarViewMode.day => DateTime(
        current.year,
        current.month,
        current.day - 1,
      ),
      CalendarViewMode.week => DateTime(
        current.year,
        current.month,
        current.day - 7,
      ),
      CalendarViewMode.month => DateTime(current.year, current.month - 1, 1),
    };
    emit(state.copyWith(focusedDate: () => next));
    add(const CalendarEventsLoadRequested());
  }

  void _onGoNextRequested(
    CalendarGoNextRequested event,
    Emitter<CalendarState> emit,
  ) {
    final current = state.effectiveFocusedDate;
    final next = switch (state.viewMode) {
      CalendarViewMode.day => DateTime(
        current.year,
        current.month,
        current.day + 1,
      ),
      CalendarViewMode.week => DateTime(
        current.year,
        current.month,
        current.day + 7,
      ),
      CalendarViewMode.month => DateTime(current.year, current.month + 1, 1),
    };
    emit(state.copyWith(focusedDate: () => next));
    add(const CalendarEventsLoadRequested());
  }

  void _onVisibleMonthChanged(
    CalendarVisibleMonthChanged event,
    Emitter<CalendarState> emit,
  ) {
    final next = DateTime(event.date.year, event.date.month);
    final current = state.effectiveFocusedDate;
    if (current.year == next.year && current.month == next.month) {
      return;
    }
    emit(state.copyWith(focusedDate: () => next));
    _loadEventsIfNeeded(emit, next);
  }

  void _onPlannerDayChanged(
    CalendarPlannerDayChanged event,
    Emitter<CalendarState> emit,
  ) {
    final next = DateTime(event.date.year, event.date.month, event.date.day);
    final current = state.effectiveFocusedDate;
    if (current.year == next.year &&
        current.month == next.month &&
        current.day == next.day) {
      return;
    }
    emit(state.copyWith(focusedDate: () => next));
    _loadEventsIfNeeded(emit, next);
  }

  void _loadEventsIfNeeded(Emitter<CalendarState> emit, DateTime day) {
    if (_loadedStart == null || _loadedEnd == null) {
      add(const CalendarEventsLoadRequested());
      return;
    }
    const buffer = Duration(days: 5);
    if (day.isBefore(_loadedStart!.add(buffer)) ||
        day.isAfter(_loadedEnd!.subtract(buffer))) {
      add(const CalendarEventsLoadRequested());
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> _onEventCreateRequested(
    CalendarEventCreateRequested event,
    Emitter<CalendarState> emit,
  ) async {
    final sessionGeneration = _sessionGeneration;
    emit(state.copyWith(isCreating: true, errorMessage: () => null));
    try {
      final created = await _api.createCalendarEvent(
        subject: event.subject,
        start: event.start,
        end: event.end,
        location: event.location,
        body: event.body,
      );
      if (sessionGeneration != _sessionGeneration) return;
      final sorted = [...state.events, created]
        ..sort((a, b) {
          final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aStart.compareTo(bStart);
        });
      emit(
        state.copyWith(
          isCreating: false,
          events: sorted,
          errorMessage: () => null,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      emit(
        state.copyWith(
          isCreating: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onEventRespondRequested(
    CalendarEventRespondRequested event,
    Emitter<CalendarState> emit,
  ) async {
    if (event.event.isColleague) return;
    final sessionGeneration = _sessionGeneration;
    emit(state.copyWith(isResponding: true, errorMessage: () => null));
    try {
      final updated = await _api.respondToCalendarEvent(
        event.event.id,
        event.action,
      );
      if (sessionGeneration != _sessionGeneration) return;
      final events = state.events.map((e) {
        return e.id == updated.id ? updated : e;
      }).toList();
      emit(
        state.copyWith(
          isResponding: false,
          events: events,
          errorMessage: () => null,
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      emit(
        state.copyWith(
          isResponding: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _onOwnToggled(CalendarOwnToggled event, Emitter<CalendarState> emit) {
    if (state.ownCalendarEnabled == event.enabled) return;
    emit(state.copyWith(ownCalendarEnabled: event.enabled));
    _persistSources();
  }

  Future<void> _onColleagueToggled(
    CalendarColleagueToggled event,
    Emitter<CalendarState> emit,
  ) async {
    final email = event.email.trim().toLowerCase();
    final index = state.colleagues.indexWhere(
      (calendar) => calendar.email == email,
    );
    if (index < 0) return;
    final current = state.colleagues[index];
    if (current.enabled == event.enabled) return;

    final updated = [...state.colleagues];
    if (!event.enabled) {
      updated[index] = current.copyWith(enabled: false, isLoading: false);
      emit(state.copyWith(colleagues: updated));
      _persistSources();
      return;
    }

    updated[index] = current.copyWith(
      enabled: true,
      isLoading: true,
      error: () => null,
    );
    emit(state.copyWith(colleagues: updated));
    _persistSources();

    final range = _fetchRangeFor(state.effectiveFocusedDate, state.viewMode);
    final sessionGeneration = _sessionGeneration;
    try {
      final fetched = await _api.fetchColleagueCalendar(
        email: current.email,
        colorIndex: current.colorIndex,
        enabled: true,
        start: range.start,
        end: range.end,
      );
      if (sessionGeneration != _sessionGeneration) return;
      final latest = [...state.colleagues];
      final latestIndex = latest.indexWhere(
        (calendar) => calendar.email == email,
      );
      if (latestIndex < 0 || !latest[latestIndex].enabled) return;
      latest[latestIndex] = fetched.copyWith(
        displayName: current.displayName,
        isLoading: false,
      );
      emit(state.copyWith(colleagues: latest));
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      final latest = [...state.colleagues];
      final latestIndex = latest.indexWhere(
        (calendar) => calendar.email == email,
      );
      if (latestIndex < 0) return;
      latest[latestIndex] = latest[latestIndex].copyWith(
        isLoading: false,
        error: () => error.toString().replaceFirst('Exception: ', ''),
      );
      emit(state.copyWith(colleagues: latest));
    }
  }

  Future<void> _onColleagueAdded(
    CalendarColleagueAdded event,
    Emitter<CalendarState> emit,
  ) async {
    final email = event.email.trim().toLowerCase();
    if (email.isEmpty) return;
    if (state.ownerEmail != null && email == state.ownerEmail) return;

    final existingIndex = state.colleagues.indexWhere(
      (calendar) => calendar.email == email,
    );
    if (existingIndex >= 0) {
      emit(
        state.copyWith(peopleQuery: '', peopleResults: const []),
      );
      add(CalendarColleagueToggled(email: email, enabled: true));
      return;
    }

    final added = ColleagueCalendar(
      email: email,
      displayName: event.displayName.trim().isEmpty
          ? email
          : event.displayName.trim(),
      colorIndex: _nextColorIndex(state.colleagues),
      enabled: true,
      isLoading: true,
    );
    emit(
      state.copyWith(
        colleagues: [...state.colleagues, added],
        peopleQuery: '',
        peopleResults: const [],
      ),
    );
    _persistSources();

    final range = _fetchRangeFor(state.effectiveFocusedDate, state.viewMode);
    final sessionGeneration = _sessionGeneration;
    try {
      final fetched = await _api.fetchColleagueCalendar(
        email: added.email,
        colorIndex: added.colorIndex,
        enabled: true,
        start: range.start,
        end: range.end,
      );
      if (sessionGeneration != _sessionGeneration) return;
      emit(
        state.copyWith(
          colleagues: [
            for (final calendar in state.colleagues)
              if (calendar.email == email)
                fetched.copyWith(
                  displayName: added.displayName,
                  isLoading: false,
                )
              else
                calendar,
          ],
        ),
      );
    } catch (error) {
      if (sessionGeneration != _sessionGeneration) return;
      emit(
        state.copyWith(
          colleagues: [
            for (final calendar in state.colleagues)
              if (calendar.email == email)
                calendar.copyWith(
                  isLoading: false,
                  error: () =>
                      error.toString().replaceFirst('Exception: ', ''),
                )
              else
                calendar,
          ],
        ),
      );
    }
  }

  void _onColleagueRemoved(
    CalendarColleagueRemoved event,
    Emitter<CalendarState> emit,
  ) {
    final email = event.email.trim().toLowerCase();
    final next = [
      for (final calendar in state.colleagues)
        if (calendar.email != email) calendar,
    ];
    if (next.length == state.colleagues.length) return;
    emit(state.copyWith(colleagues: next));
    _persistSources();
  }

  Future<void> _onPeopleSearchRequested(
    CalendarPeopleSearchRequested event,
    Emitter<CalendarState> emit,
  ) async {
    final query = event.query.trim();
    emit(
      state.copyWith(
        peopleQuery: query,
        isSearchingPeople: query.isNotEmpty,
        peopleResults: query.isEmpty ? const [] : state.peopleResults,
      ),
    );
    if (query.isEmpty) return;
    final sessionGeneration = _sessionGeneration;
    try {
      final results = await _api.searchCalendarPeople(query);
      if (sessionGeneration != _sessionGeneration) return;
      if (state.peopleQuery != query) return;
      final known = {
        if (state.ownerEmail != null) state.ownerEmail!,
        for (final calendar in state.colleagues) calendar.email,
      };
      emit(
        state.copyWith(
          isSearchingPeople: false,
          peopleResults: [
            for (final person in results)
              if (!known.contains(person.email.toLowerCase())) person,
          ],
        ),
      );
    } catch (_) {
      if (sessionGeneration != _sessionGeneration) return;
      if (state.peopleQuery != query) return;
      emit(
        state.copyWith(isSearchingPeople: false, peopleResults: const []),
      );
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  ({DateTime start, DateTime end}) _fetchRangeFor(
    DateTime anchor,
    CalendarViewMode mode,
  ) {
    return switch (mode) {
      CalendarViewMode.day => (
        start: DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).subtract(const Duration(days: 14)),
        end: DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).add(const Duration(days: 15)),
      ),
      CalendarViewMode.week => (
        start: CalendarState.startOfWeek(
          anchor,
        ).subtract(const Duration(days: 21)),
        end: CalendarState.startOfWeek(anchor).add(const Duration(days: 28)),
      ),
      CalendarViewMode.month => _monthFetchRange(anchor),
    };
  }

  ({DateTime start, DateTime end}) _monthFetchRange(DateTime anchor) {
    final monthStart = DateTime(anchor.year, anchor.month, 1);
    final monthEnd = DateTime(anchor.year, anchor.month + 1, 0);
    final weekStart = CalendarState.startOfWeek(monthStart);
    final weekEnd = CalendarState.startOfWeek(monthEnd);
    return (
      start: weekStart.subtract(const Duration(days: 7)),
      end: weekEnd.add(const Duration(days: 14)),
    );
  }

  int _nextColorIndex(List<ColleagueCalendar> colleagues) {
    final maxIndex = CalendarPalette.colors.length;
    final used = {for (final calendar in colleagues) calendar.colorIndex};
    for (var index = 1; index < maxIndex; index++) {
      if (!used.contains(index)) return index;
    }
    return (colleagues.length % (maxIndex - 1)) + 1;
  }

  String? _storageKey() {
    final email = state.ownerEmail;
    if (email == null || email.isEmpty) return null;
    return 'calendar_sources_$email';
  }

  ({bool ownEnabled, List<ColleagueCalendar> colleagues}) _readSavedSources(
    String email,
  ) {
    final storage = _storage;
    if (storage == null) {
      return (ownEnabled: true, colleagues: const []);
    }
    try {
      final raw = storage.read('calendar_sources_$email');
      if (raw is! Map) {
        return (ownEnabled: true, colleagues: const []);
      }
      final data = Map<String, dynamic>.from(raw);
      final colleagues = <ColleagueCalendar>[];
      for (final item in data['colleagues'] as List<dynamic>? ?? const []) {
        if (item is! Map) continue;
        colleagues.add(
          ColleagueCalendar.fromStorage(Map<String, dynamic>.from(item)),
        );
      }
      return (
        ownEnabled: data['ownEnabled'] as bool? ?? true,
        colleagues: colleagues,
      );
    } catch (_) {
      return (ownEnabled: true, colleagues: const []);
    }
  }

  void _persistSources() {
    final storage = _storage;
    final key = _storageKey();
    if (storage == null || key == null) return;
    try {
      storage.write(key, {
        'ownEnabled': state.ownCalendarEnabled,
        'colleagues': [
          for (final calendar in state.colleagues) calendar.toStorage(),
        ],
      });
    } catch (_) {}
  }
}
