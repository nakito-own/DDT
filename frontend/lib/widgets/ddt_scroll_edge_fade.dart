import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'ddt_adaptive.dart';
import 'ddt_mobile_navigation_bar.dart';

/// Main scroll areas (tasks, mail, analytics dashboard, contacts).
const double kDdtScrollEdgeFadeHeight = 36.0;

/// Taller, denser top fade on the phone layout. The header sits in the solid part.
const double kDdtScrollEdgeFadeHeightTopMobile = 72.0;

/// Narrow panels (e.g. analytics filters sidebar).
const double kDdtScrollEdgeFadeHeightCompact = 26.0;

const double _kDdtScrollEdgeFadeListGap = 4.0;

/// Soft top/bottom fades over a scroll viewport (content scrolls beneath).
///
/// Content alpha dissolves into whatever is painted behind the viewport, so
/// the edge follows the app photo instead of a flat fill.
class DdtScrollEdgeFade extends StatelessWidget {
  const DdtScrollEdgeFade({
    super.key,
    required this.child,
    this.showTop = true,
    this.showBottom = true,
    this.edgeFadeHeight = kDdtScrollEdgeFadeHeight,
    this.topFadeHeight,
  });

  final Widget child;
  final bool showTop;
  final bool showBottom;

  /// Logical height of each edge gradient before screen scaling.
  final double edgeFadeHeight;

  /// Overrides the top fade. Phone layout otherwise uses a taller top fade.
  final double? topFadeHeight;

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
    final topHeight =
        topFadeHeight ??
        (DdtAdaptive.floatingBottomBar(context)
            ? kDdtScrollEdgeFadeHeightTopMobile
            : edgeFadeHeight);
    final top = showTop ? topHeight.h : 0.0;
    final hold = showTop && DdtAdaptive.floatingBottomBar(context);

    return DdtContentFadeMask(
      topHold: hold ? top * 0.5 : 0,
      topFade: top,
      bottomFade: showBottom ? edgeFadeHeight.h : 0,
      child: child,
    );
  }
}

/// Fades a viewport's pixels into the backdrop behind it.
///
/// [topHold] stays fully clear, then opacity rises through [topFade].
/// [bottomFade] dissolves the bottom edge. Zero distances leave that edge solid.
class DdtContentFadeMask extends StatelessWidget {
  const DdtContentFadeMask({
    super.key,
    required this.child,
    this.topHold = 0,
    this.topFade = 0,
    this.bottomFade = 0,
  });

  final Widget child;
  final double topHold;
  final double topFade;
  final double bottomFade;

  @override
  Widget build(BuildContext context) {
    if (topFade <= 0 && bottomFade <= 0) return child;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final height = math.max(bounds.height, 1.0);
        double stop(double pixels) => (pixels / height).clamp(0.0, 1.0);
        final stops = <double>[
          0,
          stop(topHold),
          stop(topFade),
          stop(height - bottomFade),
          1,
        ];
        for (var i = 1; i < stops.length; i++) {
          if (stops[i] <= stops[i - 1]) {
            stops[i] = math.min(1, stops[i - 1] + 0.0001);
          }
        }
        final openTop = topFade <= 0;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            openTop ? Colors.white : Colors.transparent,
            openTop ? Colors.white : Colors.transparent,
            Colors.white,
            Colors.white,
            bottomFade <= 0 ? Colors.white : Colors.transparent,
          ],
          stops: stops,
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
