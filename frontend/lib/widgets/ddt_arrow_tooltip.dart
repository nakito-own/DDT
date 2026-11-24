import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';

const ddtTipArrowLength = 10.0;
const _arrowHalf = 8.0;
const _tipRadius = 16.0;
const _tipGap = 8.0;

enum DdtTipArrowSide { left, right, top, bottom }

class DdtTipPlacement {
  const DdtTipPlacement({
    required this.outer,
    required this.side,
    required this.arrowCenter,
    required this.showArrow,
  });

  /// Box that contains the bubble and the arrow, in overlay coordinates.
  final Rect outer;

  /// Edge of the bubble the arrow sits on. [left] means the bubble is to the
  /// right of the anchor and the arrow points left.
  final DdtTipArrowSide side;
  final double arrowCenter;
  final bool showArrow;
}

DdtTipPlacement ddtPlaceArrowTooltip({
  required Size screen,
  required EdgeInsets padding,
  required Rect? anchor,
  Rect? limit,
  double maxWidth = 640,
  double maxHeight = 380,
}) {
  const margin = 8.0;
  var bounds = Rect.fromLTRB(
    padding.left + margin,
    padding.top + margin,
    math.max(padding.left + margin + 1, screen.width - padding.right - margin),
    math.max(padding.top + margin + 1, screen.height - padding.bottom - margin),
  );
  if (limit != null && limit.width > 48 && limit.height > 48) {
    final limited = limit.deflate(margin);
    if (limited.width > 48 && limited.height > 48) {
      final next = bounds.intersect(limited);
      if (next.width > 48 && next.height > 48) bounds = next;
    }
  }
  final preferredWidth = math.min(maxWidth, bounds.width);
  final preferredHeight = math.min(maxHeight, bounds.height);

  if (anchor == null) {
    final width = math.min(preferredWidth, bounds.width);
    final height = math.min(preferredHeight, bounds.height);
    return DdtTipPlacement(
      outer: Rect.fromCenter(
        center: bounds.center,
        width: width,
        height: height,
      ),
      side: DdtTipArrowSide.left,
      arrowCenter: height / 2,
      showArrow: false,
    );
  }

  int bySpace(DdtTipArrowSide a, DdtTipArrowSide b) =>
      _sideSpace(bounds, anchor, b).compareTo(_sideSpace(bounds, anchor, a));
  final ranked = <DdtTipArrowSide>[
    ...([DdtTipArrowSide.left, DdtTipArrowSide.right]..sort(bySpace)),
    ...([DdtTipArrowSide.top, DdtTipArrowSide.bottom]..sort(bySpace)),
  ];

  for (final side in ranked) {
    final placed = _placeOnSide(
      bounds: bounds,
      anchor: anchor,
      side: side,
      preferredWidth: preferredWidth,
      preferredHeight: preferredHeight,
      allowShrink: false,
    );
    if (placed != null) return placed;
  }
  for (final side in ranked) {
    final placed = _placeOnSide(
      bounds: bounds,
      anchor: anchor,
      side: side,
      preferredWidth: preferredWidth,
      preferredHeight: preferredHeight,
      allowShrink: true,
    );
    if (placed != null) return placed;
  }

  final width = math.min(preferredWidth, bounds.width);
  final height = math.min(preferredHeight, bounds.height);
  return DdtTipPlacement(
    outer: Rect.fromCenter(center: bounds.center, width: width, height: height),
    side: DdtTipArrowSide.left,
    arrowCenter: height / 2,
    showArrow: false,
  );
}

Rect ddtFitTipInside(Rect outer, Rect? limit) {
  if (limit == null) return outer;
  var left = outer.left;
  var top = outer.top;
  var width = math.min(outer.width, limit.width);
  var height = math.min(outer.height, limit.height);
  if (left < limit.left) left = limit.left;
  if (top < limit.top) top = limit.top;
  if (left + width > limit.right) left = limit.right - width;
  if (top + height > limit.bottom) top = limit.bottom - height;
  return Rect.fromLTWH(left, top, width, height);
}

Offset ddtTipSlideOffset(DdtTipArrowSide side, double distance) {
  return switch (side) {
    DdtTipArrowSide.left => Offset(distance, 0),
    DdtTipArrowSide.right => Offset(-distance, 0),
    DdtTipArrowSide.top => Offset(0, distance),
    DdtTipArrowSide.bottom => Offset(0, -distance),
  };
}

Alignment ddtTipScaleAlignment(DdtTipArrowSide side) {
  return switch (side) {
    DdtTipArrowSide.left => Alignment.centerLeft,
    DdtTipArrowSide.right => Alignment.centerRight,
    DdtTipArrowSide.top => Alignment.topCenter,
    DdtTipArrowSide.bottom => Alignment.bottomCenter,
  };
}

