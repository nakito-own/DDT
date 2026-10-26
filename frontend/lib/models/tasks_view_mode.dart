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

  static TasksViewMode _board = TasksViewMode.list;

  /// Режим доски по адресу. Карточка и создание задачи адреса доски не имеют,
  /// поэтому остаётся последняя открытая доска, а не список по умолчанию.
  static TasksViewMode? boardFromRoute(String location) {
    if (location.endsWith('/kanban')) return TasksViewMode.kanban;
    if (location.endsWith('/gantt')) return TasksViewMode.gantt;
    if (location.endsWith('/list') || location.endsWith('/archive')) {
      return TasksViewMode.list;
    }
    return null;
  }

  /// Активный режим: доска из адреса либо та, с которой открыли задачу.
  static TasksViewMode fromRoute(String location) {
    final board = boardFromRoute(location);
    if (board != null) {
      _board = board;
      return board;
    }
    return _board;
  }
}
