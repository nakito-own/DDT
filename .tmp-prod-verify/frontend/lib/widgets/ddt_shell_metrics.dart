import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';
import 'ddt_shell_layout.dart';

/// Layout metrics for content rendered inside [DdtShellLayout].
class DdtShellMetrics extends InheritedWidget {
  const DdtShellMetrics({
    super.key,
    required this.topReserve,
    required this.contentInsetTop,
    required this.contentInsetBottom,
    required this.contentInsetRight,
    required this.contentInsetAfterRail,
    required super.child,
  });

  /// Distance from the main content area top to the bottom edge of the app bar
  /// stack region (start of scroll-under zone).
  final double topReserve;

  /// Where primary content should begin visually (matches pre-stack shell layout).
  final double contentInsetTop;

  /// Distance from the main content area to the bottom screen edge.
  final double contentInsetBottom;

  /// Distance from the main content area to the right screen edge.
  final double contentInsetRight;

  /// Gap between [DdtGlassNavigationRail] and main content (same as [contentInsetRight]).
  final double contentInsetAfterRail;

  static DdtShellMetrics? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DdtShellMetrics>();
  }

  static DdtShellMetrics of(BuildContext context) {
    final metrics = maybeOf(context);
    assert(
      metrics != null,
      'DdtShellMetrics not found. Wrap content in DdtShellLayout.',
    );
    return metrics!;
  }

  /// [EdgeInsets] for scrollables: top inset allows scrolling under the app bar.
  static EdgeInsets scrollPadding(
    BuildContext context, {
    EdgeInsets? base,
  }) {
    final top = maybeOf(context)?.contentInsetTop ?? 0;
    final resolved = base ?? EdgeInsets.zero;
    return resolved.copyWith(top: resolved.top + top);
  }

  /// For fixed (non-scrolling) blocks that must sit below the app bar.
  static EdgeInsets fixedTopPadding(BuildContext context) {
    final top = maybeOf(context)?.contentInsetTop ?? 0;
    return EdgeInsets.only(top: top);
  }

  static double contentBottomPadding(BuildContext context) {
    return maybeOf(context)?.contentInsetBottom ??
        DdtTheme.shellSizeOf(context, DdtShellLayout.contentBottomInset);
  }

  static double contentRightPadding(BuildContext context) {
    return maybeOf(context)?.contentInsetRight ??
        DdtTheme.shellSizeOf(context, DdtShellLayout.contentRightInset);
  }

  static double contentAfterRailPadding(BuildContext context) {
    return maybeOf(context)?.contentInsetAfterRail ??
        DdtTheme.shellSizeOf(context, DdtShellLayout.contentRightInset);
  }

  @override
  bool updateShouldNotify(DdtShellMetrics oldWidget) {
    return topReserve != oldWidget.topReserve ||
        contentInsetTop != oldWidget.contentInsetTop ||
        contentInsetBottom != oldWidget.contentInsetBottom ||
        contentInsetRight != oldWidget.contentInsetRight ||
        contentInsetAfterRail != oldWidget.contentInsetAfterRail;
  }
}
