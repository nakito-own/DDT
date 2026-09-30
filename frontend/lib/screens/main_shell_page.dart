import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_section.dart';
import '../router/route_paths.dart';
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
    final location = GoRouterState.of(context).matchedLocation;

    return DdtShellLayout(
      title: selectedSection.label,
      selectedSection: selectedSection,
      onSectionSelected: (section) => context.go(section.routePath),
      padContent: !RoutePaths.isKanbanRoute(location),
      child: child,
    );
  }
}
