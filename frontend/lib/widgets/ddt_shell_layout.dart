import 'package:flutter/material.dart';

import '../models/app_section.dart';
import '../theme/ddt_theme.dart';
import 'ddt_app_bar_section_actions.dart';
import 'ddt_glass_app_bar.dart';
import 'ddt_glass_navigation_rail.dart';
import 'ddt_shell_metrics.dart';

class DdtShellLayout extends StatelessWidget {
  const DdtShellLayout({
    super.key,
    required this.title,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.child,
    this.padContent = true,
  });

  final String title;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;
  final Widget child;
  final bool padContent;

  static const double railAreaLeftInset = 8;

  /// Horizontal gap: NavigationRail → content, and content → right screen edge.
  static const double contentRightInset = 8;

  /// Bottom breathing room for main content (matches navigation rail bottom inset).
  static const double contentBottomInset = DdtTheme.spacing;

  @override
  Widget build(BuildContext context) {
    final shellInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing);
    final contentEdge = DdtTheme.shellSizeOf(context, contentRightInset);
    final contentBottom = DdtTheme.shellSizeOf(context, contentBottomInset);
    final contentTopInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing / 2);
    final railLeftInset = DdtTheme.shellSizeOf(context, railAreaLeftInset);
    final barHeight = DdtTheme.shellSizeOf(context, DdtGlassAppBar.barHeight);
    final contentRowTop = railLeftInset + barHeight + contentTopInset;
    final contentInsetTop = padContent
        ? contentRowTop + contentTopInset
        : contentRowTop;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: DdtShellMetrics(
          topReserve: contentRowTop,
          contentInsetTop: contentInsetTop,
          contentInsetBottom: contentBottom,
          contentInsetRight: contentEdge,
          contentInsetAfterRail: contentEdge,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: railLeftInset,
                right: contentEdge,
                top: 0,
                bottom: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: contentRowTop,
                        bottom: shellInset,
                      ),
                      child: DdtGlassNavigationRail(
                        selectedSection: selectedSection,
                        onSectionSelected: onSectionSelected,
                      ),
                    ),
                    SizedBox(width: contentEdge),
                    Expanded(
                      child: _ShellMainContent(
                        padContent: padContent,
                        contentRowTop: contentRowTop,
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: railLeftInset,
                right: railLeftInset,
                top: railLeftInset,
                height: barHeight,
                child: DdtGlassAppBar(
                  title: title,
                  actions: DdtAppBarSectionActions(
                    section: selectedSection,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellMainContent extends StatelessWidget {
  const _ShellMainContent({
    required this.padContent,
    required this.contentRowTop,
    required this.child,
  });

  final bool padContent;
  final double contentRowTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        DdtShellMetrics.maybeOf(context)?.contentInsetBottom ??
        DdtTheme.shellSizeOf(context, DdtShellLayout.contentBottomInset);

    final Widget content;
    if (!padContent) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: contentRowTop),
          Expanded(child: child),
        ],
      );
    } else {
      // Full height: scroll views use [DdtShellMetrics.scrollPadding] to align
      // initially and scroll under the floating app bar.
      content = child;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: content,
    );
  }
}
