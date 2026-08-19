import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/calendar_event.dart';
import '../../services/ews_api.dart';

part 'calendar_event.dart';
part 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarBlocEvent, CalendarState> {
  CalendarBloc({EwsApi? api})
    : _api = api ?? ewsApi,
      super(CalendarState(focusedDate: DateTime.now())) {
    on<CalendarSessionCleared>(_onSessionCleared);
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
  }

  final EwsApi _api;

  DateTime? _loadedStart;
  DateTime? _loadedEnd;
  int _requestGeneration = 0;
  int _sessionGeneration = 0;

  // ─── Load / Refresh ───────────────────────────────────────────────────────

  void _onSessionCleared(
    CalendarSessionCleared event,
    Emitter<CalendarState> emit,
  ) {
    _requestGeneration++;
    _sessionGeneration++;
    _loadedStart = null;
    _loadedEnd = null;
    emit(CalendarState(focusedDate: DateTime.now()));
  }

  Future<void> _onEventsLoadRequested(
    CalendarEventsLoadRequested event,
    Emitter<CalendarState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    await _fetchEvents(emit);
  }

  Future<void> _onEventsRefreshRequested(
    CalendarEventsRefreshRequested event,
    Emitter<CalendarState> emit,
  ) async {
    await _fetchEvents(emit);
  }

  Future<void> _fetchEvents(Emitter<CalendarState> emit) async {
    final generation = ++_requestGeneration;
    try {
      final range = _fetchRangeFor(state.effectiveFocusedDate, state.viewMode);
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
          events: sorted,
          errorMessage: () => null,
        ),
      );
    } catch (error) {
      if (generation != _requestGeneration) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
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
    emit(state.copyWith(focusedDate: () => event.date));
    _loadEventsIfNeeded(emit, event.date);
  }

  void _onPlannerDayChanged(
    CalendarPlannerDayChanged event,
    Emitter<CalendarState> emit,
  ) {
    emit(state.copyWith(focusedDate: () => event.date));
    _loadEventsIfNeeded(emit, event.date);
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
}
