import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Main scroll areas (tasks, mail, analytics dashboard, contacts).
const double kDdtScrollEdgeFadeHeight = 36.0;

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
  return (
    Color.fromARGB(255, r, g, b),
    Color.fromARGB(0, r, g, b),
  );
}

/// Soft top/bottom fades over a scroll viewport (content scrolls beneath).
class DdtScrollEdgeFade extends StatelessWidget {
  const DdtScrollEdgeFade({
    super.key,
    required this.child,
    this.backgroundColor,
    this.showTop = true,
    this.showBottom = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final bool showTop;
  final bool showBottom;

  static double fadeHeight(BuildContext context) => kDdtScrollEdgeFadeHeight.h;

  /// Extra [ScrollView.padding.bottom] so the last items clear the bottom fade.
  static double listBottomPadding(BuildContext context) {
    return fadeHeight(context) + _kDdtScrollEdgeFadeListGap.h;
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

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
              fadeHeight: kDdtScrollEdgeFadeHeight,
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
              fadeHeight: kDdtScrollEdgeFadeHeight,
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
  });

  final Color backgroundColor;
  final bool atTop;
  final double fadeHeight;

  @override
  Widget build(BuildContext context) {
    final (solid, clear) = _edgeFadePair(backgroundColor);
    final colors = atTop ? [solid, clear] : [clear, solid];

    return IgnorePointer(
      child: SizedBox(
        height: fadeHeight.h,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 1.0],
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}
