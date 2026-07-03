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

  /// Определяет активный режим по текущему URL-пути.
  static TasksViewMode fromRoute(String location) {
    if (location.contains('/tasks/list')) return TasksViewMode.list;
    if (location.contains('/tasks/gantt')) return TasksViewMode.gantt;
    return TasksViewMode.kanban;
  }
}
