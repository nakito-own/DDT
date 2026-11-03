import 'package:flutter/material.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import 'ddt_glass_fab.dart';
import 'ddt_mobile_navigation_bar.dart';

/// Shows [DdtGlassFab] after the content has scrolled, above the create button.
class DdtScrollToTopOverlay extends StatefulWidget {
  const DdtScrollToTopOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  /// Bottom edge of the button: one gap above the 48px create button.
  static double bottomOf(BuildContext context) {
    return DdtGlassFab.bottomOffset(context) + DdtGlassFab.size + 12;
  }

  @override
  State<DdtScrollToTopOverlay> createState() => _DdtScrollToTopOverlayState();
}

class _DdtScrollToTopOverlayState extends State<DdtScrollToTopOverlay> {
  static const _revealAfter = 240.0;

  BuildContext? _scrollableContext;
  var _show = false;

  @override
  void didUpdateWidget(covariant DdtScrollToTopOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _show) {
      _show = false;
      _scrollableContext = null;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.enabled || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final scrollContext = notification.context;
    if (scrollContext == null || !scrollContext.mounted) return false;
    final position = Scrollable.maybeOf(scrollContext)?.position;
    if (position == null || !position.hasPixels) return false;

    final past = position.pixels > position.minScrollExtent + _revealAfter;
    if (past) {
      _scrollableContext = scrollContext;
      if (!_show) setState(() => _show = true);
    } else if (identical(scrollContext, _scrollableContext) && _show) {
      setState(() => _show = false);
    }
    return false;
  }

  Future<void> _scrollToTop() async {
    final targets = <ScrollPosition>[];
    void visit(Element element) {
      if (!element.mounted) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (position.axis == Axis.vertical &&
            position.hasContentDimensions &&
            position.pixels > position.minScrollExtent) {
          targets.add(position);
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    if (targets.isEmpty) {
      if (_show) {
        setState(() {
          _show = false;
          _scrollableContext = null;
        });
      }
      return;
    }
    await Future.wait([
      for (final position in targets)
        position.animateTo(
          position.minScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (widget.enabled)
            Positioned(
              right: DdtMobileNavigationBar.horizontalMargin,
              bottom: DdtScrollToTopOverlay.bottomOf(context),
              child: IgnorePointer(
                ignoring: !_show,
                child: AnimatedScale(
                  scale: _show ? 1 : 0.72,
                  duration: DdtTheme.selectionAnimationDuration,
                  curve: DdtTheme.selectionAnimationCurve,
                  child: AnimatedOpacity(
                    opacity: _show ? 1 : 0,
                    duration: DdtTheme.selectionAnimationDuration,
                    curve: DdtTheme.selectionAnimationCurve,
                    child: DdtGlassFab(
                      icon: DdtIcons.arrowUp,
                      tooltip: 'Наверх',
                      onPressed: _scrollToTop,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
