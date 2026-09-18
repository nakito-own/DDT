import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../theme/ddt_icons.dart';

import '../models/analytics_dashboard.dart';
import '../models/analytics_filters.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'analytics_period_calendar.dart';
import 'ddt_filter_dropdown.dart';
import 'ddt_tappable.dart';
import '../widgets/ddt_icon.dart';

const _kAnalyticsFiltersFadeHeight = 22.0;

class AnalyticsFiltersPanel extends StatelessWidget {
  const AnalyticsFiltersPanel({
    super.key,
    required this.columns,
    required this.filters,
    required this.tickets,
    required this.onDateColumnChanged,
    required this.onPeriodChanged,
    required this.onValueToggled,
    required this.onCleared,
  });

  final List<AnalyticsColumn> columns;
  final AnalyticsFilters filters;
  final List<AnalyticsTicket> tickets;
  final ValueChanged<String> onDateColumnChanged;
  final void Function(DateTime? start, DateTime? end) onPeriodChanged;
  final void Function(String columnKey, String valueKey) onValueToggled;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final dateColumns = columns
        .where((column) => column.isDate && !column.isFilterIgnored)
        .toList();
    final otherColumns = columns
        .where((column) => !column.isDate && !column.isFilterIgnored)
        .toList();
    final selectedDateKey = filters.resolvedDateColumn(columns);
    final dateFormat = DateFormat('dd.MM.yyyy');
    String? selectedDateLabel;
    for (final column in dateColumns) {
      if (column.key == selectedDateKey) {
        selectedDateLabel = column.label;
        break;
      }
    }

    final panelBackground = Theme.of(context).scaffoldBackgroundColor;

