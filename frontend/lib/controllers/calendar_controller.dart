import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart';

import '../models/calendar_event.dart';
import '../services/ews_api.dart';

enum CalendarViewMode { day, week, month }

class CalendarController extends GetxController {
  CalendarController({EwsApi? api}) : _api = api ?? ewsApi;

  static const startOfWeekDay = DateTime.monday;

  final EwsApi _api;
  final EventsController eventsController = EventsController();

  final RxBool isLoading = false.obs;
  final RxBool isCreating = false.obs;
  final RxBool isResponding = false.obs;
  final RxnString errorMessage = RxnString();
  final RxList<CalendarEvent> events = <CalendarEvent>[].obs;
  final Rx<CalendarViewMode> viewMode = CalendarViewMode.week.obs;
  final Rx<DateTime> focusedDate = DateTime.now().obs;

  DateTime? _loadedStart;
  DateTime? _loadedEnd;

  @override
  void onInit() {
    super.onInit();
    eventsController.onFocusedDayChange = _onFocusedDayChanged;
    loadEvents();
  }

  @override
  void onClose() {
    eventsController.dispose();
    super.onClose();
  }

  void _onFocusedDayChanged(DateTime day) {
    focusedDate.value = day;
    _loadEventsIfNeeded(day);
  }

  Future<void> loadEvents() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final range = _fetchRangeFor(focusedDate.value);
      final result = await _api.fetchCalendarEvents(
        start: range.start,
        end: range.end,
      );
      events.assignAll(result);
      _loadedStart = range.start;
      _loadedEnd = range.end;
      _syncPlannerEvents();
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadEventsIfNeeded(DateTime day) async {
    if (_loadedStart == null || _loadedEnd == null) {
      await loadEvents();
      return;
    }

    const buffer = Duration(days: 5);
    if (day.isBefore(_loadedStart!.add(buffer)) ||
        day.isAfter(_loadedEnd!.subtract(buffer))) {
      await loadEvents();
    }
  }

  void setViewMode(CalendarViewMode mode) {
    if (viewMode.value == mode) return;
    viewMode.value = mode;
    loadEvents();
  }

  void goToToday() {
    final today = DateTime.now();
    focusedDate.value = today;
    eventsController.updateFocusedDay(today);
    loadEvents();
  }

  void goPrevious() {
    final current = focusedDate.value;
    final next = switch (viewMode.value) {
      CalendarViewMode.day => current.addCalendarDays(-1),
      CalendarViewMode.week => current.addCalendarDays(-7),
      CalendarViewMode.month => DateTime(current.year, current.month - 1, 1),
    };
    focusedDate.value = next;
    eventsController.updateFocusedDay(next);
    loadEvents();
  }

  void goNext() {
    final current = focusedDate.value;
    final next = switch (viewMode.value) {
      CalendarViewMode.day => current.addCalendarDays(1),
      CalendarViewMode.week => current.addCalendarDays(7),
      CalendarViewMode.month => DateTime(current.year, current.month + 1, 1),
    };
    focusedDate.value = next;
    eventsController.updateFocusedDay(next);
    loadEvents();
  }

  void onVisibleMonthChanged(DateTime monthFirstDay) {
    focusedDate.value = monthFirstDay;
    _loadEventsIfNeeded(monthFirstDay);
  }

  void onPlannerDayChanged(DateTime firstVisibleDay) {
    focusedDate.value = firstVisibleDay;
    _loadEventsIfNeeded(firstVisibleDay);
  }

  Future<bool> createEvent({
    required String subject,
    required DateTime start,
    required DateTime end,
    String? location,
    String? body,
  }) async {
    isCreating.value = true;
    errorMessage.value = null;

    try {
      final event = await _api.createCalendarEvent(
        subject: subject,
        start: start,
        end: end,
        location: location,
        body: body,
      );
      events.add(event);
      _sortEvents();
      _syncPlannerEvents();
      return true;
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isCreating.value = false;
    }
  }

