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
  static const taskDetails = '/tasks/:taskId';

  static String task(int taskId) => '/tasks/$taskId';

  static const mail = '/mail';
  static const calendar = '/calendar';
  static const contacts = '/contacts';
  static const settings = '/settings';
  static const space = '/space';
  static const spaceRoot = '/space/:spaceId';
  static const spaceKanban = '/space/:spaceId/kanban';
  static const spaceList = '/space/:spaceId/list';
  static const spaceGantt = '/space/:spaceId/gantt';
  static const spaceTaskDetails = '/space/:spaceId/tasks/:taskId';

  static String spaceKanbanFor(int spaceId) => '/space/$spaceId/kanban';
  static String spaceListFor(int spaceId) => '/space/$spaceId/list';
  static String spaceGanttFor(int spaceId) => '/space/$spaceId/gantt';
  static String spaceTask(int spaceId, int taskId) =>
      '/space/$spaceId/tasks/$taskId';
  static const automations = '/automations';
  static const linkArchive = '/link-archive';

  // ─── Имена маршрутов (для context.goNamed) ────────────────────────────────

  static const nameLogin = 'login';
  static const nameTasksKanban = 'tasks-kanban';
  static const nameTasksList = 'tasks-list';
  static const nameTasksGantt = 'tasks-gantt';
  static const nameTaskDetails = 'task-details';
  static const nameMail = 'mail';
  static const nameCalendar = 'calendar';
  static const nameContacts = 'contacts';
  static const nameSettings = 'settings';
  static const nameSpace = 'space';
  static const nameSpaceKanban = 'space-kanban';
  static const nameSpaceList = 'space-list';
  static const nameSpaceGantt = 'space-gantt';
  static const nameSpaceTaskDetails = 'space-task-details';
  static const nameAutomations = 'automations';
  static const nameLinkArchive = 'link-archive';
}
