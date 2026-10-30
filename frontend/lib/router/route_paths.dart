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
  static const tasksArchive = '/tasks/archive';
  static const tasksNew = '/tasks/new';
  static const taskDetails = '/tasks/:taskKey';

  static String task(String taskKey) => '/tasks/$taskKey';

  static String taskEdit(String taskKey) => '/tasks/$taskKey/edit';

  static String spaceTaskEdit(String taskKey) => '/space/$taskKey/edit';

  /// Полный URL редактирования: личная задача или задача пространства.
  static String forTaskEdit({
    required String taskKey,
    int? spaceId,
    String? spaceKey,
  }) {
    if (taskKey.isEmpty) return tasksList;
    final inSpace =
        spaceId != null || (spaceKey != null && spaceKey.isNotEmpty);
    return inSpace ? spaceTaskEdit(taskKey) : taskEdit(taskKey);
  }

  /// Полный URL задачи: личная — `/tasks/<username>-id`, пространство — `/space/<spacekey>-id`.
  static String forTask({
    required String taskKey,
    int? spaceId,
    String? spaceKey,
  }) {
    if (taskKey.isEmpty) return tasksList;
    final inSpace =
        spaceId != null || (spaceKey != null && spaceKey.isNotEmpty);
    return inSpace ? spaceTask(taskKey) : task(taskKey);
  }

  static const mail = '/mail';
  static const mailNew = '/mail/new';
  static const calendar = '/calendar';
  static const calendarNew = '/calendar/new';
  static const contacts = '/contacts';
  static const analytics = '/analytics';
  static const settings = '/settings';
  static const space = '/space';
  static const spaceRef = '/space/:spaceKey';
  static const spaceKanban = '/space/:spaceKey/kanban';
  static const spaceList = '/space/:spaceKey/list';
  static const spaceGantt = '/space/:spaceKey/gantt';
  static const spaceArchive = '/space/:spaceKey/archive';
  static const defaultSpaceKey = 'TEST';

  static String spaceKanbanFor(String spaceKey) => '/space/$spaceKey/kanban';
  static String spaceListFor(String spaceKey) => '/space/$spaceKey/list';
  static String spaceGanttFor(String spaceKey) => '/space/$spaceKey/gantt';
  static String spaceArchiveFor(String spaceKey) => '/space/$spaceKey/archive';
  static String spaceTask(String taskKey) => '/space/$taskKey';
  static String spaceTaskNew(String spaceKey) => '/space/$spaceKey/new';
  static const notes = '/notes';
  static const note = '/notes/:noteId';

  static String notesAt({String? folderId}) {
    if (folderId == null || folderId.isEmpty) return notes;
    return '$notes?folder=${Uri.encodeQueryComponent(folderId)}';
  }

  static String noteFor(String noteId, {String? folderId}) {
    final path = '$notes/$noteId';
    if (folderId == null || folderId.isEmpty) return path;
    return '$path?folder=${Uri.encodeQueryComponent(folderId)}';
  }

  static const boards = '/boards';
  static const board = '/boards/:boardId';
  static const more = '/more';

  static String boardFor(String boardId) => '/boards/$boardId';

  /// Legacy path; redirects to [notes].
  static const linkArchive = '/link-archive';

  static final taskKeyPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*-\d+$');
  static const reservedTaskSegments = {
    'kanban',
    'list',
    'gantt',
    'archive',
    'new',
  };

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
  static const nameTasksArchive = 'tasks-archive';
  static const nameTaskDetails = 'task-details';
  static const nameTaskCreate = 'task-create';
  static const nameTaskEdit = 'task-edit';
  static const nameMail = 'mail';
  static const nameMailNew = 'mail-new';
  static const nameCalendar = 'calendar';
  static const nameCalendarNew = 'calendar-new';
  static const nameContacts = 'contacts';
  static const nameAnalytics = 'analytics';
  static const nameSettings = 'settings';
  static const nameSpace = 'space';
  static const nameSpaceKanban = 'space-kanban';
  static const nameSpaceList = 'space-list';
  static const nameSpaceGantt = 'space-gantt';
  static const nameSpaceArchive = 'space-archive';
  static const nameSpaceTaskDetails = 'space-task-details';
  static const nameSpaceTaskCreate = 'space-task-create';
  static const nameSpaceTaskEdit = 'space-task-edit';
  static const nameNotes = 'notes';
  static const nameNote = 'note';
  static const nameBoards = 'boards';
  static const nameBoard = 'board';
  static const nameMore = 'more';

  /// Legacy route name; redirects to [nameNotes].
  static const nameLinkArchive = 'link-archive';

  static bool isKanbanRoute(String location) => location.endsWith('/kanban');

  static bool isArchiveRoute(String location) => location.endsWith('/archive');

  /// Kanban, list, gantt, or archive. Task pages are not a board.
  static bool isTasksBoardRoute(String location) {
    return location.endsWith('/kanban') ||
        location.endsWith('/list') ||
        location.endsWith('/gantt') ||
        location.endsWith('/archive');
  }
}
