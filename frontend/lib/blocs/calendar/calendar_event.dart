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

/// Обновить события (кнопка в аппбаре или WS-уведомление).
final class CalendarEventsRefreshRequested extends CalendarBlocEvent {
  const CalendarEventsRefreshRequested({this.showAnimation = false});

  /// Анимация только для явного действия пользователя.
  final bool showAnimation;

  @override
  List<Object?> get props => [showAnimation];
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

/// Владелец сессии известен — восстановить сохранённые календари коллег.
final class CalendarOwnerConfigured extends CalendarBlocEvent {
  const CalendarOwnerConfigured({
    required this.email,
    required this.displayName,
  });

  final String email;
  final String displayName;

  @override
  List<Object?> get props => [email, displayName];
}

/// Включить/выключить свой календарь.
final class CalendarOwnToggled extends CalendarBlocEvent {
  const CalendarOwnToggled({required this.enabled});

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

/// Включить/выключить календарь коллеги.
final class CalendarColleagueToggled extends CalendarBlocEvent {
  const CalendarColleagueToggled({required this.email, required this.enabled});

  final String email;
  final bool enabled;

  @override
  List<Object?> get props => [email, enabled];
}

/// Добавить календарь коллеги в список просмотра.
final class CalendarColleagueAdded extends CalendarBlocEvent {
  const CalendarColleagueAdded({
    required this.email,
    required this.displayName,
  });

  final String email;
  final String displayName;

  @override
  List<Object?> get props => [email, displayName];
}

/// Убрать календарь коллеги из списка.
final class CalendarColleagueRemoved extends CalendarBlocEvent {
  const CalendarColleagueRemoved(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Поиск коллег в адресной книге Exchange.
final class CalendarPeopleSearchRequested extends CalendarBlocEvent {
  const CalendarPeopleSearchRequested(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
