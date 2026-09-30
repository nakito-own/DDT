import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';

/// Scales and fades section content while a shimmer plays over it.
class DdtSectionRefreshOverlay extends StatelessWidget {
  const DdtSectionRefreshOverlay({
    super.key,
    required this.isRefreshing,
    required this.child,
  });

  final bool isRefreshing;
  final Widget child;

  static const double _refreshScale = 0.97;
  static const double _refreshOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: isRefreshing,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedScale(
              scale: isRefreshing ? _refreshScale : 1,
              duration: DdtTheme.refreshContentDuration,
              curve: DdtTheme.selectionAnimationCurve,
              child: AnimatedOpacity(
                opacity: isRefreshing ? _refreshOpacity : 1,
                duration: DdtTheme.refreshContentDuration,
                curve: DdtTheme.selectionAnimationCurve,
                child: child,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DdtShimmerSweep(visible: isRefreshing),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-color sweeping gradient used for refresh and skeleton loading.
class DdtShimmerSweep extends StatefulWidget {
  const DdtShimmerSweep({super.key, required this.visible});

  final bool visible;

  @override
  State<DdtShimmerSweep> createState() => _DdtShimmerSweepState();
}

class _DdtShimmerSweepState extends State<DdtShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DdtTheme.refreshShimmerDuration,
    );
    if (widget.visible) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DdtShimmerSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    if (_controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      opacity: widget.visible ? 1 : 0,
      duration: DdtTheme.refreshContentDuration,
      curve: DdtTheme.selectionAnimationCurve,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _IridescentShimmerPainter(
              progress: _controller.value,
              color: AppColors.primary,
              isDark: isDark,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _IridescentShimmerPainter extends CustomPainter {
  const _IridescentShimmerPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  final double progress;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bandWidth = size.width * 0.78;
    final travel = size.width + bandWidth * 2;
    final x = -bandWidth + travel * progress;
    final skew = size.height * 0.32;

    final band = Rect.fromLTWH(
      x - skew,
      -size.height * 0.25,
      bandWidth,
      size.height * 1.5,
    );

    final peakAlpha = isDark ? 0.1 : 0.08;
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: peakAlpha * 0.25),
        color.withValues(alpha: peakAlpha * 0.55),
        color.withValues(alpha: peakAlpha),
        color.withValues(alpha: peakAlpha * 0.55),
        color.withValues(alpha: peakAlpha * 0.25),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.18, 0.34, 0.5, 0.66, 0.82, 1.0],
    ).createShader(band);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.skew(-0.28, 0);
    canvas.drawRect(
      band,
      Paint()
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IridescentShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}
