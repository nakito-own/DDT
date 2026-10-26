import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_section.dart';
import '../models/tasks_view_mode.dart';
import '../widgets/ddt_shell_layout.dart';

/// Оболочка основного приложения: навигационный рейл + аппбар + контент.
///
/// Является shell-виджетом для внешнего [ShellRoute] в GoRouter.
/// Активная секция определяется из URL через [selectedSection],
/// который вычисляется в [app_router.dart] по [GoRouterState.matchedLocation].
///
/// Переходы между секциями выполняются через [context.go],
/// что обновляет URL и историю браузера.
class MainShellPage extends StatelessWidget {
  const MainShellPage({
    super.key,
    required this.selectedSection,
    required this.child,
  });

  final AppSection selectedSection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // uri.path is the open page. A task pushed from kanban must keep the
    // kanban shell slot: switching padding here jumps the whole content area.
    final location = GoRouterState.of(context).uri.path;
    final board = TasksViewMode.fromRoute(location);

    return DdtShellLayout(
      title: selectedSection.label,
      selectedSection: selectedSection,
      onSectionSelected: (section) => context.go(section.routePath),
      padContent: board != TasksViewMode.kanban,
      child: child,
    );
  }
}
