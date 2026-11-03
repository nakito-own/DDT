import 'package:flutter/material.dart';

import '../models/app_section.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import 'ddt_adaptive.dart';
import 'ddt_app_bar_section_actions.dart';
import 'ddt_glass_app_bar.dart';
import 'ddt_glass_navigation_rail.dart';
import 'ddt_mobile_navigation_bar.dart';
import 'ddt_icon.dart';
import 'ddt_section_transition.dart';
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
    if (DdtAdaptive.isCompact(context)) {
      return _CompactShellLayout(
        title: title,
        selectedSection: selectedSection,
        onSectionSelected: onSectionSelected,
        padContent: padContent,
        child: child,
      );
    }

    final shellInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing);
    final contentEdge = DdtTheme.shellSizeOf(context, contentRightInset);
    final contentBottom = DdtTheme.shellSizeOf(context, contentBottomInset);
    final contentTopInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing / 2);
    final railLeftInset = DdtTheme.shellSizeOf(context, railAreaLeftInset);
    final barHeight = DdtTheme.shellSizeOf(context, DdtGlassAppBar.barHeight);
    final contentRowTop = railLeftInset + barHeight + contentTopInset;
    // Kanban already shifts its child below the app bar. A second inset inside
    // that child is the empty band above a task opened from the board.
    final contentInsetTop = padContent
        ? contentRowTop + contentTopInset
        : 0.0;

    return Scaffold(
      backgroundColor: DdtTheme.scaffoldBackground(context),
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
                        section: selectedSection,
                        padContent: padContent,
                        extendUnderBottomBar: false,
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
                  actions: DdtAppBarSectionActions(section: selectedSection),
                  center: selectedSection == AppSection.calendar
                      ? const CalendarAppBarDateNav()
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactShellLayout extends StatefulWidget {
  const _CompactShellLayout({
    required this.title,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.padContent,
    required this.child,
  });

  final String title;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;
  final bool padContent;
  final Widget child;

  @override
  State<_CompactShellLayout> createState() => _CompactShellLayoutState();
}

class _CompactShellLayoutState extends State<_CompactShellLayout>
    with SingleTickerProviderStateMixin {
  final _sheets = DdtSectionSheetController();
  final _bar = DdtCompactBarController();
  late final AnimationController _drawerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  );
  bool _drawerShown = false;

  @override
  void dispose() {
    _sheets.dispose();
    _bar.dispose();
    _drawerController.dispose();
    super.dispose();
  }

  void _openDrawer() {
    setState(() => _drawerShown = true);
    _drawerController.forward();
  }

  Future<void> _closeDrawer() async {
    await _drawerController.reverse();
    if (mounted) setState(() => _drawerShown = false);
  }

  bool get _secondaryRow {
    return switch (widget.selectedSection) {
      AppSection.space || AppSection.analytics => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final contentEdge = DdtTheme.shellSizeOf(
      context,
      DdtShellLayout.contentRightInset,
    );
    final floatingBar = DdtAdaptive.floatingBottomBar(context);
    final contentBottom = floatingBar
        ? DdtMobileNavigationBar.clearance(context)
        : DdtTheme.shellSizeOf(context, DdtShellLayout.contentBottomInset);
    final contentTopInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing / 2);
    final railLeftInset = DdtTheme.shellSizeOf(
      context,
      DdtShellLayout.railAreaLeftInset,
    );

    return DdtCompactBarScope(
      controller: _bar,
      child: DdtSectionSheetScope(
        controller: _sheets,
        child: ListenableBuilder(
          listenable: _bar,
          builder: (context, _) {
            final showBack = _bar.hasOverride;
            final secondaryRow = !showBack && _secondaryRow;
            final logicalBar = secondaryRow
                ? DdtGlassAppBar.barHeight + DdtGlassAppBar.secondaryRowHeight
                : DdtGlassAppBar.barHeight;
            final barHeight = DdtTheme.shellSizeOf(context, logicalBar);
            final headerTop = floatingBar ? 4.0 : railLeftInset;
            final layoutTop = floatingBar
                ? 0.0
                : railLeftInset + barHeight + contentTopInset;
            final contentInsetTop = floatingBar
                ? headerTop + barHeight + DdtTheme.shellSizeOf(context, 4)
                : widget.padContent
                ? layoutTop + contentTopInset
                : 0.0;
            final foreground = DdtTheme.textPrimary(context);
            final header = DdtGlassAppBar(
              title: _bar.title ?? widget.title,
              secondaryRow: secondaryRow,
              compact: true,
              overlay: floatingBar,
              leading: showBack || !floatingBar
                  ? IconButton(
                      tooltip: showBack ? 'Назад' : 'Разделы',
                      onPressed: showBack ? _bar.onBack : _openDrawer,
                      icon: DdtIcon(
                        showBack ? DdtIcons.back : DdtIcons.dragHandle,
                        size: DdtGlassAppBar.actionIconSizeOf(context),
                        color: foreground,
                      ),
                    )
                  : null,
              actions: showBack
                  ? null
                  : DdtAppBarSectionActions(section: widget.selectedSection),
              center: null,
            );

            return PopScope(
              canPop: floatingBar || !_drawerShown,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && !floatingBar && _drawerShown) {
                  _closeDrawer();
                }
              },
              child: Scaffold(
                backgroundColor: DdtTheme.scaffoldBackground(context),
                body: Stack(
                  children: [
                    SafeArea(
                      bottom: !floatingBar,
                      child: DdtShellMetrics(
                        topReserve: contentInsetTop,
                        contentInsetTop: contentInsetTop,
                        contentInsetBottom: contentBottom,
                        contentInsetRight: contentEdge,
                        contentInsetAfterRail: contentEdge,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: contentEdge,
                              right: contentEdge,
                              top: 0,
                              bottom: 0,
                              child: _ShellMainContent(
                                section: widget.selectedSection,
                                padContent: widget.padContent,
                                extendUnderBottomBar: floatingBar,
                                contentRowTop: layoutTop,
                                child: widget.child,
                              ),
                            ),
                            Positioned(
                              left: railLeftInset,
                              right: railLeftInset,
                              top: headerTop,
                              height: floatingBar ? null : barHeight,
                              child: header,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (floatingBar)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DdtMobileNavigationBar(
                          selectedSection: widget.selectedSection,
                          onSectionSelected: widget.onSectionSelected,
                        ),
                      ),
                    if (!floatingBar && _drawerShown)
                      Positioned.fill(
                        child: DdtMobileDrawerLayer(
                          progress: CurvedAnimation(
                            parent: _drawerController,
                            curve: Curves.easeOutCubic,
                            reverseCurve: Curves.easeInCubic,
                          ),
                          selectedSection: widget.selectedSection,
                          onSectionSelected: widget.onSectionSelected,
                          onDismiss: _closeDrawer,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShellMainContent extends StatelessWidget {
  const _ShellMainContent({
    required this.section,
    required this.padContent,
    required this.extendUnderBottomBar,
    required this.contentRowTop,
    required this.child,
  });

  final AppSection section;
  final bool padContent;
  final bool extendUnderBottomBar;
  final double contentRowTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        DdtShellMetrics.maybeOf(context)?.contentInsetBottom ??
        DdtTheme.shellSizeOf(context, DdtShellLayout.contentBottomInset);

    // Kanban drops the top inset, which changes this subtree. The transition
    // has to stay in the same slot, otherwise leaving kanban for another
    // section mounts a fresh animator and the page flip is skipped.
    final page = padContent
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: contentRowTop),
              Expanded(child: child),
            ],
          );

    return Padding(
      padding: EdgeInsets.only(bottom: extendUnderBottomBar ? 0 : bottomInset),
      child: DdtSectionTransition(section: section, child: page),
    );
  }
}