double _sideSpace(Rect bounds, Rect anchor, DdtTipArrowSide side) {
  final clearance = _tipGap + ddtTipArrowLength;
  return switch (side) {
    DdtTipArrowSide.left => bounds.right - anchor.right - clearance,
    DdtTipArrowSide.right => anchor.left - bounds.left - clearance,
    DdtTipArrowSide.top => bounds.bottom - anchor.bottom - clearance,
    DdtTipArrowSide.bottom => anchor.top - bounds.top - clearance,
  };
}

DdtTipPlacement? _placeOnSide({
  required Rect bounds,
  required Rect anchor,
  required DdtTipArrowSide side,
  required double preferredWidth,
  required double preferredHeight,
  required bool allowShrink,
}) {
  final clearance = _tipGap + ddtTipArrowLength;
  final minExtent = allowShrink ? 160.0 : 220.0;
  final space = _sideSpace(bounds, anchor, side);
  if (space < minExtent) return null;

  final horizontal =
      side == DdtTipArrowSide.left || side == DdtTipArrowSide.right;
  final width = horizontal
      ? math.min(preferredWidth, space)
      : math.min(preferredWidth, bounds.width);
  final height = horizontal
      ? math.min(preferredHeight, bounds.height)
      : math.min(preferredHeight, space);
  if (width < 140 || height < 160) return null;

  late final double left;
  late final double top;
  switch (side) {
    case DdtTipArrowSide.left:
      left = anchor.right + clearance;
      top = (anchor.center.dy - height / 2).clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - height),
      );
    case DdtTipArrowSide.right:
      left = anchor.left - clearance - width;
      top = (anchor.center.dy - height / 2).clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - height),
      );
    case DdtTipArrowSide.top:
      top = anchor.bottom + clearance;
      left = (anchor.center.dx - width / 2).clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - width),
      );
    case DdtTipArrowSide.bottom:
      top = anchor.top - clearance - height;
      left = (anchor.center.dx - width / 2).clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - width),
      );
  }

  final bubble = Rect.fromLTWH(left, top, width, height);
  if (bubble.overlaps(anchor)) return null;

  final along = switch (side) {
    DdtTipArrowSide.left ||
    DdtTipArrowSide.right => (anchor.center.dy - bubble.top).clamp(
      _tipRadius + _arrowHalf,
      height - _tipRadius - _arrowHalf,
    ),
    DdtTipArrowSide.top ||
    DdtTipArrowSide.bottom => (anchor.center.dx - bubble.left).clamp(
      _tipRadius + _arrowHalf,
      width - _tipRadius - _arrowHalf,
    ),
  };
  final outerRect = switch (side) {
    DdtTipArrowSide.left => Rect.fromLTWH(
      bubble.left - ddtTipArrowLength,
      bubble.top,
      bubble.width + ddtTipArrowLength,
      bubble.height,
    ),
    DdtTipArrowSide.right => Rect.fromLTWH(
      bubble.left,
      bubble.top,
      bubble.width + ddtTipArrowLength,
      bubble.height,
    ),
    DdtTipArrowSide.top => Rect.fromLTWH(
      bubble.left,
      bubble.top - ddtTipArrowLength,
      bubble.width,
      bubble.height + ddtTipArrowLength,
    ),
    DdtTipArrowSide.bottom => Rect.fromLTWH(
      bubble.left,
      bubble.top,
      bubble.width,
      bubble.height + ddtTipArrowLength,
    ),
  };
  return DdtTipPlacement(
    outer: outerRect,
    side: side,
    arrowCenter: along,
    showArrow: true,
  );
}

class DdtArrowTip extends StatelessWidget {
  const DdtArrowTip({
    super.key,
    required this.side,
    required this.arrowCenter,
    required this.showArrow,
    required this.child,
  });

  final DdtTipArrowSide side;
  final double arrowCenter;
  final bool showArrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? DdtTheme.darkSurface : DdtTheme.lightSurface;
    final border = DdtTheme.sidePanelDivider(context);
    final inset = showArrow
        ? switch (side) {
            DdtTipArrowSide.left => const EdgeInsets.only(
              left: ddtTipArrowLength,
            ),
            DdtTipArrowSide.right => const EdgeInsets.only(
              right: ddtTipArrowLength,
            ),
            DdtTipArrowSide.top => const EdgeInsets.only(
              top: ddtTipArrowLength,
            ),
            DdtTipArrowSide.bottom => const EdgeInsets.only(
              bottom: ddtTipArrowLength,
            ),
          }
        : EdgeInsets.zero;

