import 'package:flutter/material.dart';

/// Появление полноэкранной сущности поверх раздела.
///
/// Как у Material: новая страница въезжает справа, предыдущая чуть
/// уезжает влево. Прозрачность та же, что и раньше, поэтому фото фона
/// просвечивает. Сдвиг и opacity живут на композиторе, без размытия.
class DdtFullscreenTransition extends StatelessWidget {
  const DdtFullscreenTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  static const Duration duration = Duration(milliseconds: 340);
  static const Duration reverseDuration = Duration(milliseconds: 260);

  /// Доля ширины, на которую страница въезжает. Как у Material Fade Forwards.
  static const double enterTravel = 0.25;

  @override
  Widget build(BuildContext context) {
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return DdtCoveredFade(
      animation: secondaryAnimation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final opacity = _smooth(animation.value);
          if (opacity >= 0.999) return child!;
          return FractionalTranslation(
            translation: Offset(sign * enterTravel * (1 - opacity), 0),
            child: Opacity(opacity: opacity, child: child),
          );
        },
        child: child,
      ),
    );
  }
}

/// Растворяет экран, который остаётся под открывающейся страницей,
/// и слегка сдвигает его в сторону, противоположную въезду.
class DdtCoveredFade extends StatelessWidget {
  const DdtCoveredFade({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  static const double leaveTravel = 0.12;

  @override
  Widget build(BuildContext context) {
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = _smooth(animation.value);
        if (t <= 0.001) return child!;
        // Уходит чуть раньше входящего, чтобы к концу кадра его уже не было.
        final leave = (t / 0.85).clamp(0.0, 1.0);
        return FractionalTranslation(
          translation: Offset(-sign * leaveTravel * leave, 0),
          child: Opacity(opacity: 1 - leave, child: child),
        );
      },
      child: child,
    );
  }
}

double _smooth(double t) {
  return Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
}
