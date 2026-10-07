import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../theme/ddt_scroll_behavior.dart';
import '../theme/ddt_theme.dart';
import '../widgets/calendar_event_card.dart';
import '../widgets/calendar_event_side_panel.dart';
import '../widgets/calendar_sidebar.dart';
import '../widgets/ddt_section_refresh.dart';
import '../widgets/ddt_section_sidebar.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_side_panel_divider.dart';
import '../theme/ddt_typography.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final EventsController _eventsController;
  double? _plannerVerticalScrollOffset;

  @override
  void initState() {
    super.initState();
    _eventsController = EventsController()
      ..onFocusedDayChange = (day) {
        final bloc = context.read<CalendarBloc>();
        if (bloc.state.viewMode == CalendarViewMode.month) return;
        bloc.add(CalendarPlannerDayChanged(day));
      };

    final bloc = context.read<CalendarBloc>();
    // Синхронизируем уже загруженные события при открытии раздела.
    _syncPlannerEvents(bloc.state.visibleEvents);
  }

  @override
  void dispose() {
    _eventsController.dispose();
    super.dispose();
  }

  void _syncPlannerEvents(List<CalendarEvent> events) {
    final plannerEvents = events
        .map(_toPlannerEvent)
        .whereType<Event>()
        .toList(growable: false);

    _eventsController.updateCalendarData((data) {
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
      color: Colors.transparent,
      textColor: _eventTextColor(event),
    );
  }

  Color _eventTextColor(CalendarEvent event) => Colors.transparent;

  DateTime _plannerInitialDate(DateTime date, CalendarViewMode mode) {
    return switch (mode) {
      CalendarViewMode.day => DateTime(date.year, date.month, date.day),
      CalendarViewMode.week => CalendarState.startOfWeek(date),
      CalendarViewMode.month => DateTime(date.year, date.month, date.day),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CalendarBloc, CalendarState>(
      listenWhen: (previous, current) =>
          previous.events != current.events ||
          previous.colleagues != current.colleagues ||
          previous.ownCalendarEnabled != current.ownCalendarEnabled ||
          (previous.isRefreshing && !current.isRefreshing),
      listener: (context, state) => _syncPlannerEvents(state.visibleEvents),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DdtSectionSidebarFrame(child: CalendarSidebar()),
          DdtSectionSidebar.afterScrollbarGapBox(),
          const DdtSidePanelDivider(),
          DdtSectionSidebar.dividerGap(),
          Expanded(
            child: BlocBuilder<CalendarBloc, CalendarState>(
              buildWhen: (previous, current) =>
                  (previous.isLoading && previous.events.isEmpty) !=
                      (current.isLoading && current.events.isEmpty) ||
                  previous.events.isEmpty != current.events.isEmpty ||
                  ((previous.errorMessage != current.errorMessage) &&
                      (previous.events.isEmpty || current.events.isEmpty)),
              builder: (context, state) {
                if (state.isLoading && state.events.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.errorMessage != null && state.events.isEmpty) {
                  return _ErrorState(
                    message: state.errorMessage!,
                    onRetry: () => context.read<CalendarBloc>().add(
                      const CalendarEventsLoadRequested(),
                    ),
                  );
                }

                return Padding(
                  padding: DdtShellMetrics.fixedTopPadding(context),
                  child: BlocBuilder<CalendarBloc, CalendarState>(
                    buildWhen: (previous, current) =>
                        previous.isRefreshing != current.isRefreshing,
                    builder: (context, state) {
                      return DdtSectionRefreshOverlay(
                        isRefreshing: state.isRefreshing,
                        child: BlocBuilder<CalendarBloc, CalendarState>(
                          buildWhen: (previous, current) =>
                              previous.viewMode != current.viewMode ||
                              previous.focusedDate != current.focusedDate ||
                              previous.events.any(_spansMultipleDays) !=
                                  current.events.any(_spansMultipleDays) ||
                              previous.colleagues != current.colleagues ||
                              previous.ownCalendarEnabled !=
                                  current.ownCalendarEnabled,
                          builder: (context, state) {
                            return _CalendarBody(
                              state: state,
                              eventsController: _eventsController,
                              plannerInitialDate: _plannerInitialDate,
                              plannerVerticalScrollOffset:
                                  _plannerVerticalScrollOffset,
                              onPlannerVerticalScrollOffset: (offset) {
                                _plannerVerticalScrollOffset = offset;
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          SizedBox(height: 12.h),
          Button(
            text: 'Повторить',
            onPressed: onRetry,
            borderRadius: DdtTheme.radius,
          ),
        ],
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.state,
    required this.eventsController,
    required this.plannerInitialDate,
    required this.plannerVerticalScrollOffset,
    required this.onPlannerVerticalScrollOffset,
  });

  final CalendarState state;
  final EventsController eventsController;
  final DateTime Function(DateTime, CalendarViewMode) plannerInitialDate;
  final double? plannerVerticalScrollOffset;
  final ValueChanged<double> onPlannerVerticalScrollOffset;

  static const _weekDayFullLabels = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  @override
  Widget build(BuildContext context) {
    final mode = state.viewMode;
    final focused = state.effectiveFocusedDate;
    final calendar = ScrollConfiguration(
      behavior: const DdtWheelOnlyScrollBehavior(),
      child: mode == CalendarViewMode.month
          ? _MonthCalendar(eventsController: eventsController, focused: focused)
          : _PlannerCalendar(
              key: ValueKey(_plannerPeriodKey(focused, mode)),
              eventsController: eventsController,
              focused: plannerInitialDate(focused, mode),
              daysShowed: state.plannerDaysShowed,
              maxNextDays: state.plannerMaxNextDays,
              showAllDayBar: state.visibleEvents.any(_spansMultipleDays),
              preservedVerticalOffset: plannerVerticalScrollOffset,
              onVerticalScrollOffset: onPlannerVerticalScrollOffset,
            ),
    );

    return calendar;
  }

  static String _plannerPeriodKey(DateTime focused, CalendarViewMode mode) {
    return switch (mode) {
      CalendarViewMode.day =>
        'day-${focused.year}-${focused.month}-${focused.day}',
      CalendarViewMode.week => () {
        final start = CalendarState.startOfWeek(focused);
        return 'week-${start.year}-${start.month}-${start.day}';
      }(),
      CalendarViewMode.month => 'month',
    };
  }

  static Widget buildDayHeader(
    BuildContext context,
    DateTime day,
    bool isToday,
  ) {
    final weekdayLabel = _weekDayFullLabels[(day.weekday - 1) % 7];
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    return SizedBox(
      height: 46,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                weekdayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTypography.style(
                  size: DdtTypography.labelSmallSize,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isToday ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: DdtTypography.style(
                  size: DdtTypography.labelSize,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: isToday ? Colors.white : textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildPlannerEvent(
    BuildContext context,
    Event event,
    double height,
    double width,
  ) {
    final calendarEvent = event.data;
    if (calendarEvent is! CalendarEvent) {
      return SizedBox(height: height, width: width);
    }

    final slotHeight = height.clamp(0.0, double.infinity);
    final slotWidth = width.clamp(0.0, double.infinity);

    return SizedBox(
      height: slotHeight,
      width: slotWidth,
      child: CalendarEventCard(
        event: calendarEvent,
        maxHeight: slotHeight,
        maxWidth: slotWidth,
        onTap: () => showCalendarEventSidePanel(context, calendarEvent),
      ),
    );
  }

  static Widget buildMonthEvent(
    BuildContext context,
    Event event,
    double? width,
    double? height,
  ) {
    final eventHeight = height ?? 20.0;
    final eventWidth = width;
    final calendarEvent = event.data;
    if (calendarEvent is! CalendarEvent) {
      return SizedBox(height: eventHeight, width: eventWidth);
    }

    return SizedBox(
      height: eventHeight,
      width: eventWidth,
      child: CalendarEventCard(
        event: calendarEvent,
        maxHeight: eventHeight,
        maxWidth: eventWidth ?? double.infinity,
        onTap: () => showCalendarEventSidePanel(context, calendarEvent),
      ),
    );
  }

  static Widget buildFullDayEvent(
    BuildContext context,
    Event event,
    double width,
    double height,
  ) {
    final calendarEvent = event.data;
    if (calendarEvent is! CalendarEvent) {
      return SizedBox(height: height, width: width);
    }

    return SizedBox(
      height: height,
      width: width,
      child: CalendarEventCard(
        event: calendarEvent,
        maxHeight: height,
        maxWidth: width,
        onTap: () => showCalendarEventSidePanel(context, calendarEvent),
      ),
    );
  }
}

bool _spansMultipleDays(CalendarEvent event) {
  final start = event.start?.toLocal();
  final end = event.end?.toLocal();
  if (start == null || end == null) return false;
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  return endDay.isAfter(startDay);
}

class _PlannerCalendar extends StatefulWidget {
  const _PlannerCalendar({
    super.key,
    required this.eventsController,
    required this.focused,
    required this.daysShowed,
    required this.maxNextDays,
    required this.showAllDayBar,
    required this.preservedVerticalOffset,
    required this.onVerticalScrollOffset,
  });

  final EventsController eventsController;
  final DateTime focused;
  final int daysShowed;
  final int maxNextDays;
  final bool showAllDayBar;
  final double? preservedVerticalOffset;
  final ValueChanged<double> onVerticalScrollOffset;

  @override
  State<_PlannerCalendar> createState() => _PlannerCalendarState();
}

class _PlannerCalendarState extends State<_PlannerCalendar> {
  static const _heightPerMinute = 1.15;
  static const _timeLineTopMargin = 12.0;
  static const _layoutRetryLimit = 8;

  final _plannerKey = GlobalKey<EventsPlannerState>();

  @override
  void initState() {
    super.initState();
    _restoreOrAlignVerticalOffset();
  }

  double _currentTimeOffset() {
    final now = DateTime.now();
    return _heightPerMinute * (now.hour * 60 + now.minute) - _timeLineTopMargin;
  }

  void _restoreOrAlignVerticalOffset([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _plannerKey.currentState?.mainVerticalController;
      if (controller == null || !controller.hasClients) {
        if (attempt < _layoutRetryLimit) {
          _restoreOrAlignVerticalOffset(attempt + 1);
        }
        return;
      }

      final maxOffset = controller.position.maxScrollExtent;
      final viewport = controller.position.viewportDimension;
      final dayHeight = _heightPerMinute * 60 * 24;
      final expectedMax = (dayHeight - viewport).clamp(0.0, double.infinity);
      final layoutReady = viewport > 0 && (expectedMax - maxOffset).abs() <= 48;
      if (!layoutReady && attempt < _layoutRetryLimit) {
        _restoreOrAlignVerticalOffset(attempt + 1);
        return;
      }

      final target = (widget.preservedVerticalOffset ?? _currentTimeOffset())
          .clamp(0.0, maxOffset);
      controller.jumpTo(target);
      widget.onVerticalScrollOffset(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const heightPerMinute = _heightPerMinute;
    const timesWidth = 48.0;
    const headerHeight = 48.0;
    const fullDayBarHeight = 32.0;
    const fullDayEventHeight = 28.0;
    final now = DateTime.now();
    final initialScroll =
        widget.preservedVerticalOffset ??
        heightPerMinute * (now.hour * 60 + now.minute) - _timeLineTopMargin;

    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    return ClipRRect(
      borderRadius: DdtTheme.radius,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;
          if (notification is ScrollUpdateNotification ||
              notification is ScrollEndNotification) {
            widget.onVerticalScrollOffset(notification.metrics.pixels);
          }
          return false;
        },
        child: EventsPlanner(
          key: _plannerKey,
          controller: widget.eventsController,
          initialDate: widget.focused,
          daysShowed: widget.daysShowed,
          heightPerMinute: heightPerMinute,
          initialVerticalScrollOffset: initialScroll.clamp(0, double.infinity),
          maxPreviousDays: 0,
          maxNextDays: widget.maxNextDays,
          horizontalScrollPhysics: const NeverScrollableScrollPhysics(),
          automaticAdjustHorizontalScrollToDay: false,
          pinchToZoomParam: const PinchToZoomParameters(pinchToZoom: false),
          onDayChange: (day) {
            final bloc = context.read<CalendarBloc>();
            if (bloc.state.viewMode == CalendarViewMode.week) {
              final current = bloc.state.effectiveFocusedDate;
              if (_isSameDay(
                CalendarState.startOfWeek(current),
                CalendarState.startOfWeek(day),
              )) {
                return;
              }
            }
            bloc.add(CalendarPlannerDayChanged(day));
          },
          daysHeaderParam: DaysHeaderParam(
            daysHeaderHeight: headerHeight,
            daysHeaderColor: Colors.transparent,
            dayHeaderBuilder: (day, isToday) =>
                _CalendarBody.buildDayHeader(context, day, isToday),
          ),
          fullDayParam: FullDayParam(
            fullDayEventsBarVisibility: widget.showAllDayBar,
            showMultiDayEvents: widget.showAllDayBar,
            fullDayEventsBarDecoration: const BoxDecoration(),
            fullDayBackgroundColor: Colors.transparent,
            fullDayEventsBarLeftWidget: Center(
              child: Text(
                'Весь\nдень',
                textAlign: TextAlign.center,
                style: DdtTypography.style(
                  size: DdtTypography.microSize,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                  height: 1.1,
                ),
              ),
            ),
            fullDayEventsBarHeight: fullDayBarHeight,
            fullDayEventHeight: fullDayEventHeight,
            fullDayEventBuilder: (event, width) =>
                _CalendarBody.buildFullDayEvent(
                  context,
                  event,
                  width,
                  fullDayEventHeight,
                ),
            fullDayEventsBuilder: (events, width) {
              return SizedBox(
                height: fullDayBarHeight,
                width: width,
                child: events.isEmpty
                    ? const SizedBox.shrink()
                    : ClipRect(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < events.length; i++) ...[
                              if (i > 0) const SizedBox(height: 2),
                              _CalendarBody.buildFullDayEvent(
                                context,
                                events[i],
                                width,
                                fullDayEventHeight,
                              ),
                            ],
                          ],
                        ),
                      ),
              );
            },
          ),
          dayParam: DayParam(
            todayColor: AppColors.primary.withValues(
              alpha: isDark ? 0.08 : 0.06,
            ),
            dayTopPadding: 0,
            dayBottomPadding: 8,
            dayCustomPainter: (heightPerMinute, isToday) => LinesPainter(
              heightPerMinute: heightPerMinute,
              isToday: isToday,
              lineColor: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.08),
              hourStrokeWidth: 0.45,
              halfStrokeWidth: 0.2,
              quarterStrokeWidth: 0.12,
            ),
            dayEventBuilder: (event, height, width, _) =>
                _CalendarBody.buildPlannerEvent(context, event, height, width),
          ),
          timesIndicatorsParam: TimesIndicatorsParam(
            timesIndicatorsWidth: timesWidth,
            timesIndicatorsCustomPainter: (heightPerMinute) => HoursPainter(
              heightPerMinute: heightPerMinute,
              showCurrentHour: true,
              hourColor: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.black.withValues(alpha: 0.5),
              halfHourColor: isDark
                  ? Colors.white.withValues(alpha: 0.34)
                  : Colors.black.withValues(alpha: 0.32),
              quarterHourColor: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.2),
              currentHourIndicatorColor: AppColors.accent,
            ),
          ),
          currentHourIndicatorParam: CurrentHourIndicatorParam(
            currentHourIndicatorColor: AppColors.accent,
          ),
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({required this.eventsController, required this.focused});

  final EventsController eventsController;
  final DateTime focused;

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  final _monthsKey = GlobalKey<EventsMonthsState>();
  late DateTime _visibleMonth;
  bool _syncingFromView = false;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.focused.year, widget.focused.month);
  }

  @override
  void didUpdateWidget(covariant _MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_syncingFromView) {
      _syncingFromView = false;
      return;
    }
    final target = DateTime(widget.focused.year, widget.focused.month);
    if (target.year == _visibleMonth.year &&
        target.month == _visibleMonth.month) {
      return;
    }
    _visibleMonth = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _monthsKey.currentState?.jumpToDate(target);
    });
  }

  void _onMonthChange(DateTime date) {
    final next = DateTime(date.year, date.month);
    if (next.year == _visibleMonth.year && next.month == _visibleMonth.month) {
      return;
    }
    _syncingFromView = true;
    _visibleMonth = next;
    context.read<CalendarBloc>().add(CalendarVisibleMonthChanged(date));
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: DdtTheme.radius,
      child: Theme(
        data: theme.copyWith(
          appBarTheme: theme.appBarTheme.copyWith(
            backgroundColor: Colors.transparent,
          ),
        ),
        child: EventsMonths(
          key: _monthsKey,
          controller: widget.eventsController,
          initialMonth: _visibleMonth,
          automaticAdjustScrollToStartOfMonth: false,
          onMonthChange: _onMonthChange,
          weekParam: WeekParam(
            startOfWeekDay: CalendarState.startOfWeekDay,
            headerHeight: 36,
            weekHeight: 108,
            headerDayText: (dayOfMonth) {
              final index = (dayOfMonth - 1) % 7;
              return _CalendarBody._weekDayFullLabels[index];
            },
            headerStyle: DdtTypography.style(
              size: DdtTypography.captionSize,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          daysParam: DaysParam(
            headerHeight: 22,
            eventHeight: 28,
            eventSpacing: 2,
            dayHeaderTextBuilder: (day) => '${day.day}',
            dayEventBuilder: (event, width, height) =>
                _CalendarBody.buildMonthEvent(context, event, width, height),
            dayMoreEventsBuilder: (count, _) => Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'ещё $count',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTypography.style(
                    size: DdtTypography.captionSize,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ),
            ),
          ),
          pinchToZoomParam: PinchToZoom(pinchToZoom: false),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
