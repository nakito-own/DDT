import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

class DdtSegmentedControlSegment<T> {
  const DdtSegmentedControlSegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final FaIconData? icon;
}

/// Modern desktop web segmented selector (recessed track + elevated active pill).
class DdtSegmentedControl<T> extends StatelessWidget {
  const DdtSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  static const double _trackRadius = DdtTheme.inputControlRadius;
  static const double _segmentRadius = 6;
  static const double _segmentPaddingHorizontal = 13;
  static const double _segmentPaddingVertical = 5;
  static const double _segmentPaddingHorizontalCompact = 10;
  static const double _segmentPaddingVerticalCompact = 3;

  final List<DdtSegmentedControlSegment<T>> segments;
  final T? selected;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.56);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.11)
        : DdtTheme.lightBorderSubtle.withValues(alpha: 0.90);
    final resolvedRadius = BorderRadius.circular(_trackRadius.r);

    return ClipRRect(
      borderRadius: resolvedRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all((compact ? 2 : 3).w),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: resolvedRadius,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) SizedBox(width: 2.w),
                _DdtSegmentedControlItem<T>(
                  segment: segments[i],
                  isSelected: segments[i].value == selected,
                  compact: compact,
                  onTap: () => onChanged(segments[i].value),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DdtSegmentedControlItem<T> extends StatefulWidget {
  const _DdtSegmentedControlItem({
    required this.segment,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  final DdtSegmentedControlSegment<T> segment;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

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
    final isSelected = widget.isSelected;

    final foregroundColor = isSelected
        ? DdtTheme.textPrimary(context)
        : (_hovered
              ? DdtTheme.textSecondary(context)
              : DdtTheme.textMuted(context));

    final iconColor = isSelected
        ? (isDark ? DdtTheme.accentColor : DdtTheme.primaryColor)
        : foregroundColor;

    final backgroundColor = isSelected
        ? (isDark
              ? const Color(0xD9283248)
              : Colors.white.withValues(alpha: 0.92))
        : (_hovered
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.58))
              : Colors.transparent);

    final borderColor = isSelected
        ? (isDark
              ? Colors.white.withValues(alpha: 0.14)
              : DdtTheme.lightBorderSubtle)
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
            horizontal: (widget.compact
                    ? DdtSegmentedControl._segmentPaddingHorizontalCompact
                    : DdtSegmentedControl._segmentPaddingHorizontal)
                .w,
            vertical: (widget.compact
                    ? DdtSegmentedControl._segmentPaddingVerticalCompact
                    : DdtSegmentedControl._segmentPaddingVertical)
                .h,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              DdtSegmentedControl._segmentRadius.r,
            ),
            border: Border.all(color: borderColor),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.26 : 0.05,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.segment.icon != null) ...[
                DdtIcon(
                  widget.segment.icon!,
                  size: (widget.compact ? 12 : 13).sp,
                  color: iconColor,
                ),
                SizedBox(width: (widget.compact ? 4 : 6).w),
              ],
              Text(
                widget.segment.label,
                style: DdtTheme.style(
                  fontSize: widget.compact
                      ? DdtTypography.microSize
                      : DdtTypography.labelSmallSize,
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
