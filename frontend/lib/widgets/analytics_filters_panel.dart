import 'dart:async';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../theme/ddt_icons.dart';

import '../models/analytics_dashboard.dart';
import '../models/analytics_filters.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'analytics_charts.dart';
import 'analytics_period_calendar.dart';
import 'ddt_app_input.dart';
import 'ddt_filter_dropdown.dart';
import 'ddt_tappable.dart';
import 'ddt_section_sidebar.dart';

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
    this.onQueryChanged,
    this.loading = false,
  });

  final List<AnalyticsColumn> columns;
  final String dateColumn;
  final Map<String, AnalyticsDateBounds> dateBounds;
  final AnalyticsFilters filters;
  final ValueChanged<String> onDateColumnChanged;
  final void Function(DateTime? start, DateTime? end) onPeriodChanged;
  final void Function(String columnKey, String valueKey) onValueToggled;
  final void Function(String columnKey, String query)? onQueryChanged;
  final VoidCallback onCleared;
  final bool loading;

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

    if (loading) {
      return DdtSectionSidebarPane(
        pinned: const DdtSectionSidebarTitle(),
        children: [
          const DdtSectionSidebarField(
            label: 'Тип фильтрации по дате',
            gapAbove: false,
            child: AnalyticsSkeletonFill(height: 44),
          ),
          const DdtSectionSidebarField(
            label: 'Период',
            child: AnalyticsSkeletonFill(height: 44),
          ),
          SizedBox(height: DdtSectionSidebar.fieldGap),
          const DdtFilterLabel('Колонки таблицы'),
          SizedBox(height: DdtSectionSidebar.labelGap),
          for (var index = 0; index < 6; index++)
            Padding(
              padding: EdgeInsets.only(bottom: DdtSectionSidebar.fieldGap),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnalyticsSkeletonFill(height: 12, width: 96),
                  SizedBox(height: 8),
                  AnalyticsSkeletonFill(height: 44),
                ],
              ),
            ),
        ],
      );
    }

    return DdtSectionSidebarPane(
      pinned: DdtSectionSidebarTitle(
        trailing: AnimatedSwitcher(
          duration: DdtTheme.selectionAnimationDuration,
          switchInCurve: DdtTheme.selectionAnimationCurve,
          switchOutCurve: DdtTheme.selectionAnimationCurve,
          child: filters.hasPeriod || filters.hasColumnFilters
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
      ),
      children: [
          DdtSectionSidebarField(
            label: 'Тип фильтрации по дате',
            gapAbove: false,
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
                    DdtSectionSidebarField(
                      label: 'Период',
                      child: Builder(
                        builder: (anchorContext) {
                          return DdtFilterDropdownAnchor(
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
                          );
                        },
                      ),
                    ),
                    if (computedColumns.isNotEmpty) ...[
                      SizedBox(height: DdtSectionSidebar.fieldGap),
                      const DdtFilterLabel('Вычисляемые поля'),
                      SizedBox(height: DdtSectionSidebar.labelGap),
                      for (final column in computedColumns)
                        _columnFilter(context, column),
                    ],
                    SizedBox(height: DdtSectionSidebar.fieldGap),
                    const DdtFilterLabel('Колонки таблицы'),
                    SizedBox(height: DdtSectionSidebar.labelGap),
                    for (final column in sheetColumns)
                      _columnFilter(context, column),
      ],
    );
  }

  Widget _columnFilter(BuildContext context, AnalyticsColumn column) {
    if (column.options.isEmpty && onQueryChanged != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: DdtSectionSidebar.fieldGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DdtFilterLabel(column.label),
            SizedBox(height: DdtSectionSidebar.labelGap),
            _ColumnQueryField(
              value: filters.queries[column.key] ?? '',
              onChanged: (query) => onQueryChanged!(column.key, query),
            ),
          ],
        ),
      );
    }
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
      padding: EdgeInsets.only(bottom: DdtSectionSidebar.fieldGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DdtFilterLabel(column.label),
          SizedBox(height: DdtSectionSidebar.labelGap),
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

class _ColumnQueryField extends StatefulWidget {
  const _ColumnQueryField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_ColumnQueryField> createState() => _ColumnQueryFieldState();
}

class _ColumnQueryFieldState extends State<_ColumnQueryField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _ColumnQueryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DdtAppInput(
      controller: _controller,
      hint: 'Поиск',
      variant: DdtInputVariant.compact,
      onChanged: (value) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 400), () {
          widget.onChanged(value);
        });
      },
      onSubmitted: widget.onChanged,
    );
  }
}
