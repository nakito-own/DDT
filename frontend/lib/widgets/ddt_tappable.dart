import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';

/// Tap target without Material ink effects.
///
/// Selection transitions use [AnimatedContainer], matching bolt_ui_kit
/// (AppCard / GlassContainer use GestureDetector without ink splash).
class DdtTappable extends StatefulWidget {
  const DdtTappable({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.borderRadius,
    this.padding,
    this.border,
    this.boxShadow,
    this.enableHoverFill = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final Color? backgroundColor;
  final Color? selectedBackgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final bool enableHoverFill;

  @override
  State<DdtTappable> createState() => _DdtTappableState();
}

class _DdtTappableState extends State<DdtTappable> {
  bool _hovered = false;

  Color? _resolveBackgroundColor(BuildContext context) {
    final base = widget.selected
        ? widget.selectedBackgroundColor
        : widget.backgroundColor;

    if (!widget.enableHoverFill || !_hovered) {
      return base;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFilled = base != null && base.a > 0 && base != Colors.transparent;

    if (isFilled) {
      return Color.alphaBlend(
        AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.05),
        base,
      );
    }

    return AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? DdtTheme.radius;

    Widget content = AnimatedContainer(
      duration: DdtTheme.selectionAnimationDuration,
      curve: DdtTheme.selectionAnimationCurve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _resolveBackgroundColor(context),
        borderRadius: radius,
        border: widget.border,
        boxShadow: widget.boxShadow,
      ),
      child: widget.child,
    );

    if (widget.enableHoverFill) {
      content = MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: content,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
