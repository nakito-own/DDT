import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_filter_dropdown.dart';
import 'ddt_icon.dart';
import 'ddt_shell_metrics.dart';

/// Shared left column for section pages (tasks, mail, analytics).
abstract final class DdtSectionSidebar {
  static const double width = 272;

  /// Inset between controls and the left edge of the panel.
  static const double gutter = 8;

  /// Space between the scrollbar and the panel's right edge.
  static const double scrollbarEdgeInset = 0;

  /// Space between controls and the scrollbar.
  static const double scrollbarGap = 6;

  static double get scrollRightInset =>
      scrollbarEdgeInset + DdtTheme.scrollbarThickness + scrollbarGap;

  static EdgeInsets contentPadding() =>
      EdgeInsets.fromLTRB(gutter.w, 2.h, scrollRightInset.w, 12.h);

  /// [ListView] padding. The right side clears the scrollbar.
  static EdgeInsets scrollContentPadding({double? top, double? bottom}) =>
      EdgeInsets.fromLTRB(
        gutter.w,
        top ?? 2.h,
        scrollRightInset.w,
        bottom ?? 12.h,
      );

  /// Empty space between the scrollbar and the vertical divider.
  static const double afterScrollbarGap = 2;

  static Widget afterScrollbarGapBox() => SizedBox(width: afterScrollbarGap.w);

  /// Empty space between the divider and the main content.
  static Widget dividerGap() => DdtTheme.horizontalGap();

  static double get afterPrimaryButtonGap => 10.h;
  static double get afterTitleGap => 12.h;
  static double get fieldGap => 10.h;
  static double get labelGap => 4.h;
  static double get blockGap => 16.h;
  static double get afterDividerGap => 12.h;
}

/// Fixed-width column below the glass app bar.
class DdtSectionSidebarFrame extends StatelessWidget {
  const DdtSectionSidebarFrame({
    super.key,
    required this.child,
    this.constrainWidth = true,
  });

  final Widget child;
  final bool constrainWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DdtShellMetrics.fixedTopPadding(context),
      child: constrainWidth
          ? SizedBox(width: DdtSectionSidebar.width.w, child: child)
          : child,
    );
  }
}

class DdtSectionSidebarTitle extends StatelessWidget {
  const DdtSectionSidebarTitle({
    super.key,
    this.title = 'Фильтры',
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  static double rowHeight(BuildContext context) {
    return DdtTypography.sectionTitleSize + 8.h;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DdtIcon(
          DdtIcons.sliders,
          size: 18.sp,
          color: AppColors.primary.withValues(alpha: 0.85),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            title,
            style: DdtTheme.style(
              fontSize: DdtTypography.sectionTitleSize,
              fontWeight: FontWeight.w700,
              color: DdtTheme.taskCardTextPrimary(context),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Label + full-width control with the shared sidebar gaps.
class DdtSectionSidebarField extends StatelessWidget {
  const DdtSectionSidebarField({
    super.key,
    required this.child,
    this.label,
    this.gapAbove = true,
  });

  final String? label;
  final Widget child;
  final bool gapAbove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (gapAbove) SizedBox(height: DdtSectionSidebar.fieldGap),
        if (label != null) ...[
          DdtFilterLabel(label!),
          SizedBox(height: DdtSectionSidebar.labelGap),
        ],
        DdtFilterDropdownHoverSlot(child: child),
      ],
    );
  }
}

/// Sidebar lists keep their own equal insets. The app-wide scrollbar gutter
/// would add extra space only on the right.
class DdtSectionSidebarScroll extends StatelessWidget {
  const DdtSectionSidebarScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _SidebarScrollBehavior(),
      child: child,
    );
  }
}

class _SidebarScrollBehavior extends MaterialScrollBehavior {
  const _SidebarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return ScrollbarTheme(
          data: ScrollbarThemeData(
            thickness: const WidgetStatePropertyAll(DdtTheme.scrollbarThickness),
            crossAxisMargin: DdtSectionSidebar.scrollbarEdgeInset,
            radius: const Radius.circular(8),
            mainAxisMargin: DdtTheme.scrollbarMainAxisMargin,
          ),
          child: Scrollbar(controller: details.controller, child: child),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}
