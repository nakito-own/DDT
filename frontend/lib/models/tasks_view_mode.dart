import '../router/route_paths.dart';

enum TasksViewMode {
  kanban('Канбан'),
  list('Список'),
  gantt('Гант');

  const TasksViewMode(this.label);

  final String label;

  /// URL-путь этого режима просмотра для GoRouter.
  String get routePath => switch (this) {
    TasksViewMode.kanban => RoutePaths.tasksKanban,
    TasksViewMode.list => RoutePaths.tasksList,
    TasksViewMode.gantt => RoutePaths.tasksGantt,
  };

  String routePathForSpace(String spaceKey) => switch (this) {
    TasksViewMode.kanban => RoutePaths.spaceKanbanFor(spaceKey),
    TasksViewMode.list => RoutePaths.spaceListFor(spaceKey),
    TasksViewMode.gantt => RoutePaths.spaceGanttFor(spaceKey),
  };

  /// Определяет активный режим по текущему URL-пути.
  static TasksViewMode fromRoute(String location) {
    if (location.endsWith('/kanban')) return TasksViewMode.kanban;
    if (location.endsWith('/gantt')) return TasksViewMode.gantt;
    return TasksViewMode.list;
  }
}
