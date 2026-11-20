import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/app_section.dart';
import '../models/tasks_view_mode.dart';
import '../router/route_paths.dart';

/// Открывает раздел. Задачи и пространство возвращаются на сохранённый вид.
void openAppSection(BuildContext context, AppSection section) {
  final tasks = context.read<TasksBloc>();
  switch (section) {
    case AppSection.tasks:
      final location = GoRouterState.of(context).uri.path;
      final mode =
          TasksViewMode.boardModeFromRoute(location) ?? tasks.state.viewMode;
      context.go(mode.routePath);
    case AppSection.space:
      final location = GoRouterState.of(context).uri.path;
      final onSpace = AppSection.fromRoute(location) == AppSection.space;
      final mode = onSpace
          ? (TasksViewMode.boardModeFromRoute(location) ??
                tasks.state.spaceViewMode)
          : tasks.state.spaceViewMode;
      final spaceKey = onSpace
          ? (_spaceKeyFromLocation(location) ??
                tasks.state.activeSpaceKey ??
                RoutePaths.defaultSpaceKey)
          : (tasks.state.activeSpaceKey ?? RoutePaths.defaultSpaceKey);
      context.go(mode.routePathForSpace(spaceKey));
    default:
      context.go(section.routePath);
  }
}

String? _spaceKeyFromLocation(String location) {
  final board = RegExp(
    r'^/space/([^/]+)/(kanban|list|gantt|archive)$',
  ).firstMatch(location);
  if (board != null) return board.group(1);
  final task = RegExp(r'^/space/(.+)-\d+$').firstMatch(location);
  return task?.group(1);
}
