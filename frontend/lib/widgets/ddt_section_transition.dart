import 'package:flutter/material.dart';

import '../models/app_section.dart';

/// Лёгкая смена раздела: входящая страница слегка сдвигается и проявляется.
///
/// В дереве остаётся только новый раздел. Исходящая страница не держится
/// рядом, чтобы не рисовать второй набор стеклянных поверхностей.
/// Рейл и шапка живут вне этого виджета и не анимируются.
///
/// Переходы внутри одного раздела (канбан, список, карточка задачи)
/// ключ не меняют и проходят без анимации.
class DdtSectionTransition extends StatefulWidget {
  const DdtSectionTransition({
    super.key,
    required this.section,
    required this.child,
  });

  final AppSection section;
  final Widget child;

  static const Duration duration = Duration(milliseconds: 220);

  /// Доля ширины, на которую страница въезжает. Малый сдвиг остаётся
  /// на композиторе и не двигает вёрстку.
  static const double travel = 0.08;

  @override
  State<DdtSectionTransition> createState() => _DdtSectionTransitionState();
}

class _DdtSectionTransitionState extends State<DdtSectionTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DdtSectionTransition.duration,
    value: 1,
  );

  /// +1 — следующий раздел въезжает справа, −1 — предыдущий слева.
  int _direction = 1;

  @override
  void didUpdateWidget(DdtSectionTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section == widget.section) return;

    _direction = widget.section.index >= oldWidget.section.index ? 1 : -1;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          return FractionalTranslation(
            translation: Offset(
              _direction * (1 - t) * DdtSectionTransition.travel,
              0,
            ),
            child: Opacity(opacity: t, child: child),
          );
        },
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
