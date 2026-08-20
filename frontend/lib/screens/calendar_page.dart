import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../theme/ddt_theme.dart';
import '../widgets/calendar_event_card.dart';
import '../widgets/calendar_event_side_panel.dart';
import '../widgets/compose_event_panel.dart';
import '../widgets/ddt_glass_fab.dart';
import '../widgets/ddt_segmented_control.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final EventsController _eventsController;

  @override
  void initState() {
    super.initState();
    _eventsController = EventsController()
      ..onFocusedDayChange = (day) {
        context.read<CalendarBloc>().add(CalendarPlannerDayChanged(day));
      };

    final bloc = context.read<CalendarBloc>();
    // Синхронизируем уже загруженные события при открытии раздела.
    _syncPlannerEvents(bloc.state.events);
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
      listenWhen: (previous, current) => previous.events != current.events,
      listener: (context, state) => _syncPlannerEvents(state.events),
      child: Stack(
        children: [
          BlocBuilder<CalendarBloc, CalendarState>(
            buildWhen: (previous, current) =>
                previous.isLoading != current.isLoading ||
                previous.errorMessage != current.errorMessage ||
                previous.events.isEmpty != current.events.isEmpty ||
                previous.viewMode != current.viewMode ||
                previous.focusedDate != current.focusedDate,
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

              return RefreshIndicator(
                onRefresh: () async => context.read<CalendarBloc>().add(
                  const CalendarEventsRefreshRequested(),
                ),
                child: DdtTheme.glass(
                  context: context,
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CalendarToolbar(state: state),
                      SizedBox(height: 12.h),
                      Expanded(
                        child: _CalendarBody(
                          state: state,
                          eventsController: _eventsController,
                          plannerInitialDate: _plannerInitialDate,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            right: 24.w,
            bottom: 24.h,
            child: DdtGlassFab(
              onPressed: () => showComposeEventPanel(context),
              icon: Icons.add,
              label: 'Событие',
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

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({required this.state});

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);

    return Row(
      children: [
        OutlinedButton(
          onPressed: () => context.read<CalendarBloc>().add(
            const CalendarGoToTodayRequested(),
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
          child: Text('Сегодня', style: DdtTheme.style(fontSize: 13.sp)),
        ),
        _NavButton(
          icon: CupertinoIcons.chevron_left,
          onPressed: () => context.read<CalendarBloc>().add(
            const CalendarGoPreviousRequested(),
          ),
        ),
        _NavButton(
          icon: CupertinoIcons.chevron_right,
          onPressed: () =>
              context.read<CalendarBloc>().add(const CalendarGoNextRequested()),
        ),
        SizedBox(width: 8.w),
        Text(
          state.titleLabel,
          style: DdtTheme.style(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const Spacer(),
        DdtSegmentedControl<CalendarViewMode>(
          segments: const [
            DdtSegmentedControlSegment(
              value: CalendarViewMode.day,
              label: 'День',
              icon: CupertinoIcons.time,
            ),
            DdtSegmentedControlSegment(
              value: CalendarViewMode.week,
              label: 'Неделя',
              icon: CupertinoIcons.calendar,
            ),
            DdtSegmentedControlSegment(
              value: CalendarViewMode.month,
              label: 'Месяц',
              icon: CupertinoIcons.calendar_badge_plus,
            ),
          ],
          selected: state.viewMode,
          onChanged: (mode) =>
              context.read<CalendarBloc>().add(CalendarViewModeChanged(mode)),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20.sp),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.state,
    required this.eventsController,
    required this.plannerInitialDate,
  });

  final CalendarState state;
  final EventsController eventsController;
  final DateTime Function(DateTime, CalendarViewMode) plannerInitialDate;

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
    final key = ValueKey(
      '${mode.name}-${focused.year}-${focused.month}-${focused.day}',
    );

    if (mode == CalendarViewMode.month) {
      return _MonthCalendar(
        key: key,
        eventsController: eventsController,
        focused: focused,
      );
    }

    return _PlannerCalendar(
      key: key,
      eventsController: eventsController,
      focused: plannerInitialDate(focused, mode),
      daysShowed: state.plannerDaysShowed,
      maxNextDays: state.plannerMaxNextDays,
    );
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
                style: TextStyle(
                  fontFamily: 'Nunito Sans',
                  fontSize: 12,
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
                style: TextStyle(
                  fontFamily: 'Nunito Sans',
                  fontSize: 13,
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

class _PlannerCalendar extends StatelessWidget {
  const _PlannerCalendar({
    super.key,
    required this.eventsController,
    required this.focused,
    required this.daysShowed,
    required this.maxNextDays,
  });

  final EventsController eventsController;
  final DateTime focused;
  final int daysShowed;
  final int maxNextDays;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const heightPerMinute = 1.15;
    const timesWidth = 48.0;
    const headerHeight = 48.0;
    const fullDayBarHeight = 24.0;
    const fullDayEventHeight = 18.0;
    final now = DateTime.now();
    final initialScroll = heightPerMinute * (now.hour * 60 + now.minute - 60);

    return ClipRRect(
      borderRadius: DdtTheme.radius,
      child: EventsPlanner(
        controller: eventsController,
        initialDate: focused,
        daysShowed: daysShowed,
        heightPerMinute: heightPerMinute,
        initialVerticalScrollOffset: initialScroll.clamp(0, double.infinity),
        maxPreviousDays: 0,
        maxNextDays: maxNextDays,
        horizontalScrollPhysics: const NeverScrollableScrollPhysics(),
        automaticAdjustHorizontalScrollToDay: false,
        pinchToZoomParam: const PinchToZoomParameters(pinchToZoom: false),
        onDayChange: (day) =>
            context.read<CalendarBloc>().add(CalendarPlannerDayChanged(day)),
        daysHeaderParam: DaysHeaderParam(
          daysHeaderHeight: headerHeight,
          daysHeaderColor: Colors.transparent,
          dayHeaderBuilder: (day, isToday) =>
              _CalendarBody.buildDayHeader(context, day, isToday),
        ),
        fullDayParam: FullDayParam(
          fullDayEventsBarLeftText: 'Весь день',
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
          todayColor: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.06),
          dayTopPadding: 4,
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
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    super.key,
    required this.eventsController,
    required this.focused,
  });

  final EventsController eventsController;
  final DateTime focused;

  @override
  Widget build(BuildContext context) {
    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    return ClipRRect(
      borderRadius: DdtTheme.radius,
      child: EventsMonths(
        controller: eventsController,
        initialMonth: DateTime(focused.year, focused.month),
        onMonthChange: (date) =>
            context.read<CalendarBloc>().add(CalendarVisibleMonthChanged(date)),
        weekParam: WeekParam(
          startOfWeekDay: CalendarState.startOfWeekDay,
          headerHeight: 36,
          weekHeight: 108,
          headerDayText: (dayOfMonth) {
            final index = (dayOfMonth - 1) % 7;
            return _CalendarBody._weekDayFullLabels[index];
          },
          headerStyle: TextStyle(
            fontFamily: 'Nunito Sans',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        daysParam: DaysParam(
          headerHeight: 22,
          eventHeight: 18,
          eventSpacing: 2,
          dayHeaderTextBuilder: (day) => '${day.day}',
          dayEventBuilder: (event, width, height) =>
              _CalendarBody.buildMonthEvent(context, event, width, height),
        ),
        pinchToZoomParam: PinchToZoom(pinchToZoom: false),
      ),
    );
  }
}
