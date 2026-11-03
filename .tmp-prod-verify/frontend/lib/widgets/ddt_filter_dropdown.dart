import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_app_input.dart';
import 'ddt_checkbox.dart';
import 'ddt_context_menu.dart';
import 'ddt_icon.dart';

/// Vertical inset for focus shadow; width comes from the sidebar.
class DdtFilterDropdownHoverSlot extends StatelessWidget {
  const DdtFilterDropdownHoverSlot({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: SizedBox(width: double.infinity, child: child),
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
        fontWeight: FontWeight.w600,
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
    this.enabled = true,
    this.searchText,
    this.content,
  });

  final String key;
  final String label;
  final int? count;
  final bool enabled;

  /// Дополнительная строка для поиска. Подпись и так участвует в поиске.
  final String? searchText;

  /// Содержимое строки вместо обычной подписи. Поиск идёт по [label] и [searchText].
  final WidgetBuilder? content;

  bool matches(String needle) {
    if (needle.isEmpty) return true;
    final haystack = '${searchText ?? ''} $label'.toLowerCase();
    return haystack.contains(needle);
  }
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
          onTap: () => showDdtSearchableFilterMenu(
            context: context,
            anchorContext: anchorContext,
            options: options,
            selected: selected,
            onSelected: onSelected,
            multi: multi,
            emptyLabel: emptyLabel,
          ),
        );
      },
    );
  }
}

/// Searchable popover panel shared by filter sidebars and compact form pickers.
Future<void> showDdtSearchableFilterMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<DdtFilterOption> options,
  required Set<String> selected,
  required ValueChanged<String> onSelected,
  bool multi = false,
  String emptyLabel = 'Нет значений',
  bool matchAnchorWidth = false,
  double? menuWidth,
}) {
  final anchorWidth =
      menuWidth ??
      (matchAnchorWidth
          ? ddtContextMenuAnchorRect(
              context: context,
              anchorContext: anchorContext,
            )?.width
          : null);

  return showDdtContextPanel(
    context: context,
    anchorContext: anchorContext,
    placement: DdtContextMenuPlacement.belowStart,
    offset: Offset(0, 4.h),
    childBuilder: (dismiss) => _DdtSearchableFilterMenu(
      options: options,
      selected: selected,
      multi: multi,
      emptyLabel: emptyLabel,
      closeOnSelect: !multi,
      dismiss: dismiss,
      onSelected: onSelected,
      menuWidth: anchorWidth,
    ),
  );
}

/// Compact trigger used in the app bar. Must stay shorter than the bar.
const double kDdtCompactFilterDropdownHeight = 32;

class DdtFilterDropdownAnchor extends StatefulWidget {
  const DdtFilterDropdownAnchor({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
    this.icon,
    this.badge = 0,
    this.compact = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final FaIconData? icon;
  final int badge;
  final bool compact;

  @override
  State<DdtFilterDropdownAnchor> createState() =>
      _DdtFilterDropdownAnchorState();
}

class _DdtFilterDropdownAnchorState extends State<DdtFilterDropdownAnchor> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = widget.active
        ? DdtTheme.primaryColor.withValues(alpha: isDark ? 0.16 : 0.08)
        : _hovered
        ? DdtTheme.inputFillColorHover(context)
        : DdtTheme.inputFillColor(context);
    final border = widget.active
        ? DdtTheme.primaryColor.withValues(alpha: _hovered ? 0.55 : 0.38)
        : (_hovered
              ? DdtTheme.borderStrong(context)
              : DdtTheme.borderSubtle(context));

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
          width: double.infinity,
          height: widget.compact
              ? kDdtCompactFilterDropdownHeight
              : DdtTheme.compactInputControlHeight,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10.w : 12.w,
          ),
          decoration: BoxDecoration(
            borderRadius: DdtTheme.inputControlBorderRadius,
            border: Border.all(color: border),
            color: fill,
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                DdtIcon(
                  widget.icon!,
                  size: (widget.compact ? 13 : 14).sp,
                  color: widget.active
                      ? (isDark ? DdtTheme.accentColor : DdtTheme.primaryColor)
                      : DdtTheme.textMuted(context),
                ),
                SizedBox(width: (widget.compact ? 6 : 8).w),
              ],
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: DdtTheme.selectionAnimationDuration,
                  curve: DdtTheme.selectionAnimationCurve,
                  style: DdtTheme.style(
                    fontSize: widget.compact
                        ? DdtTypography.labelSmallSize
                        : DdtTypography.labelSize,
                    fontWeight: widget.active
                        ? FontWeight.w600
                        : FontWeight.w500,
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
                        margin: EdgeInsets.only(right: 6.w),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 1.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: DdtTheme.primaryColor,
                          borderRadius: DdtTheme.badgeBorderRadius,
                        ),
                        child: Text(
                          '${widget.badge}',
                          style: DdtTheme.style(
                            fontSize: DdtTypography.microSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-badge')),
              ),
              DdtIcon(
                DdtIcons.chevronDown,
                size: 12.sp,
                color: widget.active || _hovered
                    ? DdtTheme.textSecondary(context)
                    : DdtTheme.textMuted(context),
              ),
            ],
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
    this.closeOnSelect = false,
    this.dismiss,
    this.menuWidth,
  });

  final List<DdtFilterOption> options;
  final Set<String> selected;
  final bool multi;
  final String emptyLabel;
  final ValueChanged<String> onSelected;
  final bool closeOnSelect;
  final Future<void> Function()? dismiss;
  final double? menuWidth;

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
        if (option.matches(needle)) option,
    ];
  }

  void _select(String key) {
    for (final option in widget.options) {
      if (option.key == key) {
        if (!option.enabled) return;
        break;
      }
    }

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
    if (widget.closeOnSelect && widget.dismiss != null) {
      unawaited(widget.dismiss!());
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return DdtTheme.contextMenuGlass(
      context: context,
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 6.h),
      child: SizedBox(
        width: widget.menuWidth ?? 280.w,
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
                            onTap: option.enabled
                                ? () => _select(option.key)
                                : null,
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
  final VoidCallback? onTap;

  @override
  State<_DdtFilterOptionRow> createState() => _DdtFilterOptionRowState();
}

class _DdtFilterOptionRowState extends State<_DdtFilterOptionRow> {
  bool _hovered = false;

  Color _background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.checked) {
      return DdtTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.10);
    }
    if (isDark) {
      return Colors.white.withValues(alpha: _hovered ? 0.06 : 0.0);
    }
    return DdtTheme.primaryColor.withValues(alpha: _hovered ? 0.08 : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.option.enabled && widget.onTap != null;
    final textColor = enabled
        ? DdtTheme.textPrimary(context)
        : DdtTheme.textMuted(context).withValues(alpha: 0.55);
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _background(context),
              borderRadius: BorderRadius.circular(6.r),
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
                  DdtIcon(
                    widget.checked ? DdtIcons.radioOn : DdtIcons.radioOff,
                    size: 15.sp,
                    color: widget.checked
                        ? accent
                        : (_hovered
                              ? DdtTheme.textSecondary(context)
                              : DdtTheme.textMuted(context)),
                  ),
                SizedBox(width: 8.w),
                Expanded(
                  child: widget.option.content != null
                      ? widget.option.content!(context)
                      : Text(
                          widget.option.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DdtTheme.style(
                            fontSize: DdtTypography.labelSize,
                            fontWeight: widget.checked
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                ),
                if (widget.option.count != null)
                  Text(
                    '${widget.option.count}',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.captionSize,
                      fontWeight: widget.checked
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: widget.checked
                          ? accent
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
