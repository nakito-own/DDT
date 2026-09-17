import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_context_menu.dart';

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
                  icon: Icon(CupertinoIcons.chevron_left, size: 16.sp),
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
                  icon: Icon(CupertinoIcons.chevron_right, size: 16.sp),
                ),
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
            ..._monthWeeks().map(
              (week) => Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Row(
                  children: [
                    for (final day in week)
                      Expanded(
                        child: day == null
                            ? const SizedBox(height: 32)
                            : _DayCell(
                                day: day,
                                selected: _inRange(day),
                                isEdge:
                                    _dateOnly(day) == _start ||
                                    _dateOnly(day) == _end,
                                onTap: () => _select(day),
                              ),
                      ),
                  ],
                ),
              ),
            ),
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
    required this.selected,
    required this.isEdge,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isEdge;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final selected = widget.selected;
    final isEdge = widget.isEdge;
    final color = isEdge
        ? AppColors.primary
        : selected
        ? AppColors.primary.withValues(alpha: 0.18)
        : _hovered
        ? AppColors.primary.withValues(alpha: 0.10)
        : Colors.transparent;
    final textColor = isEdge
        ? Colors.white
        : selected || _hovered
        ? AppColors.primary
        : DdtTheme.textPrimary(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          height: 32,
          alignment: Alignment.center,
          transform: Matrix4.translationValues(
            0,
            _hovered && !isEdge ? -1 : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isEdge ? 99 : 8),
            boxShadow: isEdge || _hovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: isEdge ? 0.28 : 0.12,
                      ),
                      blurRadius: isEdge ? 8 : 6,
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: DdtTheme.selectionAnimationDuration,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            child: Text('${day.day}'),
          ),
        ),
      ),
    );
  }
}