  Future<bool> respondToEvent(
    CalendarEvent event,
    CalendarEventResponseAction action,
  ) async {
    isResponding.value = true;
    errorMessage.value = null;

    try {
      final updated = await _api.respondToCalendarEvent(event.id, action);
      final index = events.indexWhere((item) => item.id == event.id);
      if (index >= 0) {
        events[index] = updated;
      }
      _syncPlannerEvents();
      return true;
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isResponding.value = false;
    }
  }

  void updateEvent(CalendarEvent updated) {
    final index = events.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      events[index] = updated;
      _syncPlannerEvents();
    }
  }

  DateTime plannerInitialDate(DateTime date) {
    return switch (viewMode.value) {
      CalendarViewMode.day => date.withoutTime,
      CalendarViewMode.week => date.startOfWeek(startOfWeekDay),
      CalendarViewMode.month => date.withoutTime,
    };
  }

  int get plannerDaysShowed => switch (viewMode.value) {
        CalendarViewMode.day => 1,
        CalendarViewMode.week => 7,
        CalendarViewMode.month => 1,
      };

  int get plannerMaxNextDays => switch (viewMode.value) {
        CalendarViewMode.day => 1,
        CalendarViewMode.week => 7,
        CalendarViewMode.month => 0,
      };

  String titleLabel() {
    final date = focusedDate.value;
    return switch (viewMode.value) {
      CalendarViewMode.day =>
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
      CalendarViewMode.week => _weekRangeLabel(date),
      CalendarViewMode.month => _monthLabel(date),
    };
  }

  void _sortEvents() {
    events.sort((a, b) {
      final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aStart.compareTo(bStart);
    });
  }

  void _syncPlannerEvents() {
    final plannerEvents = events
        .map(_toPlannerEvent)
        .whereType<Event>()
        .toList(growable: false);

    eventsController.updateCalendarData((data) {
      data.dayEvents.clear();
      data.addEvents(plannerEvents);
    });
  }

  Event? _toPlannerEvent(CalendarEvent event) {
    final start = event.start?.toLocal();
    if (start == null) return null;

    final end = event.end?.toLocal() ?? start.add(const Duration(hours: 1));
    if (!end.isAfter(start)) return null;

    return Event(
      startTime: start,
      endTime: end,
      title: event.subject,
      description: event.location,
      data: event,
      color: _eventColor(event),
      textColor: _eventTextColor(event),
    );
  }

  Color _eventColor(CalendarEvent event) {
    if (event.needsResponse) {
      return AppColors.primary.withValues(alpha: 0.1);
    }
    if (event.isDeclined) {
      return Colors.grey.withValues(alpha: 0.08);
    }
    return Colors.transparent;
  }

  Color _eventTextColor(CalendarEvent event) => Colors.transparent;

  ({DateTime start, DateTime end}) _fetchRangeFor(DateTime anchor) {
    return switch (viewMode.value) {
      CalendarViewMode.day => (
          start: anchor.withoutTime.subtract(const Duration(days: 14)),
          end: anchor.withoutTime.add(const Duration(days: 15)),
        ),
      CalendarViewMode.week => (
          start: anchor
              .startOfWeek(startOfWeekDay)
              .subtract(const Duration(days: 21)),
          end: anchor
              .startOfWeek(startOfWeekDay)
              .add(const Duration(days: 28)),
        ),
      CalendarViewMode.month => _monthFetchRange(anchor),
    };
  }

  ({DateTime start, DateTime end}) _monthFetchRange(DateTime anchor) {
    final monthStart = DateTime(anchor.year, anchor.month, 1);
    final monthEnd = DateTime(anchor.year, anchor.month + 1, 0);
    return (
      start: monthStart
          .startOfWeek(startOfWeekDay)
          .subtract(const Duration(days: 7)),
      end: monthEnd.startOfWeek(startOfWeekDay).add(const Duration(days: 14)),
    );
  }

  String _weekRangeLabel(DateTime date) {
    final start = date.startOfWeek(startOfWeekDay);
    final end = start.addCalendarDays(6);
    final sameMonth = start.month == end.month;
    if (sameMonth) {
      return '${start.day}–${end.day}.${start.month.toString().padLeft(2, '0')}.${start.year}';
    }
    return '${start.day}.${start.month.toString().padLeft(2, '0')} – ${end.day}.${end.month.toString().padLeft(2, '0')}.${end.year}';
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