    return ColoredBox(
      color: panelBackground,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 2.h, 12.w, 4.h),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: ClipRect(
                child: ListView(
                  clipBehavior: Clip.hardEdge,
                  padding: EdgeInsets.only(
                    top: _AnalyticsFiltersHeader.scrollTopInset(context),
                    bottom: _AnalyticsFiltersScrollFade.scrollBottomInset(
                      context,
                    ),
                    left: 8.w,
                    right: 8.w,
                  ),
                  children: [
                  SizedBox(height: 4.h),
                  DdtFilterLabel('Тип фильтрации по дате'),
                  SizedBox(height: 4.h),
                  DdtFilterDropdownHoverSlot(
                    child: DdtSearchableFilterDropdown(
                    summary: selectedDateLabel ?? 'Выбрать колонку',
                    active: selectedDateKey.isNotEmpty,
                    options: [
                      for (final column in dateColumns)
                        DdtFilterOption(
                          key: column.key,
                          label: column.label,
                        ),
                    ],
                    selected: {
                      if (selectedDateKey.isNotEmpty) selectedDateKey,
                    },
                    multi: false,
                    emptyLabel: 'Нет колонок с датами',
                    onSelected: onDateColumnChanged,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  DdtFilterLabel('Период'),
                  SizedBox(height: 4.h),
                  Builder(
                    builder: (anchorContext) {
                      return DdtFilterDropdownHoverSlot(
                        child: DdtFilterDropdownAnchor(
                        label: filters.periodStart == null
                            ? 'Выбрать период'
                            : filters.periodEnd == null ||
                                  _sameDay(
                                    filters.periodStart!,
                                    filters.periodEnd!,
                                  )
                            ? dateFormat.format(filters.periodStart!)
                            : '${dateFormat.format(filters.periodStart!)} — ${dateFormat.format(filters.periodEnd!)}',
                        active: filters.hasPeriod,
                        icon: DdtIcons.calendar,
                        onTap: () {
                          final bounds = _dateBounds(
                            tickets,
                            selectedDateKey,
                          );
                          showAnalyticsPeriodCalendar(
                            context: context,
                            anchorContext: anchorContext,
                            start: filters.periodStart,
                            end: filters.periodEnd,
                            firstDate: bounds.$1,
                            lastDate: bounds.$2,
                            onApply: onPeriodChanged,
                          );
                        },
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12.h),
                  DdtFilterLabel('Колонки таблицы'),
                  SizedBox(height: 4.h),
                  for (final column in otherColumns) ...[
                    Text(
                      column.label,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSize,
                        fontWeight: FontWeight.w700,
                        color: DdtTheme.textSecondary(context),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    DdtFilterDropdownHoverSlot(
                      child: DdtSearchableFilterDropdown(
                        summary: ddtFilterSelectionSummary(
                          filters.selectedValues[column.key] ?? const {},
                          _optionsFor(column, tickets),
                        ),
                        active:
                            (filters.selectedValues[column.key] ?? const {})
                                .isNotEmpty,
                        options: _optionsFor(column, tickets),
                        selected:
                            filters.selectedValues[column.key] ?? const {},
                        onSelected: (value) =>
                            onValueToggled(column.key, value),
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _AnalyticsFiltersHeader(
                backgroundColor: panelBackground,
                showReset: filters.hasPeriod || filters.hasColumnFilters,
                onCleared: onCleared,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _AnalyticsFiltersScrollFade(
                backgroundColor: panelBackground,
                atTop: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DdtFilterOption> _optionsFor(
    AnalyticsColumn column,
    List<AnalyticsTicket> tickets,
  ) {
    if (column.options.isNotEmpty) {
      return [
        for (final option in column.options)
          DdtFilterOption(
            key: option.key,
            label: option.label,
            count: option.count,
          ),
      ];
    }

    final counts = <String, int>{};
    var empty = 0;
    for (final ticket in tickets) {
      final value = ticket.fieldValue(column.key).trim();
      if (value.isEmpty) {
        empty += 1;
        continue;
      }
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return [
      for (final entry in entries)
        DdtFilterOption(key: entry.key, label: entry.key, count: entry.value),
      if (empty > 0)
        DdtFilterOption(key: '', label: 'Пусто', count: empty),
    ];
  }

  (DateTime, DateTime) _dateBounds(List<AnalyticsTicket> tickets, String key) {
    DateTime? min;
    DateTime? max;
    for (final ticket in tickets) {
      final date = ticket.dateValue(key);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (min == null || day.isBefore(min)) min = day;
      if (max == null || day.isAfter(max)) max = day;
    }
    final now = DateTime.now();
    return (
      min ?? DateTime(now.year - 1),
      max ?? DateTime(now.year, now.month, now.day),
    );
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

/// Title row plus a downward fade so scrolled filters dissolve under the header.
class _AnalyticsFiltersHeader extends StatelessWidget {
  const _AnalyticsFiltersHeader({
    required this.backgroundColor,
    required this.showReset,
    required this.onCleared,
  });

  final Color backgroundColor;
  final bool showReset;
  final VoidCallback onCleared;

  static double scrollTopInset(BuildContext context) {
    final titleLine = DdtTypography.sectionTitleSize.sp + 8.h;
    return titleLine + _kAnalyticsFiltersFadeHeight.h + 4.h;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: backgroundColor,
          child: Row(
            children: [
              DdtIcon(
                DdtIcons.sliders,
                size: 18.sp,
                color: AppColors.primary.withValues(alpha: 0.9),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Фильтры',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.sectionTitleSize,
                    fontWeight: FontWeight.w800,
                    color: DdtTheme.textPrimary(context),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: DdtTheme.selectionAnimationDuration,
                switchInCurve: DdtTheme.selectionAnimationCurve,
                switchOutCurve: DdtTheme.selectionAnimationCurve,
                child: showReset
                    ? DdtTappable(
                        key: const ValueKey('reset'),
                        onTap: onCleared,
                        enableHoverFill: true,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        child: Text(
                          'Сбросить',
                          style: DdtTheme.style(
                            fontSize: DdtTypography.labelSmallSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('reset-hidden')),
              ),
            ],
          ),
        ),
        _AnalyticsFiltersScrollFade(
          backgroundColor: backgroundColor,
          atTop: true,
        ),
      ],
    );
  }
}

class _AnalyticsFiltersScrollFade extends StatelessWidget {
  const _AnalyticsFiltersScrollFade({
    required this.backgroundColor,
    required this.atTop,
  });

  final Color backgroundColor;
  final bool atTop;

  static double scrollBottomInset(BuildContext context) {
    return _kAnalyticsFiltersFadeHeight.h + 4.h;
  }

  @override
  Widget build(BuildContext context) {
    final transparent = backgroundColor.withValues(alpha: 0);

    return IgnorePointer(
      child: SizedBox(
        height: _kAnalyticsFiltersFadeHeight.h,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: atTop
                  ? [backgroundColor, transparent]
                  : [transparent, backgroundColor],
            ),
          ),
        ),
      ),
    );
  }
}
