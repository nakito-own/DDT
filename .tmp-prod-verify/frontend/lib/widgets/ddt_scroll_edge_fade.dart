import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';
import 'ddt_adaptive.dart';
import 'ddt_mobile_navigation_bar.dart';

/// Main scroll areas (tasks, mail, analytics dashboard, contacts).
const double kDdtScrollEdgeFadeHeight = 36.0;

/// Taller, denser top fade on the phone layout. The header sits in the solid part.
const double kDdtScrollEdgeFadeHeightTopMobile = 72.0;

/// Narrow panels (e.g. analytics filters sidebar).
const double kDdtScrollEdgeFadeHeightCompact = 26.0;

const double _kDdtScrollEdgeFadeListGap = 4.0;

(int, int, int) _rgbChannels(Color color) {
  return (
    (color.r * 255.0).round() & 0xff,
    (color.g * 255.0).round() & 0xff,
    (color.b * 255.0).round() & 0xff,
  );
}

/// Opaque fill at the screen edge; transparent at the inner edge (same RGB).
(Color solid, Color clear) _edgeFadePair(Color background) {
  final (r, g, b) = _rgbChannels(background);
  return (Color.fromARGB(255, r, g, b), Color.fromARGB(0, r, g, b));
}

/// Soft top/bottom fades over a scroll viewport (content scrolls beneath).
class DdtScrollEdgeFade extends StatelessWidget {
  const DdtScrollEdgeFade({
    super.key,
    required this.child,
    this.backgroundColor,
    this.showTop = true,
    this.showBottom = true,
    this.edgeFadeHeight = kDdtScrollEdgeFadeHeight,
  });

  final Widget child;
  final Color? backgroundColor;
  final bool showTop;
  final bool showBottom;

  /// Logical height of each edge gradient before screen scaling.
  final double edgeFadeHeight;

  static double fadeHeight(BuildContext context) => kDdtScrollEdgeFadeHeight.h;

  /// Extra [ScrollView.padding.bottom] so the last items clear the bottom fade
  /// and, on the phone layout, the floating bar that sits on top of it.
  static double listBottomPadding(BuildContext context) {
    final fade = fadeHeight(context) + _kDdtScrollEdgeFadeListGap.h;
    if (!DdtAdaptive.floatingBottomBar(context)) return fade;
    return fade + DdtMobileNavigationBar.clearance(context);
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? DdtTheme.scaffoldBackground(context);
    final topHeight = DdtAdaptive.floatingBottomBar(context)
        ? kDdtScrollEdgeFadeHeightTopMobile
        : edgeFadeHeight;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        child,
        if (showTop)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DdtScrollEdgeFadeGradient(
              backgroundColor: bg,
              atTop: true,
              fadeHeight: topHeight,
              hold: DdtAdaptive.floatingBottomBar(context),
            ),
          ),
        if (showBottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: DdtScrollEdgeFadeGradient(
              backgroundColor: bg,
              atTop: false,
              fadeHeight: edgeFadeHeight,
            ),
          ),
      ],
    );
  }
}

class DdtScrollEdgeFadeGradient extends StatelessWidget {
  const DdtScrollEdgeFadeGradient({
    super.key,
    required this.backgroundColor,
    required this.atTop,
    this.fadeHeight = kDdtScrollEdgeFadeHeightCompact,
    this.hold = false,
  });

  final Color backgroundColor;
  final bool atTop;
  final double fadeHeight;

  /// Keeps the edge opaque for longer before dissolving.
  final bool hold;

  @override
  Widget build(BuildContext context) {
    final (solid, clear) = _edgeFadePair(backgroundColor);
    final colors = atTop
        ? (hold ? [solid, solid, clear] : [solid, clear])
        : [clear, solid];
    final stops = atTop && hold ? const [0.0, 0.5, 1.0] : const [0.0, 1.0];

    return IgnorePointer(
      child: SizedBox(
        height: fadeHeight.h,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: stops,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}
