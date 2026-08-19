import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../models/app_section.dart';
import '../screens/calendar_page.dart';
import '../screens/contacts_page.dart';
import '../screens/ews_login_screen.dart';
import '../screens/kanban_board_page.dart';
import '../screens/mail_page.dart';
import '../screens/main_shell_page.dart';
import '../screens/settings_page.dart';
import '../screens/task_details_page.dart';
import '../screens/tasks_gantt_page.dart';
import '../screens/tasks_list_page.dart';
import '../screens/tasks_shell_page.dart';
import '../services/tasks_api.dart';
import 'route_paths.dart';

/// Создаёт и возвращает настроенный [GoRouter].
///
/// [authBloc] должен быть тем же экземпляром, который предоставлен
/// через [BlocProvider] в дереве виджетов. Это гарантирует, что redirect
/// и виджеты читают одно и то же состояние.
GoRouter createAppRouter(AuthBloc authBloc) {
  final notifier = _AuthRouterNotifier(authBloc);

  return GoRouter(
    initialLocation: RoutePaths.tasksKanban,
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = notifier.isAuthenticated;
      final isLoginRoute = state.matchedLocation == RoutePaths.login;

      // Неавторизованный пользователь → всегда на логин
      if (!isAuthenticated && !isLoginRoute) return RoutePaths.login;

      // Авторизованный пользователь на логине → в приложение
      if (isAuthenticated && isLoginRoute) return RoutePaths.tasksKanban;

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
      // pageBuilder с NoTransitionPage исключает анимацию на уровне шелла:
      // навигационный рейл и аппбар никогда не должны анимироваться.
      ShellRoute(
        pageBuilder: (context, state, child) {
          final section = AppSection.fromRoute(state.matchedLocation);
          return NoTransitionPage(
            child: MainShellPage(selectedSection: section, child: child),
          );
        },
        routes: [
          // /tasks → redirect к kanban по умолчанию
          GoRoute(
            path: RoutePaths.tasks,
            redirect: (context, state) => RoutePaths.tasksKanban,
          ),

          // ── Внутренняя оболочка задач с TasksShellPage ─────────────────────
          // ShellRoute сохраняет TasksShellPage живым при переключении
          // между kanban/list/gantt (initState не вызывается повторно).
          ShellRoute(
            pageBuilder: (context, state, child) =>
                NoTransitionPage(child: TasksShellPage(child: child)),
            routes: [
              GoRoute(
                path: RoutePaths.tasksKanban,
                name: RoutePaths.nameTasksKanban,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const KanbanBoardPage(),
                ),
              ),
              GoRoute(
                path: RoutePaths.tasksList,
                name: RoutePaths.nameTasksList,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const TasksListPage(),
                ),
              ),
              GoRoute(
                path: RoutePaths.tasksGantt,
                name: RoutePaths.nameTasksGantt,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const TasksGanttPage(),
                ),
              ),
              GoRoute(
                path: RoutePaths.taskDetails,
                name: RoutePaths.nameTaskDetails,
                pageBuilder: (context, state) {
                  final taskId = int.tryParse(
                    state.pathParameters['taskId'] ?? '',
                  );
                  return NoTransitionPage(
                    key: state.pageKey,
                    child: taskId == null
                        ? const _NotFoundPage()
                        : TaskDetailsPage(taskId: taskId),
                  );
                },
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
            redirect: (context, state) => RoutePaths.spaceKanbanFor(1),
          ),
          ShellRoute(
            pageBuilder: (context, state, child) {
              final spaceId = int.tryParse(
                state.pathParameters['spaceId'] ?? '',
              );
              if (spaceId == null) {
                return const NoTransitionPage(child: _NotFoundPage());
              }
              return NoTransitionPage(
                key: ValueKey('space-$spaceId'),
                child: BlocProvider(
                  create: (_) => TasksBloc(api: TasksApi(spaceId: spaceId)),
                  child: TasksShellPage(child: child),
                ),
              );
            },
            routes: [
              GoRoute(
                path: RoutePaths.spaceRoot,
                redirect: (context, state) {
                  final spaceId = int.parse(state.pathParameters['spaceId']!);
                  return RoutePaths.spaceKanbanFor(spaceId);
                },
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
                path: RoutePaths.spaceTaskDetails,
                name: RoutePaths.nameSpaceTaskDetails,
                pageBuilder: (context, state) {
                  final spaceId = int.tryParse(
                    state.pathParameters['spaceId'] ?? '',
                  );
                  final taskId = int.tryParse(
                    state.pathParameters['taskId'] ?? '',
                  );
                  return NoTransitionPage(
                    key: state.pageKey,
                    child: spaceId == null || taskId == null
                        ? const _NotFoundPage()
                        : TaskDetailsPage(taskId: taskId, spaceId: spaceId),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: RoutePaths.automations,
            name: RoutePaths.nameAutomations,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: _PlaceholderPage(section: AppSection.automations),
            ),
          ),
          GoRoute(
            path: RoutePaths.linkArchive,
            name: RoutePaths.nameLinkArchive,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: _PlaceholderPage(section: AppSection.linkArchive),
            ),
          ),
        ],
      ),
    ],

    // Обработка неизвестных маршрутов (404)
    errorBuilder: (context, state) => _NotFoundPage(error: state.error),
  );
}

/// Страница с плавным fade-переходом.
///
/// Используется там, где анимация уместна (логин ↔ приложение).
/// Для переключения секций внутри шелла используется [NoTransitionPage].
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
    _subscription = authBloc.stream.listen((_) => notifyListeners());
  }

  final AuthBloc _authBloc;
  late final StreamSubscription<AuthState> _subscription;

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
              onPressed: () => context.go(RoutePaths.tasksKanban),
              child: const Text('На главную'),
            ),
          ],
        ),
      ),
    );
  }
}
