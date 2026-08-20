part of 'calendar_bloc.dart';

sealed class CalendarBlocEvent extends Equatable {
  const CalendarBlocEvent();

  @override
  List<Object?> get props => [];
}

/// Очистить персональные данные календаря при завершении сессии.
final class CalendarSessionCleared extends CalendarBlocEvent {
  const CalendarSessionCleared();
}

/// Загрузить события при открытии раздела.
final class CalendarEventsLoadRequested extends CalendarBlocEvent {
  const CalendarEventsLoadRequested();
}

/// Обновить события (например, по WS-уведомлению).
final class CalendarEventsRefreshRequested extends CalendarBlocEvent {
  const CalendarEventsRefreshRequested();
}

/// Пользователь переключил режим отображения (день/неделя/месяц).
final class CalendarViewModeChanged extends CalendarBlocEvent {
  const CalendarViewModeChanged(this.mode);

  final CalendarViewMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Переместить фокус на сегодня.
final class CalendarGoToTodayRequested extends CalendarBlocEvent {
  const CalendarGoToTodayRequested();
}

/// Перейти к предыдущему периоду.
final class CalendarGoPreviousRequested extends CalendarBlocEvent {
  const CalendarGoPreviousRequested();
}

/// Перейти к следующему периоду.
final class CalendarGoNextRequested extends CalendarBlocEvent {
  const CalendarGoNextRequested();
}

/// Видимый месяц изменился (calendar widget callback).
final class CalendarVisibleMonthChanged extends CalendarBlocEvent {
  const CalendarVisibleMonthChanged(this.date);

  final DateTime date;

  @override
  List<Object?> get props => [date];
}

/// Видимый день в планнере изменился (calendar widget callback).
final class CalendarPlannerDayChanged extends CalendarBlocEvent {
  const CalendarPlannerDayChanged(this.date);

  final DateTime date;

  @override
  List<Object?> get props => [date];
}

/// Создать новое событие.
final class CalendarEventCreateRequested extends CalendarBlocEvent {
  const CalendarEventCreateRequested({
    required this.subject,
    required this.start,
    required this.end,
    this.location,
    this.body,
  });

  final String subject;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? body;

  @override
  List<Object?> get props => [subject, start, end, location, body];
}

/// Ответить на приглашение.
final class CalendarEventRespondRequested extends CalendarBlocEvent {
  const CalendarEventRespondRequested({
    required this.event,
    required this.action,
  });

  final CalendarEvent event;
  final CalendarEventResponseAction action;

  @override
  List<Object?> get props => [event, action];
}
