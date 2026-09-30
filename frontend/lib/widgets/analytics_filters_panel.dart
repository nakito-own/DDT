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
import 'ddt_scroll_edge_fade.dart';

const _kAnalyticsFiltersFadeHeight = kDdtScrollEdgeFadeHeightCompact;
const _kAnalyticsFiltersSolidTail = 8.0;
const _kAnalyticsFiltersListGap = 4.0;

/// Single source of truth for sticky header height vs [ListView] top padding.
abstract final class _AnalyticsFiltersHeaderMetrics {
  static double titleRowHeight(BuildContext context) {
    return DdtTypography.sectionTitleSize.sp + 8.h;
  }

  static double topOverlayHeight(BuildContext context) {
    return titleRowHeight(context) +
        _kAnalyticsFiltersSolidTail.h +
        _kAnalyticsFiltersFadeHeight.h;
  }

  static double listTopPadding(BuildContext context) {
    return topOverlayHeight(context) + _kAnalyticsFiltersListGap.h;
  }

  static double listBottomPadding(BuildContext context) {
    return _kAnalyticsFiltersFadeHeight.h + _kAnalyticsFiltersListGap.h;
  }
}

class AnalyticsFiltersPanel extends StatelessWidget {
  const AnalyticsFiltersPanel({
    super.key,
    required this.columns,
    required this.dateColumn,
    required this.dateBounds,
    required this.filters,
    required this.onDateColumnChanged,
    required this.onPeriodChanged,
    required this.onValueToggled,
    required this.onCleared,
  });

  final List<AnalyticsColumn> columns;
  final String dateColumn;
  final Map<String, AnalyticsDateBounds> dateBounds;
  final AnalyticsFilters filters;
  final ValueChanged<String> onDateColumnChanged;
  final void Function(DateTime? start, DateTime? end) onPeriodChanged;
  final void Function(String columnKey, String valueKey) onValueToggled;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final dateColumns = columns.where((column) => column.isDate).toList();
    final sheetColumns = columns
        .where((column) => !column.isDate && !column.computed)
        .toList();
    final computedColumns = columns
        .where((column) => !column.isDate && column.computed)
        .toList();
    final selectedDateKey = filters.dateColumnKey ?? dateColumn;
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
                    top: _AnalyticsFiltersHeaderMetrics.listTopPadding(context),
                    bottom: _AnalyticsFiltersHeaderMetrics.listBottomPadding(
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
                              final bounds = _dateBounds(selectedDateKey);
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
                    if (computedColumns.isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      DdtFilterLabel('Вычисляемые поля'),
                      SizedBox(height: 4.h),
                      for (final column in computedColumns)
                        _columnFilter(context, column),
                    ],
                    SizedBox(height: 12.h),
                    DdtFilterLabel('Колонки таблицы'),
                    SizedBox(height: 4.h),
                    for (final column in sheetColumns)
                      _columnFilter(context, column),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: _AnalyticsFiltersHeader(
                  backgroundColor: panelBackground,
                  showReset: filters.hasPeriod || filters.hasColumnFilters,
                  onCleared: onCleared,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DdtScrollEdgeFadeGradient(
                backgroundColor: panelBackground,
                atTop: false,
                fadeHeight: _kAnalyticsFiltersFadeHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _columnFilter(BuildContext context, AnalyticsColumn column) {
    final options = [
      for (final option in column.options)
        DdtFilterOption(
          key: option.key,
          label: option.label,
          count: option.count,
        ),
    ];
    final selected = filters.selectedValues[column.key] ?? const <String>{};
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              summary: ddtFilterSelectionSummary(selected, options),
              active: selected.isNotEmpty,
              options: options,
              selected: selected,
              onSelected: (value) => onValueToggled(column.key, value),
            ),
          ),
        ],
      ),
    );
  }

  (DateTime, DateTime) _dateBounds(String key) {
    final bounds = dateBounds[key];
    if (bounds != null) return (bounds.min, bounds.max);
    final now = DateTime.now();
    return (DateTime(now.year - 1), DateTime(now.year, now.month, now.day));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: backgroundColor,
          child: SizedBox(
            height: _AnalyticsFiltersHeaderMetrics.titleRowHeight(context),
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
        ),
        ColoredBox(
          color: backgroundColor,
          child: SizedBox(height: _kAnalyticsFiltersSolidTail.h),
        ),
        DdtScrollEdgeFadeGradient(
          backgroundColor: backgroundColor,
          atTop: true,
          fadeHeight: _kAnalyticsFiltersFadeHeight,
        ),
      ],
    );
  }
}
