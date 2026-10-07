part of 'calendar_bloc.dart';

enum CalendarViewMode { day, week, month }

final class CalendarState extends Equatable {
  const CalendarState({
    this.events = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isCreating = false,
    this.isResponding = false,
    this.errorMessage,
    this.viewMode = CalendarViewMode.week,
    this.focusedDate,
    this.ownerEmail,
    this.ownerDisplayName,
    this.ownCalendarEnabled = true,
    this.colleagues = const [],
    this.peopleQuery = '',
    this.peopleResults = const [],
    this.isSearchingPeople = false,
  });

  final List<CalendarEvent> events;
  final bool isLoading;
  final bool isRefreshing;
  final bool isCreating;
  final bool isResponding;
  final String? errorMessage;
  final CalendarViewMode viewMode;
  final DateTime? focusedDate;
  final String? ownerEmail;
  final String? ownerDisplayName;
  final bool ownCalendarEnabled;
  final List<ColleagueCalendar> colleagues;
  final String peopleQuery;
  final List<CalendarPerson> peopleResults;
  final bool isSearchingPeople;

  DateTime get effectiveFocusedDate => focusedDate ?? DateTime.now();

  String get ownCalendarLabel {
    final name = ownerDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Мой календарь';
  }

  List<CalendarEvent> get visibleEvents {
    return [
      if (ownCalendarEnabled) ...events,
      for (final calendar in colleagues)
        if (calendar.enabled) ...calendar.events,
    ];
  }

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
    bool? isRefreshing,
    bool? isCreating,
    bool? isResponding,
    String? Function()? errorMessage,
    CalendarViewMode? viewMode,
    DateTime? Function()? focusedDate,
    String? Function()? ownerEmail,
    String? Function()? ownerDisplayName,
    bool? ownCalendarEnabled,
    List<ColleagueCalendar>? colleagues,
    String? peopleQuery,
    List<CalendarPerson>? peopleResults,
    bool? isSearchingPeople,
  }) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCreating: isCreating ?? this.isCreating,
      isResponding: isResponding ?? this.isResponding,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      viewMode: viewMode ?? this.viewMode,
      focusedDate: focusedDate != null ? focusedDate() : this.focusedDate,
      ownerEmail: ownerEmail != null ? ownerEmail() : this.ownerEmail,
      ownerDisplayName: ownerDisplayName != null
          ? ownerDisplayName()
          : this.ownerDisplayName,
      ownCalendarEnabled: ownCalendarEnabled ?? this.ownCalendarEnabled,
      colleagues: colleagues ?? this.colleagues,
      peopleQuery: peopleQuery ?? this.peopleQuery,
      peopleResults: peopleResults ?? this.peopleResults,
      isSearchingPeople: isSearchingPeople ?? this.isSearchingPeople,
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
    isRefreshing,
    isCreating,
    isResponding,
    errorMessage,
    viewMode,
    focusedDate,
    ownerEmail,
    ownerDisplayName,
    ownCalendarEnabled,
    colleagues,
    peopleQuery,
    peopleResults,
    isSearchingPeople,
  ];
}
