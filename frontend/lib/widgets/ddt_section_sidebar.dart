import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_filter_dropdown.dart';
import 'ddt_icon.dart';
import 'ddt_scroll_edge_fade.dart';
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

  /// Space between the app bar reserve and the sidebar's main button.
  /// Mail uses this for «Написать»; every other section matches it.
  static double get contentTopInset => 2.h;

  static EdgeInsets contentPadding() =>
      EdgeInsets.fromLTRB(gutter.w, contentTopInset, scrollRightInset.w, 12.h);

  /// [ListView] padding. The right side clears the scrollbar.
  static EdgeInsets scrollContentPadding({double? top, double? bottom}) =>
      EdgeInsets.fromLTRB(
        gutter.w,
        top ?? contentTopInset,
        scrollRightInset.w,
        bottom ?? 12.h,
      );

  /// Empty space between the scrollbar and the vertical divider.
  static const double afterScrollbarGap = 2;

  static Widget afterScrollbarGapBox() => SizedBox(width: afterScrollbarGap.w);

  /// Empty space between the divider and the main content.
  static const double contentGap = 8;

  static Widget dividerGap() => SizedBox(width: contentGap.w);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: DdtTheme.primaryColor.withValues(
              alpha: isDark ? 0.20 : 0.10,
            ),
            borderRadius: BorderRadius.circular(6.r),
          ),
          alignment: Alignment.center,
          child: DdtIcon(
            DdtIcons.sliders,
            size: 12.sp,
            color: isDark ? DdtTheme.accentColor : DdtTheme.primaryColor,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            title,
            style: DdtTheme.style(
              fontSize: DdtTypography.sectionTitleSize,
              fontWeight: FontWeight.w600,
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

/// Pinned sidebar chrome centered on the top scroll fade.
///
/// [pinned] stays under the app bar. The scroll fades above and below that
/// block by the same amount, so the block sits in the middle of the gradient.
class DdtSectionSidebarPane extends StatefulWidget {
  const DdtSectionSidebarPane({
    super.key,
    required this.pinned,
    required this.children,
  });

  final Widget pinned;
  final List<Widget> children;

  @override
  State<DdtSectionSidebarPane> createState() => _DdtSectionSidebarPaneState();
}

class _DdtSectionSidebarPaneState extends State<DdtSectionSidebarPane> {
  final _scroll = ScrollController();
  double _pinnedHeight = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onPinnedSize(Size size) {
    final next = size.height;
    if (!mounted || (next - _pinnedHeight).abs() < 0.5) return;
    setState(() => _pinnedHeight = next);
  }

  void _scrollBy(double dy) {
    if (dy == 0 || !_scroll.hasClients) return;
    final position = _scroll.position;
    final next = (position.pixels + dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) position.jumpTo(next.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final pinnedTop = DdtSectionSidebar.contentTopInset;
    final below = DdtSectionSidebar.afterTitleGap;
    final topFade = _pinnedHeight <= 0
        ? pinnedTop + below
        : pinnedTop + _pinnedHeight + below;
    final bottomFade = kDdtScrollEdgeFadeHeightCompact.h;

    return DdtSectionSidebarScroll(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return SizedBox(
            height: height.isFinite ? height : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DdtContentFadeMask(
                  topFade: topFade,
                  bottomFade: bottomFade,
                  child: ListView(
                    controller: _scroll,
                    clipBehavior: Clip.hardEdge,
                    padding: DdtSectionSidebar.scrollContentPadding(
                      top: topFade,
                      bottom: bottomFade + 12.h,
                    ),
                    children: widget.children,
                  ),
                ),
                Positioned(
                  top: pinnedTop,
                  left: DdtSectionSidebar.gutter.w,
                  right: DdtSectionSidebar.scrollRightInset.w,
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        _scrollBy(event.scrollDelta.dy);
                      }
                    },
                    child: _ReportSize(
                      onChange: _onPinnedSize,
                      child: widget.pinned,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Reports its own size after layout. The render object may read its size;
/// a parent callback may not.
class _ReportSize extends SingleChildRenderObjectWidget {
  const _ReportSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderProxyBox createRenderObject(BuildContext context) {
    return _RenderReportSize(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderReportSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderReportSize extends RenderProxyBox {
  _RenderReportSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final next = child?.size ?? Size.zero;
    if (_last == next) return;
    _last = next;
    final reported = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_last != reported) return;
      onChange(reported);
    });
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