    return CustomPaint(
      painter: _TipShadowPainter(
        side: side,
        arrowCenter: arrowCenter,
        showArrow: showArrow,
        isDark: isDark,
      ),
      foregroundPainter: _TipBorderPainter(
        side: side,
        arrowCenter: arrowCenter,
        showArrow: showArrow,
        color: border,
      ),
      child: ClipPath(
        clipper: _TipClipper(
          side: side,
          arrowCenter: arrowCenter,
          showArrow: showArrow,
        ),
        child: ColoredBox(
          color: fill,
          child: Padding(padding: inset, child: child),
        ),
      ),
    );
  }
}

class _TipClipper extends CustomClipper<Path> {
  const _TipClipper({
    required this.side,
    required this.arrowCenter,
    required this.showArrow,
  });

  final DdtTipArrowSide side;
  final double arrowCenter;
  final bool showArrow;

  @override
  Path getClip(Size size) => _tipPath(size, side, arrowCenter, showArrow);

  @override
  bool shouldReclip(covariant _TipClipper oldClipper) {
    return oldClipper.side != side ||
        oldClipper.arrowCenter != arrowCenter ||
        oldClipper.showArrow != showArrow;
  }
}

class _TipShadowPainter extends CustomPainter {
  const _TipShadowPainter({
    required this.side,
    required this.arrowCenter,
    required this.showArrow,
    required this.isDark,
  });

  final DdtTipArrowSide side;
  final double arrowCenter;
  final bool showArrow;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _tipPath(size, side, arrowCenter, showArrow);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.55 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.35 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant _TipShadowPainter oldDelegate) {
    return oldDelegate.side != side ||
        oldDelegate.arrowCenter != arrowCenter ||
        oldDelegate.showArrow != showArrow ||
        oldDelegate.isDark != isDark;
  }
}

class _TipBorderPainter extends CustomPainter {
  const _TipBorderPainter({
    required this.side,
    required this.arrowCenter,
    required this.showArrow,
    required this.color,
  });

  final DdtTipArrowSide side;
  final double arrowCenter;
  final bool showArrow;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _tipPath(size, side, arrowCenter, showArrow);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TipBorderPainter oldDelegate) {
    return oldDelegate.side != side ||
        oldDelegate.arrowCenter != arrowCenter ||
        oldDelegate.showArrow != showArrow ||
        oldDelegate.color != color;
  }
}

Path _tipPath(
  Size size,
  DdtTipArrowSide side,
  double arrowCenter,
  bool showArrow,
) {
  final bubble = switch (side) {
    DdtTipArrowSide.left when showArrow => Rect.fromLTWH(
      ddtTipArrowLength,
      0,
      size.width - ddtTipArrowLength,
      size.height,
    ),
    DdtTipArrowSide.right when showArrow => Rect.fromLTWH(
      0,
      0,
      size.width - ddtTipArrowLength,
      size.height,
    ),
    DdtTipArrowSide.top when showArrow => Rect.fromLTWH(
      0,
      ddtTipArrowLength,
      size.width,
      size.height - ddtTipArrowLength,
    ),
    DdtTipArrowSide.bottom when showArrow => Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height - ddtTipArrowLength,
    ),
    _ => Offset.zero & size,
  };
  final body = Path()
    ..addRRect(
      RRect.fromRectAndRadius(bubble, const Radius.circular(_tipRadius)),
    );
  if (!showArrow) return body;

  final triangle = Path();
  switch (side) {
    case DdtTipArrowSide.left:
      triangle
        ..moveTo(0, arrowCenter)
        ..lineTo(ddtTipArrowLength + 1.2, arrowCenter - _arrowHalf)
        ..lineTo(ddtTipArrowLength + 1.2, arrowCenter + _arrowHalf)
        ..close();
    case DdtTipArrowSide.right:
      triangle
        ..moveTo(size.width, arrowCenter)
        ..lineTo(size.width - ddtTipArrowLength - 1.2, arrowCenter - _arrowHalf)
        ..lineTo(size.width - ddtTipArrowLength - 1.2, arrowCenter + _arrowHalf)
        ..close();
    case DdtTipArrowSide.top:
      triangle
        ..moveTo(arrowCenter, 0)
        ..lineTo(arrowCenter - _arrowHalf, ddtTipArrowLength + 1.2)
        ..lineTo(arrowCenter + _arrowHalf, ddtTipArrowLength + 1.2)
        ..close();
    case DdtTipArrowSide.bottom:
      triangle
        ..moveTo(arrowCenter, size.height)
        ..lineTo(
          arrowCenter - _arrowHalf,
          size.height - ddtTipArrowLength - 1.2,
        )
        ..lineTo(
          arrowCenter + _arrowHalf,
          size.height - ddtTipArrowLength - 1.2,
        )
        ..close();
  }
  return Path.combine(PathOperation.union, body, triangle);
}
