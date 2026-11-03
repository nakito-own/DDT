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
  ScrollPosition? _scrollPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition == next) return;
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
    _scrollPosition = next;
    _scrollPosition?.isScrollingNotifier.addListener(_onScrollActivity);
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
    super.dispose();
  }

  void _onScrollActivity() {
    if (_scrollPosition?.isScrollingNotifier.value != true || !_hovered) return;
    setState(() => _hovered = false);
  }

  void _setHovered(bool value) {
    if (_scrollPosition?.isScrollingNotifier.value == true) return;
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  Color? _resolveBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.selected
        ? widget.selectedBackgroundColor
        : widget.backgroundColor;

    final isFilled = base != null && base.a > 0 && base != Colors.transparent;

    if (!widget.enableHoverFill || !_hovered) {
      if (isFilled) return base;
      if (widget.enableHoverFill) {
        return isDark
            ? Colors.white.withValues(alpha: 0.0)
            : DdtTheme.primaryColor.withValues(alpha: 0.0);
      }
      return base;
    }

    if (isFilled) {
      return Color.alphaBlend(
        DdtTheme.primaryColor.withValues(alpha: isDark ? 0.08 : 0.06),
        base,
      );
    }

    return isDark
        ? Colors.white.withValues(alpha: 0.06)
        : DdtTheme.primaryColor.withValues(alpha: 0.08);
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
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
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
