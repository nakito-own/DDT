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

  String routePathForSpace(int spaceId) => switch (this) {
    TasksViewMode.kanban => RoutePaths.spaceKanbanFor(spaceId),
    TasksViewMode.list => RoutePaths.spaceListFor(spaceId),
    TasksViewMode.gantt => RoutePaths.spaceGanttFor(spaceId),
  };

  /// Определяет активный режим по текущему URL-пути.
  static TasksViewMode fromRoute(String location) {
    if (location.endsWith('/list')) return TasksViewMode.list;
    if (location.endsWith('/gantt')) return TasksViewMode.gantt;
    return TasksViewMode.kanban;
  }
}
