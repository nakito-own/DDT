import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_app_input.dart';
import 'ddt_checkbox.dart';
import 'ddt_context_menu.dart';
import 'ddt_icon.dart';

/// Room for focus shadow and hover border without clipping in the filter column.
class DdtFilterDropdownHoverSlot extends StatelessWidget {
  const DdtFilterDropdownHoverSlot({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: child,
    );
  }
}

class DdtFilterLabel extends StatelessWidget {
  const DdtFilterLabel(this.text, {super.key});

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

class DdtFilterOption {
  const DdtFilterOption({
    required this.key,
    required this.label,
    this.count,
  });

  final String key;
  final String label;
  final int? count;
}

/// Summary text for multi-select filter dropdowns (same rules as analytics).
String ddtFilterSelectionSummary(
  Set<String> selected,
  List<DdtFilterOption> options, {
  String emptyLabel = 'Все значения',
}) {
  if (selected.isEmpty) return emptyLabel;
  final labels = [
    for (final option in options)
      if (selected.contains(option.key)) option.label,
  ];
  if (labels.isEmpty) return emptyLabel;
  if (labels.length == 1) return labels.first;
  if (labels.length == 2) return '${labels[0]}, ${labels[1]}';
  return 'Выбрано: ${labels.length}';
}

class DdtSearchableFilterDropdown extends StatelessWidget {
  const DdtSearchableFilterDropdown({
    required this.summary,
    required this.active,
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
    this.multi = true,
    this.emptyLabel = 'Нет значений',
  });

  final String summary;
  final bool active;
  final List<DdtFilterOption> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final bool multi;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchorContext) {
        return DdtFilterDropdownAnchor(
          label: summary,
          active: active,
          badge: multi ? selected.length : 0,
          onTap: () => showDdtContextPanel(
            context: context,
            anchorContext: anchorContext,
            placement: DdtContextMenuPlacement.belowStart,
            childBuilder: (_) => _DdtSearchableFilterMenu(
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

class DdtFilterDropdownAnchor extends StatefulWidget {
  const DdtFilterDropdownAnchor({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
    this.icon,
    this.badge = 0,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final FaIconData? icon;
  final int badge;

  @override
  State<DdtFilterDropdownAnchor> createState() => _DdtFilterDropdownAnchorState();
}

class _DdtFilterDropdownAnchorState extends State<DdtFilterDropdownAnchor> {
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
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
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
                    child: DdtIcon(
                      widget.icon!,
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
                  child: DdtIcon(
                    DdtIcons.chevronDown,
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

class _DdtSearchableFilterMenu extends StatefulWidget {
  const _DdtSearchableFilterMenu({
    required this.options,
    required this.selected,
    required this.multi,
    required this.emptyLabel,
    required this.onSelected,
  });

  final List<DdtFilterOption> options;
  final Set<String> selected;
  final bool multi;
  final String emptyLabel;
  final ValueChanged<String> onSelected;

  @override
  State<_DdtSearchableFilterMenu> createState() =>
      _DdtSearchableFilterMenuState();
}

class _DdtSearchableFilterMenuState extends State<_DdtSearchableFilterMenu> {
  late final Set<String> _selected = {...widget.selected};
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<DdtFilterOption> get _visible {
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
              prefixIcon: DdtIcons.search,
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
                    ? _DdtFilterMenuPlaceholder(
                        key: const ValueKey('empty'),
                        text: widget.emptyLabel,
                      )
                    : visible.isEmpty
                    ? const _DdtFilterMenuPlaceholder(
                        key: ValueKey('none'),
                        text: 'Ничего не найдено',
                      )
                    : ListView.builder(
                        key: ValueKey('list-${visible.length}'),
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final option = visible[index];
                          return _DdtFilterOptionRow(
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

class _DdtFilterMenuPlaceholder extends StatelessWidget {
  const _DdtFilterMenuPlaceholder({required this.text, super.key});

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

class _DdtFilterOptionRow extends StatefulWidget {
  const _DdtFilterOptionRow({
    required this.option,
    required this.checked,
    required this.multi,
    required this.onTap,
  });

  final DdtFilterOption option;
  final bool checked;
  final bool multi;
  final VoidCallback onTap;

  @override
  State<_DdtFilterOptionRow> createState() => _DdtFilterOptionRowState();
}

class _DdtFilterOptionRowState extends State<_DdtFilterOptionRow> {
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
                    child: DdtIcon(
                      widget.checked
                          ? DdtIcons.radioOn
                          : DdtIcons.radioOff,
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
