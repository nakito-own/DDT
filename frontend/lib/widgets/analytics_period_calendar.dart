import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_context_menu.dart';
import '../widgets/ddt_icon.dart';

Future<void> showAnalyticsPeriodCalendar({
  required BuildContext context,
  required BuildContext anchorContext,
  DateTime? start,
  DateTime? end,
  required DateTime firstDate,
  required DateTime lastDate,
  required void Function(DateTime? start, DateTime? end) onApply,
}) {
  return showDdtContextPanel(
    context: context,
    anchorContext: anchorContext,
    placement: DdtContextMenuPlacement.belowStart,
    childBuilder: (dismiss) {
      return AnalyticsPeriodCalendar(
        start: start,
        end: end,
        firstDate: firstDate,
        lastDate: lastDate,
        onApply: (nextStart, nextEnd) async {
          onApply(nextStart, nextEnd);
          await dismiss();
        },
      );
    },
  );
}

class AnalyticsPeriodCalendar extends StatefulWidget {
  const AnalyticsPeriodCalendar({
    super.key,
    required this.firstDate,
    required this.lastDate,
    required this.onApply,
    this.start,
    this.end,
  });

  final DateTime? start;
  final DateTime? end;
  final DateTime firstDate;
  final DateTime lastDate;
  final Future<void> Function(DateTime? start, DateTime? end) onApply;

  @override
  State<AnalyticsPeriodCalendar> createState() =>
      _AnalyticsPeriodCalendarState();
}

class _AnalyticsPeriodCalendarState extends State<AnalyticsPeriodCalendar> {
  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;

  static const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  static const _monthNames = [
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

  @override
  void initState() {
    super.initState();
    _start = widget.start == null ? null : _dateOnly(widget.start!);
    _end = widget.end == null ? null : _dateOnly(widget.end!);
    _visibleMonth = DateTime(
      (_start ?? widget.lastDate).year,
      (_start ?? widget.lastDate).month,
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _select(DateTime day) {
    final value = _dateOnly(day);
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = value;
        _end = null;
        return;
      }
      if (value.isBefore(_start!)) {
        _end = _start;
        _start = value;
        return;
      }
      _end = value;
    });
  }

  void _selectPreset(_PeriodPreset preset) {
    final today = _dateOnly(DateTime.now());
    final start = switch (preset) {
      _PeriodPreset.week => today.subtract(const Duration(days: 6)),
      _PeriodPreset.month => _shiftMonths(today, -1),
      _PeriodPreset.year => _shiftMonths(today, -12),
    };
    setState(() {
      _start = start;
      _end = today;
      _visibleMonth = DateTime(today.year, today.month);
    });
  }

  DateTime _shiftMonths(DateTime value, int months) {
    final total = value.year * 12 + (value.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = value.day > lastDay ? lastDay : value.day;
    return DateTime(year, month, day);
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _inRange(DateTime day) {
    if (_start == null) return false;
    final end = _end ?? _start!;
    return !day.isBefore(_start!) && !day.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}';
    return DdtTheme.contextMenuGlass(
      context: context,
      padding: EdgeInsets.all(12.w),
      child: SizedBox(
        width: 312.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    );
                  }),
                  icon: DdtIcon(DdtIcons.chevronLeft, size: 16.sp),
                ),
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.bodySize,
                      fontWeight: FontWeight.w700,
                      color: DdtTheme.textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    );
                  }),
                  icon: DdtIcon(DdtIcons.chevronRight, size: 16.sp),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                for (final preset in _PeriodPreset.values) ...[
                  if (preset != _PeriodPreset.week) SizedBox(width: 6.w),
                  Expanded(
                    child: _PresetButton(
                      label: preset.label,
                      onTap: () => _selectPreset(preset),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                for (final weekday in _weekdays)
                  Expanded(
                    child: Text(
                      weekday,
                      textAlign: TextAlign.center,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.microSize,
                        color: DdtTheme.textMuted(context),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 6.h),
            ..._monthWeeks().map((week) {
              final span =
                  _start != null && _end != null && !_sameDay(_start, _end);
              return Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: Row(
                  children: [
                    for (var index = 0; index < week.length; index++)
                      Expanded(
                        child: week[index] == null
                            ? const SizedBox(height: 32)
                            : _DayCell(
                                day: week[index]!,
                                isStart: _sameDay(week[index], _start),
                                isEnd: _sameDay(week[index], _end ?? _start),
                                showRange: span && _inRange(week[index]!),
                                continuesLeft:
                                    span &&
                                    index > 0 &&
                                    week[index - 1] != null &&
                                    _inRange(week[index - 1]!) &&
                                    _inRange(week[index]!),
                                continuesRight:
                                    span &&
                                    index < week.length - 1 &&
                                    week[index + 1] != null &&
                                    _inRange(week[index]!) &&
                                    _inRange(week[index + 1]!),
                                onTap: () => _select(week[index]!),
                              ),
                      ),
                  ],
                ),
              );
            }),
            SizedBox(height: 8.h),
            Row(
              children: [
                TextButton(
                  onPressed: () => widget.onApply(null, null),
                  child: Text(
                    'Сбросить',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSmallSize,
                      color: DdtTheme.textMuted(context),
                    ),
                  ),
                ),
                const Spacer(),
                Button(
                  text: 'Применить',
                  onPressed: () => widget.onApply(_start, _end ?? _start),
                  borderRadius: DdtTheme.radius,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<List<DateTime?>> _monthWeeks() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final startOffset = (first.weekday + 6) % 7;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(startOffset, null),
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_visibleMonth.year, _visibleMonth.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [
      for (var index = 0; index < cells.length; index += 7)
        cells.sublist(index, index + 7),
    ];
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.day,
    required this.isStart,
    required this.isEnd,
    required this.showRange,
    required this.continuesLeft,
    required this.continuesRight,
    required this.onTap,
  });

  final DateTime day;
  final bool isStart;
  final bool isEnd;
  final bool showRange;
  final bool continuesLeft;
  final bool continuesRight;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    final edge = widget.isStart || widget.isEnd;
    final fill = DdtTheme.primaryColor.withValues(alpha: isDark ? 0.28 : 0.14);
    final textColor = edge
        ? Colors.white
        : _hovered && !widget.showRange
        ? accent
        : DdtTheme.textPrimary(context);
    const radius = Radius.circular(8);
    final background = edge
        ? DdtTheme.primaryColor
        : widget.showRange
        ? fill
        : _hovered
        ? DdtTheme.primaryColor.withValues(alpha: isDark ? 0.16 : 0.10)
        : Colors.transparent;

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
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.horizontal(
              left: widget.continuesLeft ? Radius.zero : radius,
              right: widget.continuesRight ? Radius.zero : radius,
            ),
          ),
          child: Text(
            '${widget.day.day}',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

enum _PeriodPreset { week, month, year }

extension on _PeriodPreset {
  String get label => switch (this) {
    _PeriodPreset.week => 'Неделя',
    _PeriodPreset.month => 'Месяц',
    _PeriodPreset.year => 'Год',
  };
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: DdtTheme.primaryColor.withValues(
              alpha: isDark ? 0.16 : 0.08,
            ),
          ),
          child: Text(
            label,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: FontWeight.w600,
              color: isDark ? DdtTheme.accentColor : DdtTheme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
