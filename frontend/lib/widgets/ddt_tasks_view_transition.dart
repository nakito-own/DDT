import 'package:flutter/material.dart';

import '../models/tasks_view_mode.dart';
import '../theme/ddt_theme.dart';

/// Смена вида задач: канбан, список или гант.
///
/// В дереве остаётся только новый вид. Карточка задачи и архив приходят
/// с [mode] == null и появляются без этой анимации.
class DdtTasksViewTransition extends StatefulWidget {
  const DdtTasksViewTransition({
    super.key,
    required this.mode,
    required this.child,
  });

  final TasksViewMode? mode;
  final Widget child;

  static const Duration duration = Duration(milliseconds: 220);
  static const double travel = 0.08;

  @override
  State<DdtTasksViewTransition> createState() => _DdtTasksViewTransitionState();
}

class _DdtTasksViewTransitionState extends State<DdtTasksViewTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DdtTasksViewTransition.duration,
    value: 1,
  );

  /// +1 — следующий вид въезжает справа, −1 — предыдущий слева.
  int _direction = 1;

  @override
  void didUpdateWidget(DdtTasksViewTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.mode;
    final previous = oldWidget.mode;
    if (next == null || previous == null || next == previous) {
      if (next != previous) _controller.value = 1;
      return;
    }

    _direction = next.index >= previous.index ? 1 : -1;
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
          final sliding = FractionalTranslation(
            translation: Offset(
              _direction * (1 - t) * DdtTasksViewTransition.travel,
              0,
            ),
            child: child,
          );

          // Колонки канбана блюрят фон через BackdropFilter. Opacity
          // собирает страницу в отдельный слой, фильтр его не видит и
          // колонки остаются плоской заливкой, пока слой не снимется
          // в конце анимации. Вуаль того же цвета, что и фон, прячет
          // уже готовое стекло и не изолирует фильтр. Страница остаётся
          // в том же Stack и после анимации, чтобы фильтр не пересоздавался.
          if (widget.mode == TasksViewMode.kanban) {
            return Stack(
              fit: StackFit.expand,
              children: [
                sliding,
                if (t < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: DdtTheme.scaffoldBackground(
                          context,
                        ).withValues(alpha: 1 - t),
                      ),
                    ),
                  ),
              ],
            );
          }

          if (t >= 1) return sliding;
          return Opacity(opacity: t, child: sliding);
        },
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
