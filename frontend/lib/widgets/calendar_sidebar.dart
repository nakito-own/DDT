import 'dart:async';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../models/colleague_calendar.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'compose_event_panel.dart';
import 'ddt_app_input.dart';
import 'ddt_checkbox.dart';
import 'ddt_icon.dart';
import 'ddt_panel_primary_button.dart';
import 'ddt_scroll_edge_fade.dart';
import 'ddt_section_sidebar.dart';
import 'ddt_tappable.dart';

const _calendarSourcesFadeHeight = 14.0;

/// Left column of the calendar section: create action and a miniature calendar
/// one step wider than the main view (day → week, week → month, month → year).
class CalendarSidebar extends StatelessWidget {
  const CalendarSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) =>
          previous.viewMode != current.viewMode ||
          previous.focusedDate != current.focusedDate ||
          previous.events != current.events ||
          previous.colleagues != current.colleagues ||
          previous.ownCalendarEnabled != current.ownCalendarEnabled ||
          previous.peopleResults != current.peopleResults ||
          previous.isSearchingPeople != current.isSearchingPeople ||
          previous.peopleQuery != current.peopleQuery ||
          previous.ownerDisplayName != current.ownerDisplayName,
      builder: (context, state) {
        final horizontal = DdtSectionSidebar.scrollContentPadding(bottom: 0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DdtSectionSidebarField(
                    gapAbove: false,
                    child: DdtPanelPrimaryButton(
                      label: 'Событие',
                      icon: DdtIcons.add,
                      onPressed: () => showComposeEventPanel(context),
                    ),
                  ),
                  SizedBox(height: DdtSectionSidebar.afterPrimaryButtonGap),
                  _CalendarMiniView(state: state),
                ],
              ),
            ),
            SizedBox(height: DdtSectionSidebar.blockGap),
            Expanded(
              child: DdtSectionSidebarScroll(
                child: DdtScrollEdgeFade(
                  edgeFadeHeight: _calendarSourcesFadeHeight,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal.left,
                      _calendarSourcesFadeHeight.h,
                      horizontal.right,
                      _calendarSourcesFadeHeight.h,
                    ),
                    children: [
                      _CalendarSources(state: state),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CalendarMiniView extends StatelessWidget {
  const _CalendarMiniView({required this.state});

  final CalendarState state;

  static const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  static const _monthsFull = [
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
  static const _monthsShort = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  static const _monthsChip = [
    'Янв',
    'Фев',
    'Мар',
    'Апр',
    'Май',
    'Июн',
    'Июл',
    'Авг',
    'Сен',
    'Окт',
    'Ноя',
    'Дек',
  ];

  @override
  Widget build(BuildContext context) {
    final focused = state.effectiveFocusedDate;
    return switch (state.viewMode) {
      CalendarViewMode.day => _MiniWeek(
        focused: focused,
        events: state.visibleEvents,
        onSelectDay: (day) => _selectDay(context, day),
        onPrevious: () => _shiftPeriod(context, -1),
        onNext: () => _shiftPeriod(context, 1),
      ),
      CalendarViewMode.week => _MiniMonth(
        focused: focused,
        onSelectDay: (day) => _selectDay(context, day),
        onPrevious: () => _shiftPeriod(context, -1),
        onNext: () => _shiftPeriod(context, 1),
      ),
      CalendarViewMode.month => _MiniYear(
        focused: focused,
        onSelectMonth: (year, month) => _selectMonth(context, year, month),
        onPrevious: () => _shiftPeriod(context, -1),
        onNext: () => _shiftPeriod(context, 1),
      ),
    };
  }

  void _shiftPeriod(BuildContext context, int direction) {
    final focused = state.effectiveFocusedDate;
    final next = switch (state.viewMode) {
      CalendarViewMode.day => DateTime(
        focused.year,
        focused.month,
        focused.day + 7 * direction,
      ),
      CalendarViewMode.week => _shiftMonth(focused, direction),
      CalendarViewMode.month => _shiftYear(focused, direction),
    };
    final bloc = context.read<CalendarBloc>();
    if (state.viewMode == CalendarViewMode.month) {
      bloc.add(CalendarVisibleMonthChanged(next));
      return;
    }
    bloc.add(CalendarPlannerDayChanged(next));
  }

  DateTime _shiftMonth(DateTime date, int months) {
    final shifted = DateTime(date.year, date.month + months, 1);
    final lastDay = DateTime(shifted.year, shifted.month + 1, 0).day;
    return DateTime(shifted.year, shifted.month, date.day.clamp(1, lastDay));
  }

  DateTime _shiftYear(DateTime date, int years) {
    final year = date.year + years;
    final lastDay = DateTime(year, date.month + 1, 0).day;
    return DateTime(year, date.month, date.day.clamp(1, lastDay));
  }

  void _selectDay(BuildContext context, DateTime day) {
    final focused = state.effectiveFocusedDate;
    final next = DateTime(day.year, day.month, day.day);
    final periodChanged = switch (state.viewMode) {
      CalendarViewMode.day => !_sameDay(focused, next),
      CalendarViewMode.week => !_sameDay(
        CalendarState.startOfWeek(focused),
        CalendarState.startOfWeek(next),
      ),
      CalendarViewMode.month =>
        focused.year != next.year || focused.month != next.month,
    };
    if (!periodChanged) return;
    context.read<CalendarBloc>().add(CalendarPlannerDayChanged(next));
  }

  void _selectMonth(BuildContext context, int year, int month) {
    final focused = state.effectiveFocusedDate;
    if (focused.year == year && focused.month == month) return;
    context.read<CalendarBloc>().add(
      CalendarVisibleMonthChanged(DateTime(year, month, 1)),
    );
  }
}

class _MiniWeek extends StatelessWidget {
  const _MiniWeek({
    required this.focused,
    required this.events,
    required this.onSelectDay,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime focused;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Same block as a six-week month grid: one row per day, with event stripes.
  static double bodyHeight() => 6 * (32 + 2.h);

  @override
  Widget build(BuildContext context) {
    final start = CalendarState.startOfWeek(focused);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    final end = days.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodHeader(
          label: _weekRangeLabel(start, end),
          previousTooltip: 'Предыдущая неделя',
          nextTooltip: 'Следующая неделя',
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: bodyHeight(),
          child: Column(
            children: [
              for (final day in days)
                Expanded(
                  child: _MiniWeekDayRow(
                    day: day,
                    events: _eventsOn(day),
                    selected: _sameDay(day, focused),
                    today: _isToday(day),
                    onTap: () => onSelectDay(day),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<CalendarEvent> _eventsOn(DateTime day) {
    final matched =
        [
          for (final event in events)
            if (_eventCoversDay(event, day)) event,
        ]..sort((a, b) {
          final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aStart.compareTo(bStart);
        });
    return matched;
  }

  String _weekRangeLabel(DateTime start, DateTime end) {
    final months = _CalendarMiniView._monthsShort;
    final full = _CalendarMiniView._monthsFull;
    if (start.year != end.year) {
      return '${start.day} ${months[start.month - 1]} ${start.year} – ${end.day} ${months[end.month - 1]} ${end.year}';
    }
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${full[start.month - 1]}';
    }
    return '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]}';
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({
    required this.focused,
    required this.onSelectDay,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime focused;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks = _weeksOf(DateTime(focused.year, focused.month));
    final weekStart = CalendarState.startOfWeek(focused);
    final band = AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodHeader(
          label:
              '${_CalendarMiniView._monthsFull[focused.month - 1]} ${focused.year}',
          previousTooltip: 'Предыдущий месяц',
          nextTooltip: 'Следующий месяц',
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        SizedBox(height: 10.h),
        const _WeekdayHeader(labels: _CalendarMiniView._weekdays),
        SizedBox(height: 4.h),
        for (final week in weeks)
          Padding(
            padding: EdgeInsets.only(bottom: 2.h),
            child: DecoratedBox(
              decoration: _sameDay(week.first, weekStart)
                  ? BoxDecoration(
                      color: band,
                      borderRadius: BorderRadius.circular(8.r),
                    )
                  : const BoxDecoration(),
              child: Row(
                children: [
                  for (final day in week)
                    Expanded(
                      child: _MiniDayCell(
                        day: day,
                        today: _isToday(day),
                        dimmed:
                            day.month != focused.month &&
                            !_sameDay(
                              CalendarState.startOfWeek(day),
                              weekStart,
                            ),
                        onTap: () => onSelectDay(day),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<List<DateTime>> _weeksOf(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    var cursor = CalendarState.startOfWeek(first);
    final lastWeekStart = CalendarState.startOfWeek(last);
    final end = DateTime(
      lastWeekStart.year,
      lastWeekStart.month,
      lastWeekStart.day + 6,
    );
    final weeks = <List<DateTime>>[];
    while (!cursor.isAfter(end)) {
      weeks.add([
        for (var i = 0; i < 7; i++)
          DateTime(cursor.year, cursor.month, cursor.day + i),
      ]);
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 7);
    }
    return weeks;
  }
}

class _MiniYear extends StatelessWidget {
  const _MiniYear({
    required this.focused,
    required this.onSelectMonth,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime focused;
  final void Function(int year, int month) onSelectMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodHeader(
          label: '${focused.year}',
          previousTooltip: 'Предыдущий год',
          nextTooltip: 'Следующий год',
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        SizedBox(height: 10.h),
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) SizedBox(height: 6.h),
          Row(
            children: [
              for (var column = 0; column < 3; column++)
                Expanded(
                  child: _MiniMonthCell(
                    label: _CalendarMiniView._monthsChip[row * 3 + column],
                    selected: focused.month == row * 3 + column + 1,
                    today:
                        now.year == focused.year &&
                        now.month == row * 3 + column + 1,
                    onTap: () =>
                        onSelectMonth(focused.year, row * 3 + column + 1),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.label,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final String previousTooltip;
  final String nextTooltip;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          _PeriodArrow(
            icon: DdtIcons.chevronLeft,
            tooltip: previousTooltip,
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSize,
                fontWeight: FontWeight.w700,
                color: DdtTheme.taskCardTextPrimary(context),
              ),
            ),
          ),
          _PeriodArrow(
            icon: DdtIcons.chevronRight,
            tooltip: nextTooltip,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _PeriodArrow extends StatefulWidget {
  const _PeriodArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_PeriodArrow> createState() => _PeriodArrowState();
}

class _PeriodArrowState extends State<_PeriodArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? AppColors.primary : DdtTheme.textMuted(context);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: DdtIcon(widget.icon, size: 12.sp, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniWeekDayRow extends StatelessWidget {
  const _MiniWeekDayRow({
    required this.day,
    required this.events,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekday = _CalendarMiniView._weekdays[day.weekday - 1];
    final muted = DdtTheme.textMuted(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                weekday,
                textAlign: TextAlign.center,
                style: DdtTheme.style(
                  fontSize: DdtTypography.microSize,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ),
            _MiniDayBadge(day: day, selected: selected, today: today),
            SizedBox(width: 8.w),
            Expanded(child: _EventStripes(events: events)),
          ],
        ),
      ),
    );
  }
}

class _MiniDayBadge extends StatelessWidget {
  const _MiniDayBadge({
    required this.day,
    required this.selected,
    required this.today,
  });

  final DateTime day;
  final bool selected;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? Colors.white
        : today
        ? AppColors.primary
        : DdtTheme.textPrimary(context);

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : null,
        shape: BoxShape.circle,
        border: today && !selected
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
      ),
      child: Text(
        '${day.day}',
        style: DdtTheme.style(
          fontSize: DdtTypography.labelSmallSize,
          fontWeight: selected || today ? FontWeight.w700 : FontWeight.w500,
          height: 1,
          color: textColor,
        ),
      ),
    );
  }
}

class _EventStripes extends StatelessWidget {
  const _EventStripes({required this.events});

  final List<CalendarEvent> events;

  static const _barHeight = 4.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        if (!maxHeight.isFinite || maxHeight < _barHeight) {
          return const SizedBox.shrink();
        }
        final maxBars = ((maxHeight + _gap) / (_barHeight + _gap)).floor();
        final count = maxBars.clamp(0, events.length);
        if (count == 0) return const SizedBox.shrink();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < count; index++) ...[
              if (index > 0) const SizedBox(height: _gap),
              Tooltip(
                message: events[index].subject,
                child: Container(
                  height: _barHeight,
                  decoration: BoxDecoration(
                    color: _stripeColor(events[index], isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final style = DdtTheme.style(
      fontSize: DdtTypography.microSize,
      fontWeight: FontWeight.w600,
      color: DdtTheme.textMuted(context),
    );
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(label, textAlign: TextAlign.center, style: style),
          ),
      ],
    );
  }
}

class _MiniDayCell extends StatefulWidget {
  const _MiniDayCell({
    required this.day,
    required this.onTap,
    this.today = false,
    this.dimmed = false,
  });

  final DateTime day;
  final VoidCallback onTap;
  final bool today;
  final bool dimmed;

  @override
  State<_MiniDayCell> createState() => _MiniDayCellState();
}

class _MiniDayCellState extends State<_MiniDayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = widget.today;
    final Color? fill = _hovered
        ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
        : null;
    final Color textColor = today
        ? AppColors.primary
        : widget.dimmed
        ? DdtTheme.textMuted(context)
        : DdtTheme.textPrimary(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 32,
          child: Center(
            child: AnimatedContainer(
              duration: DdtTheme.selectionAnimationDuration,
              curve: DdtTheme.selectionAnimationCurve,
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: today
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Text(
                '${widget.day.day}',
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  fontWeight: today ? FontWeight.w700 : FontWeight.w500,
                  height: 1,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMonthCell extends StatefulWidget {
  const _MiniMonthCell({
    required this.label,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  State<_MiniMonthCell> createState() => _MiniMonthCellState();
}

class _MiniMonthCellState extends State<_MiniMonthCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.selected;
    final Color? fill = selected
        ? AppColors.primary
        : _hovered
        ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
        : null;
    final textColor = selected
        ? Colors.white
        : widget.today
        ? AppColors.primary
        : DdtTheme.textPrimary(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          height: 36,
          margin: EdgeInsets.symmetric(horizontal: 3.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8.r),
            border: widget.today && !selected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          child: Text(
            widget.label,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: selected || widget.today
                  ? FontWeight.w700
                  : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarSources extends StatefulWidget {
  const _CalendarSources({required this.state});

  final CalendarState state;

  @override
  State<_CalendarSources> createState() => _CalendarSourcesState();
}

class _CalendarSourcesState extends State<_CalendarSources> {
  static const _ownSectionKey = 'own';
  static const _colleaguesSectionKey = 'colleagues';

  final Set<String> _expandedSections = {_ownSectionKey, _colleaguesSectionKey};
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CalendarSources oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.peopleQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  void _toggleSection(String key) {
    setState(() {
      if (!_expandedSections.add(key)) {
        _expandedSections.remove(key);
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      context.read<CalendarBloc>().add(CalendarPeopleSearchRequested(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExpandableSection(
          title: 'Мои календари',
          expanded: _expandedSections.contains(_ownSectionKey),
          onToggle: () => _toggleSection(_ownSectionKey),
          children: [
            _CalendarSourceRow(
              label: state.ownCalendarLabel,
              checked: state.ownCalendarEnabled,
              color: CalendarPalette.colorFor(0),
              onChanged: (enabled) => context.read<CalendarBloc>().add(
                CalendarOwnToggled(enabled: enabled),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _ExpandableSection(
          title: 'Календари коллег',
          expanded: _expandedSections.contains(_colleaguesSectionKey),
          onToggle: () => _toggleSection(_colleaguesSectionKey),
          children: [
            DdtAppInput(
              hint: 'Найти коллегу',
              controller: _searchController,
              variant: DdtInputVariant.compact,
              prefixIcon: DdtIcons.search,
              onChanged: _onSearchChanged,
              onSubmitted: (value) {
                _searchDebounce?.cancel();
                final needle = value.trim();
                if (needle.contains('@')) {
                  context.read<CalendarBloc>().add(
                    CalendarColleagueAdded(
                      email: needle,
                      displayName: needle,
                    ),
                  );
                  return;
                }
                context.read<CalendarBloc>().add(
                  CalendarPeopleSearchRequested(value),
                );
              },
            ),
            SizedBox(height: 6.h),
            if (state.isSearchingPeople)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              for (final person in state.peopleResults)
                _PersonResultRow(
                  name: person.displayName,
                  email: person.email,
                  onTap: () => context.read<CalendarBloc>().add(
                    CalendarColleagueAdded(
                      email: person.email,
                      displayName: person.displayName,
                    ),
                  ),
                ),
            if (state.colleagues.isEmpty && state.peopleResults.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(6.w, 4.h, 6.w, 8.h),
                child: Text(
                  'Добавьте коллегу, чтобы видеть его календарь рядом со своим.',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.captionSize,
                    color: DdtTheme.textMuted(context),
                  ),
                ),
              ),
            for (final calendar in state.colleagues)
              _CalendarSourceRow(
                label: calendar.displayName,
                checked: calendar.enabled,
                color: calendar.color,
                isLoading: calendar.isLoading,
                error: calendar.error,
                onChanged: calendar.isLoading
                    ? null
                    : (enabled) => context.read<CalendarBloc>().add(
                        CalendarColleagueToggled(
                          email: calendar.email,
                          enabled: enabled,
                        ),
                      ),
                onRemove: () => context.read<CalendarBloc>().add(
                  CalendarColleagueRemoved(calendar.email),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Row(
            children: [
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOutCubic,
                child: DdtIcon(
                  DdtIcons.chevronRight,
                  size: 11.sp,
                  color: DdtTheme.taskCardTextSecondary(context),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  title,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: FontWeight.w700,
                    color: DdtTheme.taskCardTextPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            reverseDuration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: expanded
                ? Column(
                    key: const ValueKey('expanded'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 6.h),
                      ...children,
                    ],
                  )
                : const SizedBox(key: ValueKey('collapsed'), height: 0),
          ),
        ),
      ],
    );
  }
}

class _CalendarSourceRow extends StatefulWidget {
  const _CalendarSourceRow({
    required this.label,
    required this.checked,
    required this.color,
    this.isLoading = false,
    this.error,
    this.onChanged,
    this.onRemove,
  });

  final String label;
  final bool checked;
  final Color color;
  final bool isLoading;
  final String? error;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onRemove;

  @override
  State<_CalendarSourceRow> createState() => _CalendarSourceRowState();
}

class _CalendarSourceRowState extends State<_CalendarSourceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = widget.color.withValues(
      alpha: widget.checked
          ? (isDark ? 0.28 : 0.16)
          : (isDark ? 0.14 : 0.08),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: 3.h),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: DdtTappable(
          onTap: enabled ? () => widget.onChanged!(!widget.checked) : null,
          enableHoverFill: enabled,
          backgroundColor: fill,
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h),
            child: Row(
              children: [
                IgnorePointer(
                  child: DdtCheckbox(
                    value: widget.checked,
                    enabled: enabled,
                    padding: EdgeInsets.zero,
                    onChanged: widget.onChanged,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DdtTheme.style(
                          fontSize: DdtTypography.labelSize,
                          fontWeight: widget.checked
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: DdtTheme.taskCardTextPrimary(context),
                        ),
                      ),
                      if (widget.error != null && widget.error!.isNotEmpty)
                        Text(
                          widget.error!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DdtTheme.style(
                            fontSize: DdtTypography.microSize,
                            color: DdtTheme.textMuted(context),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (widget.onRemove != null && _hovered)
                  Tooltip(
                    message: 'Убрать',
                    child: GestureDetector(
                      onTap: widget.onRemove,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.only(left: 6.w),
                        child: DdtIcon(
                          DdtIcons.close,
                          size: 11.sp,
                          color: DdtTheme.textMuted(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonResultRow extends StatelessWidget {
  const _PersonResultRow({
    required this.name,
    required this.email,
    required this.onTap,
  });

  final String name;
  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 3.h),
      child: DdtTappable(
        onTap: onTap,
        enableHoverFill: true,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
          child: Row(
            children: [
              DdtIcon(
                DdtIcons.user,
                size: 12.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSize,
                        fontWeight: FontWeight.w600,
                        color: DdtTheme.taskCardTextPrimary(context),
                      ),
                    ),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.microSize,
                        color: DdtTheme.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              DdtIcon(
                DdtIcons.add,
                size: 11.sp,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isToday(DateTime day) => _sameDay(day, DateTime.now());

bool _eventCoversDay(CalendarEvent event, DateTime day) {
  final start = event.start?.toLocal();
  if (start == null) return false;
  final end = event.end?.toLocal() ?? start;
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return start.isBefore(dayEnd) && end.isAfter(dayStart);
}

Color _stripeColor(CalendarEvent event, bool isDark) {
  if (event.isDeclined) {
    return (isDark ? Colors.white : Colors.black).withValues(alpha: 0.28);
  }
  final alpha = event.needsResponse
      ? 1.0
      : isDark
      ? 0.72
      : 0.55;
  return CalendarPalette.colorFor(event.colorIndex).withValues(alpha: alpha);
}
