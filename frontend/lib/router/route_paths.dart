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

  static const mail = '/mail';
  static const calendar = '/calendar';
  static const contacts = '/contacts';
  static const settings = '/settings';
  static const space = '/space';
  static const automations = '/automations';
  static const linkArchive = '/link-archive';

  // ─── Имена маршрутов (для context.goNamed) ────────────────────────────────

  static const nameLogin = 'login';
  static const nameTasksKanban = 'tasks-kanban';
  static const nameTasksList = 'tasks-list';
  static const nameTasksGantt = 'tasks-gantt';
  static const nameMail = 'mail';
  static const nameCalendar = 'calendar';
  static const nameContacts = 'contacts';
  static const nameSettings = 'settings';
  static const nameSpace = 'space';
  static const nameAutomations = 'automations';
  static const nameLinkArchive = 'link-archive';
}
