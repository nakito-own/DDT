part of 'calendar_bloc.dart';

enum CalendarViewMode { day, week, month }

final class CalendarState extends Equatable {
  const CalendarState({
    this.events = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.isResponding = false,
    this.errorMessage,
    this.viewMode = CalendarViewMode.week,
    this.focusedDate,
  });

  final List<CalendarEvent> events;
  final bool isLoading;
  final bool isCreating;
  final bool isResponding;
  final String? errorMessage;
  final CalendarViewMode viewMode;
  final DateTime? focusedDate;

  DateTime get effectiveFocusedDate => focusedDate ?? DateTime.now();

  static const startOfWeekDay = DateTime.monday;

  int get plannerDaysShowed => switch (viewMode) {
    CalendarViewMode.day => 1,
    CalendarViewMode.week => 7,
    CalendarViewMode.month => 1,
  };

  int get plannerMaxNextDays => switch (viewMode) {
    CalendarViewMode.day => 1,
    CalendarViewMode.week => 7,
    CalendarViewMode.month => 0,
  };

  String get titleLabel {
    final date = effectiveFocusedDate;
    return switch (viewMode) {
      CalendarViewMode.day =>
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
      CalendarViewMode.week => _weekRangeLabel(date),
      CalendarViewMode.month => _monthLabel(date),
    };
  }

  CalendarState copyWith({
    List<CalendarEvent>? events,
    bool? isLoading,
    bool? isCreating,
    bool? isResponding,
    String? Function()? errorMessage,
    CalendarViewMode? viewMode,
    DateTime? Function()? focusedDate,
  }) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isResponding: isResponding ?? this.isResponding,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      viewMode: viewMode ?? this.viewMode,
      focusedDate: focusedDate != null ? focusedDate() : this.focusedDate,
    );
  }

  String _weekRangeLabel(DateTime date) {
    final start = startOfWeek(date);
    final end = start.add(const Duration(days: 6));
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

  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    final diff = (weekday - startOfWeekDay + 7) % 7;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: diff));
  }

  @override
  List<Object?> get props => [
    events,
    isLoading,
    isCreating,
    isResponding,
    errorMessage,
    viewMode,
    focusedDate,
  ];
}
