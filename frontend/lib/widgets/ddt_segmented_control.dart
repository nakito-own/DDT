import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';

class DdtSegmentedControlSegment<T> {
  const DdtSegmentedControlSegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented selector styled for DDT glass UI.
///
/// Follows the structure of [GlassWidgets.tabBar] from bolt_ui_kit, but uses
/// DDT theme colors and supports optional icons per segment.
class DdtSegmentedControl<T> extends StatelessWidget {
  const DdtSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  static const double _segmentRadius = DdtTheme.borderRadius + 12;
  static const double _segmentPaddingHorizontal = 16;
  static const double _segmentPaddingVertical = 4;

  final List<DdtSegmentedControlSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: DdtTheme.shellSurfaceDecoration(
        context,
        addShadow: false,
        radius: 30.r,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) SizedBox(width: 2.w),
            _DdtSegmentedControlItem<T>(
              segment: segments[i],
              isSelected: segments[i].value == selected,
              onTap: () => onChanged(segments[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _DdtSegmentedControlItem<T> extends StatefulWidget {
  const _DdtSegmentedControlItem({
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final DdtSegmentedControlSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DdtSegmentedControlItem<T>> createState() =>
      _DdtSegmentedControlItemState<T>();
}

class _DdtSegmentedControlItemState<T>
    extends State<_DdtSegmentedControlItem<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    final isSelected = widget.isSelected;
    final foregroundColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.95)
        : (_hovered
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : DdtTheme.lightTextPrimary)
              : textSecondary);

    final backgroundColor = isSelected
        ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
        : (_hovered
              ? AppColors.primary.withValues(alpha: isDark ? 0.10 : 0.06)
              : Colors.transparent);

    final borderColor = isSelected
        ? AppColors.primary.withValues(alpha: isDark ? 0.45 : 0.32)
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
          padding: EdgeInsets.symmetric(
            horizontal: DdtSegmentedControl._segmentPaddingHorizontal.w,
            vertical: DdtSegmentedControl._segmentPaddingVertical.h,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              DdtSegmentedControl._segmentRadius.r,
            ),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.segment.icon != null) ...[
                Icon(widget.segment.icon, size: 14.sp, color: foregroundColor),
                SizedBox(width: 5.w),
              ],
              Text(
                widget.segment.label,
                style: DdtTheme.style(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
