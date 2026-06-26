import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:infinite_calendar_view/infinite_calendar_view.dart';

import '../controllers/calendar_controller.dart';
import '../models/calendar_event.dart';
import '../theme/ddt_theme.dart';
import '../widgets/calendar_event_card.dart';
import '../widgets/calendar_event_side_panel.dart';
import '../widgets/compose_event_panel.dart';
import '../widgets/ddt_glass_fab.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CalendarController());

    return Stack(
      children: [
        Obx(() {
          if (controller.isLoading.value && controller.events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value != null &&
              controller.events.isEmpty) {
            return _ErrorState(
              message: controller.errorMessage.value!,
              onRetry: controller.loadEvents,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadEvents,
            child: DdtTheme.glass(
              context: context,
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CalendarToolbar(controller: controller),
                  if (controller.isLoading.value) ...[
                    SizedBox(height: 8.h),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  SizedBox(height: 12.h),
                  Expanded(
                    child: _CalendarBody(controller: controller),
                  ),
                ],
              ),
            ),
          );
        }),
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
  const _CalendarToolbar({required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    return Obx(
      () => Row(
        children: [
          OutlinedButton(
            onPressed: controller.goToToday,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
            child: Text(
              'Сегодня',
              style: DdtTheme.style(fontSize: 13.sp),
            ),
          ),
          _NavButton(
            icon: CupertinoIcons.chevron_left,
            onPressed: controller.goPrevious,
          ),
          _NavButton(
            icon: CupertinoIcons.chevron_right,
            onPressed: controller.goNext,
          ),
          SizedBox(width: 8.w),
          Text(
            controller.titleLabel(),
            style: DdtTheme.style(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          _ViewModeSelector(
            mode: controller.viewMode.value,
            onChanged: controller.setViewMode,
            textSecondary: textSecondary,
          ),
        ],
      ),
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

class _ViewModeSelector extends StatelessWidget {
  const _ViewModeSelector({
    required this.mode,
    required this.onChanged,
    required this.textSecondary,
  });

  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onChanged;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SegmentedButton<CalendarViewMode>(
      segments: [
        ButtonSegment(
          value: CalendarViewMode.day,
          label: const Text('День'),
          icon: Icon(CupertinoIcons.time, size: 16.sp),
        ),
        ButtonSegment(
          value: CalendarViewMode.week,
          label: const Text('Неделя'),
          icon: Icon(CupertinoIcons.calendar, size: 16.sp),
        ),
        ButtonSegment(
          value: CalendarViewMode.month,
          label: const Text('Месяц'),
          icon: Icon(CupertinoIcons.calendar_badge_plus, size: 16.sp),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(DdtTheme.style(fontSize: 12.sp)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.85);
          }
          return textSecondary;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(
              color: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.2),
            );
          }
          return BorderSide.none;
        }),
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({required this.controller});

  final CalendarController controller;

  static const _weekDayFullLabels = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  static String _weekdayLabel(DateTime day) =>
      _weekDayFullLabels[(day.weekday - 1) % 7];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = controller.viewMode.value;
      final focused = controller.focusedDate.value;
      final key = ValueKey('${mode.name}-${focused.year}-${focused.month}-${focused.day}');

      if (mode == CalendarViewMode.month) {
        return _MonthCalendar(
          key: key,
          controller: controller,
          focused: focused,
        );
      }

      return _PlannerCalendar(
        key: key,
        controller: controller,
        focused: focused,
        daysShowed: controller.plannerDaysShowed,
      );
    });
  }

  static Widget buildDayHeader(
    BuildContext context,
    DateTime day,
    bool isToday,
  ) {
    final weekdayLabel = _weekdayLabel(day);
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
    required this.controller,
    required this.focused,
    required this.daysShowed,
  });

  final CalendarController controller;
  final DateTime focused;
  final int daysShowed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initialDate = controller.plannerInitialDate(focused);
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
        controller: controller.eventsController,
        initialDate: initialDate,
        daysShowed: daysShowed,
        heightPerMinute: heightPerMinute,
        initialVerticalScrollOffset: initialScroll.clamp(0, double.infinity),
        maxPreviousDays: 0,
        maxNextDays: controller.plannerMaxNextDays,
        horizontalScrollPhysics: const NeverScrollableScrollPhysics(),
        automaticAdjustHorizontalScrollToDay: false,
        pinchToZoomParam: const PinchToZoomParameters(pinchToZoom: false),
        onDayChange: controller.onPlannerDayChanged,
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
          fullDayEventBuilder: (event, width) => _CalendarBody.buildFullDayEvent(
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
    required this.controller,
    required this.focused,
  });

  final CalendarController controller;
  final DateTime focused;

  @override
  Widget build(BuildContext context) {
    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    return ClipRRect(
      borderRadius: DdtTheme.radius,
      child: EventsMonths(
        controller: controller.eventsController,
        initialMonth: DateTime(focused.year, focused.month),
        onMonthChange: controller.onVisibleMonthChanged,
        weekParam: WeekParam(
          startOfWeekDay: CalendarController.startOfWeekDay,
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
        pinchToZoomParam: PinchToZoom(
          pinchToZoom: false,
        ),
      ),
    );
  }
}
