import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../models/analytics_dashboard.dart';
import '../models/analytics_filters.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'analytics_period_calendar.dart';
import 'ddt_app_input.dart';
import 'ddt_checkbox.dart';
import 'ddt_context_menu.dart';
import 'ddt_tappable.dart';

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

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4.w, 4.h, 12.w, 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.slider_horizontal_3,
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
                  child: filters.hasPeriod || filters.hasColumnFilters
                      ? DdtTappable(
                          key: const ValueKey('reset'),
                          onTap: onCleared,
                          enableHoverFill: true,
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
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
            Expanded(
              child: ListView(
                children: [
                  SizedBox(height: 8.h),
                  _FilterLabel('Тип фильтрации по дате'),
                  SizedBox(height: 6.h),
                  _SearchableDropdown(
                    summary: selectedDateLabel ?? 'Выбрать колонку',
                    active: selectedDateKey.isNotEmpty,
                    options: [
                      for (final column in dateColumns)
                        _FilterOption(
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
                  SizedBox(height: 16.h),
                  _FilterLabel('Период'),
                  SizedBox(height: 6.h),
                  Builder(
                    builder: (anchorContext) {
                      return _DropdownAnchor(
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
                        icon: CupertinoIcons.calendar,
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
                      );
                    },
                  ),
                  SizedBox(height: 20.h),
                  _FilterLabel('Колонки таблицы'),
                  SizedBox(height: 8.h),
                  for (final column in otherColumns) ...[
                    Text(
                      column.label,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.labelSize,
                        fontWeight: FontWeight.w700,
                        color: DdtTheme.textSecondary(context),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    _SearchableDropdown(
                      summary: _selectionSummary(
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
                    SizedBox(height: 12.h),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_FilterOption> _optionsFor(
    AnalyticsColumn column,
    List<AnalyticsTicket> tickets,
  ) {
    if (column.options.isNotEmpty) {
      return [
        for (final option in column.options)
          _FilterOption(
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
        _FilterOption(key: entry.key, label: entry.key, count: entry.value),
      if (empty > 0)
        _FilterOption(key: '', label: 'Пусто', count: empty),
    ];
  }

  String _selectionSummary(
    Set<String> selected,
    List<_FilterOption> options,
  ) {
    if (selected.isEmpty) return 'Все значения';
    final labels = [
      for (final option in options)
        if (selected.contains(option.key)) option.label,
    ];
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]}, ${labels[1]}';
    return 'Выбрано: ${labels.length}';
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

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: DdtTheme.style(
        fontSize: DdtTypography.labelSmallSize,
        fontWeight: FontWeight.w700,
        color: DdtTheme.textMuted(context),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption({
    required this.key,
    required this.label,
    this.count,
  });

  final String key;
  final String label;
  final int? count;
}

class _SearchableDropdown extends StatelessWidget {
  const _SearchableDropdown({
    required this.summary,
    required this.active,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.multi = true,
    this.emptyLabel = 'Нет значений',
  });

  final String summary;
  final bool active;
  final List<_FilterOption> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final bool multi;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchorContext) {
        return _DropdownAnchor(
          label: summary,
          active: active,
          badge: multi ? selected.length : 0,
          onTap: () => showDdtContextPanel(
            context: context,
            anchorContext: anchorContext,
            placement: DdtContextMenuPlacement.belowStart,
            childBuilder: (_) => _SearchableMenu(
              options: options,
              selected: selected,
              multi: multi,
              emptyLabel: emptyLabel,
              onSelected: onSelected,
            ),
          ),
        );
      },
    );
  }
}

class _DropdownAnchor extends StatefulWidget {
  const _DropdownAnchor({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.badge = 0,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final int badge;

  @override
  State<_DropdownAnchor> createState() => _DropdownAnchorState();
}

class _DropdownAnchorState extends State<_DropdownAnchor> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlighted = widget.active || _hovered;
    final fill = widget.active
        ? AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.10)
        : _hovered
        ? DdtTheme.inputFillColorHover(context)
        : DdtTheme.inputFillColor(context);
    final border = widget.active
        ? AppColors.primary.withValues(alpha: _hovered ? 0.62 : 0.42)
        : DdtTheme.inputBorderColor(context).withValues(
            alpha: _hovered ? 0.55 : 0.32,
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hovered ? 1.015 : 1,
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              borderRadius: DdtTheme.radius,
              border: Border.all(color: border),
              color: fill,
              boxShadow: highlighted
                  ? DdtTheme.inputFocusShadow(context)
                  : const [],
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  AnimatedScale(
                    scale: _hovered ? 1.08 : 1,
                    duration: DdtTheme.selectionAnimationDuration,
                    curve: DdtTheme.selectionAnimationCurve,
                    child: Icon(
                      widget.icon,
                      size: 16.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: DdtTheme.selectionAnimationDuration,
                    curve: DdtTheme.selectionAnimationCurve,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSize,
                      fontWeight: widget.active
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: DdtTheme.textPrimary(context),
                    ),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: DdtTheme.selectionAnimationDuration,
                  switchInCurve: DdtTheme.selectionAnimationCurve,
                  child: widget.active && widget.badge > 0
                      ? Container(
                          key: ValueKey(widget.badge),
                          margin: EdgeInsets.only(right: 8.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 7.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${widget.badge}',
                            style: DdtTheme.style(
                              fontSize: DdtTypography.microSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no-badge')),
                ),
                AnimatedRotation(
                  turns: _hovered ? 0.5 : 0,
                  duration: DdtTheme.selectionAnimationDuration,
                  curve: DdtTheme.selectionAnimationCurve,
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    size: 14.sp,
                    color: highlighted
                        ? AppColors.primary
                        : DdtTheme.textMuted(context),
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

class _SearchableMenu extends StatefulWidget {
  const _SearchableMenu({
    required this.options,
    required this.selected,
    required this.multi,
    required this.emptyLabel,
    required this.onSelected,
  });

  final List<_FilterOption> options;
  final Set<String> selected;
  final bool multi;
  final String emptyLabel;
  final ValueChanged<String> onSelected;

  @override
  State<_SearchableMenu> createState() => _SearchableMenuState();
}

class _SearchableMenuState extends State<_SearchableMenu> {
  late final Set<String> _selected = {...widget.selected};
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<_FilterOption> get _visible {
    final needle = _query.text.trim().toLowerCase();
    if (needle.isEmpty) return widget.options;
    return [
      for (final option in widget.options)
        if (option.label.toLowerCase().contains(needle) ||
            option.key.toLowerCase().contains(needle))
          option,
    ];
  }

  void _select(String key) {
    if (widget.multi) {
      setState(() {
        if (!_selected.add(key)) {
          _selected.remove(key);
        }
      });
    } else {
      setState(() {
        _selected
          ..clear()
          ..add(key);
      });
    }
    widget.onSelected(key);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return DdtTheme.contextMenuGlass(
      context: context,
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 6.h),
      child: SizedBox(
        width: 280.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DdtAppInput(
              hint: 'Поиск',
              controller: _query,
              variant: DdtInputVariant.compact,
              prefixIcon: CupertinoIcons.search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 6.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 260.h),
              child: AnimatedSwitcher(
                duration: DdtTheme.selectionAnimationDuration,
                switchInCurve: DdtTheme.selectionAnimationCurve,
                switchOutCurve: DdtTheme.selectionAnimationCurve,
                child: widget.options.isEmpty
                    ? _MenuPlaceholder(
                        key: const ValueKey('empty'),
                        text: widget.emptyLabel,
                      )
                    : visible.isEmpty
                    ? const _MenuPlaceholder(
                        key: ValueKey('none'),
                        text: 'Ничего не найдено',
                      )
                    : ListView.builder(
                        key: ValueKey('list-${visible.length}'),
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final option = visible[index];
                          return _HoverOptionRow(
                            option: option,
                            checked: _selected.contains(option.key),
                            multi: widget.multi,
                            onTap: () => _select(option.key),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuPlaceholder extends StatelessWidget {
  const _MenuPlaceholder({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 16.h),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: DdtTheme.style(
          fontSize: DdtTypography.captionSize,
          color: DdtTheme.textMuted(context),
        ),
      ),
    );
  }
}

class _HoverOptionRow extends StatefulWidget {
  const _HoverOptionRow({
    required this.option,
    required this.checked,
    required this.multi,
    required this.onTap,
  });

  final _FilterOption option;
  final bool checked;
  final bool multi;
  final VoidCallback onTap;

  @override
  State<_HoverOptionRow> createState() => _HoverOptionRowState();
}

class _HoverOptionRowState extends State<_HoverOptionRow> {
  bool _hovered = false;

  Color _background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.checked) {
      return AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10);
    }
    if (_hovered) {
      return AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07);
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _background(context),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: widget.checked
                    ? AppColors.primary.withValues(alpha: 0.28)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                if (widget.multi)
                  IgnorePointer(
                    child: DdtCheckbox(
                      value: widget.checked,
                      padding: EdgeInsets.zero,
                      onChanged: (_) {},
                    ),
                  )
                else
                  AnimatedScale(
                    scale: widget.checked || _hovered ? 1.08 : 1,
                    duration: DdtTheme.selectionAnimationDuration,
                    curve: DdtTheme.selectionAnimationCurve,
                    child: Icon(
                      widget.checked
                          ? CupertinoIcons.smallcircle_fill_circle
                          : CupertinoIcons.circle,
                      size: 16.sp,
                      color: widget.checked || _hovered
                          ? AppColors.primary
                          : DdtTheme.textMuted(context),
                    ),
                  ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    widget.option.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSize,
                      fontWeight: widget.checked
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: DdtTheme.textPrimary(context),
                    ),
                  ),
                ),
                if (widget.option.count != null)
                  AnimatedDefaultTextStyle(
                    duration: DdtTheme.selectionAnimationDuration,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.captionSize,
                      fontWeight: widget.checked
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.checked
                          ? AppColors.primary
                          : DdtTheme.textMuted(context),
                    ),
                    child: Text('${widget.option.count}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
