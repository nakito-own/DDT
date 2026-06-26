import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';

/// Tap target without Material ink effects.
///
/// Selection transitions use [AnimatedContainer], matching bolt_ui_kit
/// (AppCard / GlassContainer use GestureDetector without ink splash).
class DdtTappable extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DdtTheme.radius;
    final resolvedBackground = selected
        ? selectedBackgroundColor
        : backgroundColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: DdtTheme.selectionAnimationDuration,
        curve: DdtTheme.selectionAnimationCurve,
        padding: padding,
        decoration: BoxDecoration(
          color: resolvedBackground,
          borderRadius: radius,
          border: border,
          boxShadow: boxShadow,
        ),
        child: child,
      ),
    );
  }
}
