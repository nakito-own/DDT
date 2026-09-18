/// Константы маршрутов приложения.
///
/// Все пути и имена маршрутов определены здесь как единая точка истины.
/// Это исключает опечатки при навигации и упрощает рефакторинг маршрутов.
abstract final class RoutePaths {
  // ─── Публичные маршруты ────────────────────────────────────────────────────

  static const login = '/login';

  // ─── Разделы основной оболочки ────────────────────────────────────────────

  static const tasks = '/tasks';
  static const tasksKanban = '/tasks/kanban';
  static const tasksList = '/tasks/list';
  static const tasksGantt = '/tasks/gantt';
  static const taskDetails = '/tasks/:taskKey';

  static String task(String taskKey) => '/tasks/$taskKey';

  /// Полный URL задачи: личная — `/tasks/<username>-id`, пространство — `/space/<spacekey>-id`.
  static String forTask({required String taskKey, int? spaceId, String? spaceKey}) {
    if (taskKey.isEmpty) return tasksList;
    final inSpace = spaceId != null || (spaceKey != null && spaceKey.isNotEmpty);
    return inSpace ? spaceTask(taskKey) : task(taskKey);
  }

  static const mail = '/mail';
  static const calendar = '/calendar';
  static const contacts = '/contacts';
  static const analytics = '/analytics';
  static const settings = '/settings';
  static const space = '/space';
  static const spaceRef = '/space/:spaceKey';
  static const spaceKanban = '/space/:spaceKey/kanban';
  static const spaceList = '/space/:spaceKey/list';
  static const spaceGantt = '/space/:spaceKey/gantt';
  static const defaultSpaceKey = 'TEST';

  static String spaceKanbanFor(String spaceKey) => '/space/$spaceKey/kanban';
  static String spaceListFor(String spaceKey) => '/space/$spaceKey/list';
  static String spaceGanttFor(String spaceKey) => '/space/$spaceKey/gantt';
  static String spaceTask(String taskKey) => '/space/$taskKey';
  static const automations = '/automations';
  static const notes = '/notes';

  /// Legacy path; redirects to [notes].
  static const linkArchive = '/link-archive';

  static final taskKeyPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*-\d+$');
  static const reservedTaskSegments = {'kanban', 'list', 'gantt'};

  static bool isTaskKey(String value) => taskKeyPattern.hasMatch(value);

  static bool isReservedTaskSegment(String value) =>
      reservedTaskSegments.contains(value);

  static String spaceKeyFromTaskKey(String taskKey) {
    final separator = taskKey.lastIndexOf('-');
    if (separator <= 0) return taskKey;
    return taskKey.substring(0, separator);
  }

  // ─── Имена маршрутов (для context.goNamed) ────────────────────────────────

  static const nameLogin = 'login';
  static const nameTasksKanban = 'tasks-kanban';
  static const nameTasksList = 'tasks-list';
  static const nameTasksGantt = 'tasks-gantt';
  static const nameTaskDetails = 'task-details';
  static const nameMail = 'mail';
  static const nameCalendar = 'calendar';
  static const nameContacts = 'contacts';
  static const nameAnalytics = 'analytics';
  static const nameSettings = 'settings';
  static const nameSpace = 'space';
  static const nameSpaceKanban = 'space-kanban';
  static const nameSpaceList = 'space-list';
  static const nameSpaceGantt = 'space-gantt';
  static const nameSpaceTaskDetails = 'space-task-details';
  static const nameAutomations = 'automations';
  static const nameNotes = 'notes';

  /// Legacy route name; redirects to [nameNotes].
  static const nameLinkArchive = 'link-archive';

  static bool isKanbanRoute(String location) => location.endsWith('/kanban');
}
