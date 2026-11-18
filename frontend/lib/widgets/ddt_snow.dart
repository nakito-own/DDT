import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/theme/theme_bloc.dart';

/// Сезонное оформление. Поставьте `false`, чтобы убрать снег.
const bool ddtSnowEnabled = true;

/// Падающие снежинки. [back] — слой над фоном: крупнее, медленнее и слегка размыт.
class DdtSnowLayer extends StatefulWidget {
  const DdtSnowLayer({super.key, required this.back});

  final bool back;

  @override
  State<DdtSnowLayer> createState() => _DdtSnowLayerState();
}

class _Flake {
  const _Flake({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.spin,
    required this.sway,
    required this.swaySpeed,
    required this.phase,
    required this.opacity,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double spin;
  final double sway;
  final double swaySpeed;
  final double phase;
  final double opacity;
}

class _SnowClock extends ChangeNotifier {
  Duration elapsed = Duration.zero;

  void advance(Duration value) {
    elapsed = value;
    notifyListeners();
  }
}

class _DdtSnowLayerState extends State<DdtSnowLayer>
    with SingleTickerProviderStateMixin {
  late final List<_Flake> _flakes = _makeFlakes(widget.back);
  final _clock = _SnowClock();
  Ticker? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (animate && _ticker == null) {
      _ticker = createTicker(_clock.advance)..start();
    } else if (!animate && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
      _clock.advance(Duration.zero);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paint = CustomPaint(
      painter: _SnowPainter(
        clock: _clock,
        flakes: _flakes,
        color: isDark ? const Color(0xFFA7B0BE) : Colors.white,
        opacityScale: isDark ? 0.72 : 2.35,
      ),
      child: const SizedBox.expand(),
    );
    if (!widget.back) return paint;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
      child: paint,
    );
  }
}

List<_Flake> _makeFlakes(bool back) {
  final random = math.Random(back ? 7 : 21);
  final count = back ? 28 : 42;
  return [
    for (var i = 0; i < count; i++)
      _Flake(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: back ? 5 + random.nextDouble() * 4 : 3 + random.nextDouble() * 3,
        speed: back
            ? 0.018 + random.nextDouble() * 0.02
            : 0.035 + random.nextDouble() * 0.045,
        spin: (random.nextBool() ? 1 : -1) * (0.35 + random.nextDouble() * 0.85),
        sway: 0.012 + random.nextDouble() * (back ? 0.02 : 0.035),
        swaySpeed: 0.4 + random.nextDouble() * 0.8,
        phase: random.nextDouble() * math.pi * 2,
        opacity: back
            ? 0.16 + random.nextDouble() * 0.12
            : 0.26 + random.nextDouble() * 0.16,
      ),
  ];
}

/// Снежинка радиусом 1: шестиугольник в центре, два яруса веток и кант на кончике.
final Path _snowflakePath = _buildSnowflake();

Path _buildSnowflake() {
  final path = Path();
  const radius = 1.0;
  const hub = 0.11;
  for (var side = 0; side < 6; side++) {
    final angle = side * math.pi / 3 - math.pi / 2;
    final x = math.cos(angle) * hub;
    final y = math.sin(angle) * hub;
    if (side == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();

  for (var arm = 0; arm < 6; arm++) {
    final angle = arm * math.pi / 3 - math.pi / 2;
    final tipX = math.cos(angle) * radius;
    final tipY = math.sin(angle) * radius;
    path.moveTo(0, 0);
    path.lineTo(tipX, tipY);

    const tipInset = 0.18;
    const tipSpread = 0.16;
    final neckX = math.cos(angle) * (radius - tipInset);
    final neckY = math.sin(angle) * (radius - tipInset);
    for (final side in [1.0, -1.0]) {
      path.moveTo(tipX, tipY);
      path.lineTo(
        neckX + math.cos(angle + side * math.pi / 2) * tipSpread,
        neckY + math.sin(angle + side * math.pi / 2) * tipSpread,
      );
    }

    for (final station in [0.4, 0.7]) {
      final originX = math.cos(angle) * radius * station;
      final originY = math.sin(angle) * radius * station;
      final length = station == 0.4 ? 0.22 : 0.34;
      for (final turn in [0.9, -0.9]) {
        final branchAngle = angle + turn;
        final endX = originX + math.cos(branchAngle) * length;
        final endY = originY + math.sin(branchAngle) * length;
        path.moveTo(originX, originY);
        path.lineTo(endX, endY);
        if (station == 0.7) {
          final midX = originX + math.cos(branchAngle) * length * 0.58;
          final midY = originY + math.sin(branchAngle) * length * 0.58;
          final twigAngle = branchAngle + (turn > 0 ? 0.75 : -0.75);
          path.moveTo(midX, midY);
          path.lineTo(
            midX + math.cos(twigAngle) * 0.13,
            midY + math.sin(twigAngle) * 0.13,
          );
        }
      }
    }
  }
  return path;
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({
    required this.clock,
    required this.flakes,
    required this.color,
    required this.opacityScale,
  }) : super(repaint: clock);

  final _SnowClock clock;
  final List<_Flake> flakes;
  final Color color;
  final double opacityScale;
  final Path _flake = _snowflakePath;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final seconds = clock.elapsed.inMicroseconds / 1000000;
    final span = size.height + 48;
    for (final flake in flakes) {
      final distance = (flake.y * span + seconds * flake.speed * span) % span;
      final y = distance - 24;
      final x =
          (flake.x +
              math.sin(seconds * flake.swaySpeed + flake.phase) * flake.sway) *
          size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(seconds * flake.spin + flake.phase);
      canvas.scale(flake.size);
      _stroke
        ..color = color.withValues(
          alpha: (flake.opacity * opacityScale).clamp(0, 1),
        )
        ..strokeWidth = 0.1;
      canvas.drawPath(_flake, _stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) {
    return oldDelegate.flakes != flakes ||
        oldDelegate.color != color ||
        oldDelegate.opacityScale != opacityScale;
  }
}

/// Тонкий белый сугроб по верхнему краю аппбара.
class DdtAppBarSnow extends StatelessWidget {
  const DdtAppBarSnow({super.key});

  static const double height = 12;

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<ThemeBloc, bool>(
      (bloc) => bloc.state.snowEnabled,
    );
    if (!ddtSnowEnabled || !enabled) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0x59FFFFFF) : const Color(0xCC5279C7);
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _AppBarSnowPainter(color)),
      ),
    );
  }
}

class _AppBarSnowPainter extends CustomPainter {
  const _AppBarSnowPainter(this.color);

  final Color color;

  static const List<double> _mounds = [
    4.5, 8, 5, 10, 6.5, 9, 4, 7.5, 11, 5.5, 8.5, 4.2, 7, 9.5, 5,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = Path()..moveTo(0, 0)..lineTo(0, 1.6);
    final step = size.width / _mounds.length;
    for (var i = 0; i < _mounds.length; i++) {
      final next = step * (i + 1);
      final crest = _mounds[i].clamp(2.0, size.height);
      path.quadraticBezierTo(step * i + step * 0.55, crest, next, i.isEven ? 2 : 3);
    }
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AppBarSnowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
