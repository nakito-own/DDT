import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../models/app_section.dart';
import '../screens/additions_page.dart';
import '../screens/board_editor_page.dart';
import '../screens/boards_page.dart';
import '../screens/analytics_page.dart';
import '../screens/calendar_page.dart';
import '../screens/event_create_page.dart';
import '../screens/contacts_page.dart';
import '../screens/ews_login_screen.dart';
import '../screens/kanban_board_page.dart';
import '../screens/mail_page.dart';
import '../screens/main_shell_page.dart';
import '../screens/settings_page.dart';
import '../screens/task_create_page.dart';
import '../screens/task_details_page.dart';
import '../screens/tasks_gantt_page.dart';
import '../screens/tasks_list_page.dart';
import '../screens/tasks_shell_page.dart';
import '../services/tasks_api.dart';
import '../theme/ddt_theme.dart';
import '../widgets/ddt_section_transition.dart';
import 'route_paths.dart';

/// Создаёт и возвращает настроенный [GoRouter].
///
/// [authBloc] должен быть тем же экземпляром, который предоставлен
/// через [BlocProvider] в дереве виджетов. Это гарантирует, что redirect
/// и виджеты читают одно и то же состояние.
AppRouter createAppRouter(AuthBloc authBloc) {
  final notifier = _AuthRouterNotifier(authBloc);

  final router = GoRouter(
    initialLocation: RoutePaths.tasksList,
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = notifier.isAuthenticated;
      final isLoginRoute = state.matchedLocation == RoutePaths.login;

      // Неавторизованный пользователь → всегда на логин
      if (!isAuthenticated && !isLoginRoute) return RoutePaths.login;

      // Авторизованный пользователь на логине → в приложение
      if (isAuthenticated && isLoginRoute) return RoutePaths.tasksList;

      return null;
    },
    routes: [
      // ─── Публичный маршрут ─────────────────────────────────────────────────
      // Для логина используем fade — переход между логином и приложением
      // должен быть плавным.
      GoRoute(
        path: RoutePaths.login,
        name: RoutePaths.nameLogin,
        pageBuilder: (context, state) =>
            _buildFadePage(key: state.pageKey, child: const EwsLoginScreen()),
      ),

      // ─── Защищённые маршруты: внешняя оболочка с DdtShellLayout ───────────
      // pageBuilder с NoTransitionPage не анимирует сам шелл:
      // рейл и аппбар остаются на месте. Смена раздела анимируется
      // только в области контента, см. [DdtSectionTransition].
      ShellRoute(
        pageBuilder: (context, state, child) {
          final section = AppSection.fromRoute(state.matchedLocation);
          return NoTransitionPage(
            child: MainShellPage(selectedSection: section, child: child),
          );
        },
        routes: [
          GoRoute(
            path: RoutePaths.tasks,
            redirect: (context, state) {
              if (state.uri.path == RoutePaths.tasks) {
                return RoutePaths.tasksList;
              }
              return null;
            },
            routes: [
              // ── Внутренняя оболочка задач с TasksShellPage ─────────────────
              // ShellRoute сохраняет TasksShellPage живым при переключении
              // между kanban/list/gantt (initState не вызывается повторно).
              ShellRoute(
                pageBuilder: (context, state, child) =>
                    NoTransitionPage(child: TasksShellPage(child: child)),
                routes: [
                  GoRoute(
                    path: 'kanban',
                    name: RoutePaths.nameTasksKanban,
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const KanbanBoardPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'list',
                    name: RoutePaths.nameTasksList,
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const TasksListPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'gantt',
                    name: RoutePaths.nameTasksGantt,
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const TasksGanttPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'new',
                    name: RoutePaths.nameTaskCreate,
                    pageBuilder: (context, state) => _buildRevealPage(
                      key: state.pageKey,
                      child: const TaskCreatePage(),
                    ),
                  ),
                  GoRoute(
                    path: 'archive',
                    name: RoutePaths.nameTasksArchive,
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: BlocProvider(
                        create: (_) =>
                            TasksBloc(archivedOnly: true)
                              ..add(const TasksBoardLoadRequested()),
                        child: const TasksListPage(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':taskKey',
                    name: RoutePaths.nameTaskDetails,
                    pageBuilder: (context, state) {
                      final taskKey = state.pathParameters['taskKey'] ?? '';
                      return _buildTaskOpenPage(
                        key: state.pageKey,
                        child:
                            taskKey.isEmpty ||
                                RoutePaths.isReservedTaskSegment(taskKey)
                            ? const _NotFoundPage()
                            : TaskDetailsPage(taskKey: taskKey),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          GoRoute(
            path: RoutePaths.mail,
            name: RoutePaths.nameMail,
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: const MailPage()),
          ),
          GoRoute(
            path: RoutePaths.calendarNew,
            name: RoutePaths.nameCalendarNew,
            pageBuilder: (context, state) => _buildRevealPage(
              key: state.pageKey,
              child: const EventCreatePage(),
            ),
          ),
          GoRoute(
            path: RoutePaths.calendar,
            name: RoutePaths.nameCalendar,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CalendarPage(),
            ),
          ),
          GoRoute(
            path: RoutePaths.contacts,
            name: RoutePaths.nameContacts,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ContactsPage(),
            ),
          ),
          GoRoute(
            path: RoutePaths.analytics,
            name: RoutePaths.nameAnalytics,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AnalyticsPage(),
            ),
          ),
          GoRoute(
            path: RoutePaths.settings,
            name: RoutePaths.nameSettings,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
          ),
          GoRoute(
            path: RoutePaths.space,
            name: RoutePaths.nameSpace,
            redirect: (context, state) =>
                RoutePaths.spaceListFor(RoutePaths.defaultSpaceKey),
          ),
          GoRoute(
            path: RoutePaths.spaceRef,
            name: RoutePaths.nameSpaceTaskDetails,
            redirect: (context, state) {
              final spaceKey = state.pathParameters['spaceKey'] ?? '';
              if (RoutePaths.isTaskKey(spaceKey)) return null;
              return RoutePaths.spaceListFor(spaceKey);
            },
            pageBuilder: (context, state) {
              final taskKey = state.pathParameters['spaceKey'] ?? '';
              final spaceKey = RoutePaths.spaceKeyFromTaskKey(taskKey);
              return _buildTaskOpenPage(
                key: state.pageKey,
                child: RoutePaths.isTaskKey(taskKey)
                    ? BlocProvider(
                        create: (_) =>
                            TasksBloc(api: TasksApi(spaceKey: spaceKey))
                              ..add(const TasksBoardLoadRequested()),
                        child: TaskDetailsPage(
                          taskKey: taskKey,
                          spaceKey: spaceKey,
                        ),
                      )
                    : const _NotFoundPage(),
              );
            },
          ),
          ShellRoute(
            pageBuilder: (context, state, child) {
              final spaceKey = state.pathParameters['spaceKey'] ?? '';
              if (spaceKey.isEmpty || RoutePaths.isTaskKey(spaceKey)) {
                return const NoTransitionPage(child: _NotFoundPage());
              }
              return NoTransitionPage(
                key: const ValueKey('space-tasks-shell'),
                child: SpaceTasksHost(
                  spaceKey: spaceKey,
                  child: TasksShellPage(child: child),
                ),
              );
            },
            routes: [
              GoRoute(
                path: '/space/:spaceKey/new',
                name: RoutePaths.nameSpaceTaskCreate,
                pageBuilder: (context, state) => _buildRevealPage(
                  key: state.pageKey,
                  child: const TaskCreatePage(),
                ),
              ),
              GoRoute(
                path: RoutePaths.spaceList,
                name: RoutePaths.nameSpaceList,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const TasksListPage(),
                ),
              ),
              GoRoute(
                path: RoutePaths.spaceGantt,
                name: RoutePaths.nameSpaceGantt,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const TasksGanttPage(),
                ),
              ),
              GoRoute(
                path: RoutePaths.spaceKanban,
                name: RoutePaths.nameSpaceKanban,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const KanbanBoardPage(),
                ),
              ),
              GoRoute(
                path: RoutePaths.spaceArchive,
                name: RoutePaths.nameSpaceArchive,
                pageBuilder: (context, state) {
                  final spaceKey = state.pathParameters['spaceKey'] ?? '';
                  return NoTransitionPage(
                    key: state.pageKey,
                    child: BlocProvider(
                      create: (_) => TasksBloc(
                        api: TasksApi(spaceKey: spaceKey),
                        archivedOnly: true,
                      )..add(const TasksBoardLoadRequested()),
                      child: const TasksListPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/automations',
            redirect: (context, state) => RoutePaths.tasksList,
          ),
          GoRoute(
            path: RoutePaths.more,
            name: RoutePaths.nameMore,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AdditionsPage(),
            ),
          ),
          GoRoute(
            path: RoutePaths.board,
            name: RoutePaths.nameBoard,
            pageBuilder: (context, state) => _buildRevealPage(
              key: state.pageKey,
              child: BoardEditorPage(
                boardId: state.pathParameters['boardId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.boards,
            name: RoutePaths.nameBoards,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const BoardsPage(),
            ),
          ),
          GoRoute(
            path: RoutePaths.notes,
            name: RoutePaths.nameNotes,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: _PlaceholderPage(section: AppSection.notes),
            ),
          ),
          GoRoute(
            path: RoutePaths.linkArchive,
            name: RoutePaths.nameLinkArchive,
            redirect: (context, state) => RoutePaths.notes,
          ),
        ],
      ),
    ],

    // Обработка неизвестных маршрутов (404)
    errorBuilder: (context, state) => _NotFoundPage(error: state.error),
  );

  return AppRouter(router: router, authNotifier: notifier);
}

/// Владеет роутером и его подпиской на AuthBloc.
final class AppRouter {
  const AppRouter({required this.router, required ChangeNotifier authNotifier})
    : _authNotifier = authNotifier;

  final GoRouter router;
  final ChangeNotifier _authNotifier;

  void dispose() {
    router.dispose();
    _authNotifier.dispose();
  }
}

/// Создание задачи, события и доски: один и тот же переход поверх раздела.
///
/// Экран проявляется и чуть сдвигается справа, при закрытии уходит так же.
/// Рейл и шапка живут в оболочке и не участвуют в переходе.
CustomTransitionPage<void> _buildRevealPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: ColoredBox(
            color: DdtTheme.scaffoldBackground(context),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Карточка задачи въезжает внутри оболочки: рейл и шапка не двигаются.
CustomTransitionPage<void> _buildTaskOpenPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return ColoredBox(
        color: DdtTheme.scaffoldBackground(context),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Страница с плавным fade-переходом.
///
/// Используется там, где анимация уместна (логин ↔ приложение).
/// Смена разделов внутри шелла анимируется в [DdtSectionTransition],
/// а не страницей маршрута: рейл и аппбар не должны уезжать.
CustomTransitionPage<void> _buildFadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

// ─── Auth Notifier ──────────────────────────────────────────────────────────

/// Связывает [AuthBloc] с [GoRouter] через [ChangeNotifier].
///
/// GoRouter не умеет подписываться на Stream напрямую. Этот класс
/// прослушивает поток AuthBloc и вызывает [notifyListeners] при каждом
/// изменении состояния, заставляя GoRouter пересчитать redirect.
///
/// Навигационные решения (redirect) принимает GoRouter.
/// Этот класс только предоставляет текущее значение [isAuthenticated].
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(AuthBloc authBloc) : _authBloc = authBloc {
    _wasAuthenticated = isAuthenticated;
    _subscription = authBloc.stream.listen((_) {
      final authenticated = isAuthenticated;
      if (authenticated == _wasAuthenticated) return;
      _wasAuthenticated = authenticated;
      notifyListeners();
    });
  }

  final AuthBloc _authBloc;
  late final StreamSubscription<AuthState> _subscription;
  late bool _wasAuthenticated;

  bool get isAuthenticated => _authBloc.state is AuthAuthenticated;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ─── Вспомогательные страницы ───────────────────────────────────────────────

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Раздел «${section.label}» в разработке',
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '404',
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Страница не найдена'),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go(RoutePaths.tasksList),
              child: const Text('На главную'),
            ),
          ],
        ),
      ),
    );
  }
}
