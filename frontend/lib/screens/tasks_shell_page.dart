import 'dart:async';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/tasks_view_mode.dart';
import '../router/route_paths.dart';
import '../services/tasks_api.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_app_bar_section_actions.dart';
import '../widgets/ddt_glass_fab.dart';
import '../widgets/ddt_mobile_navigation_bar.dart';
import '../widgets/ddt_scroll_to_top.dart';
import '../widgets/ddt_tasks_view_transition.dart';
import 'task_create_page.dart';
import '../widgets/kanban_board_skeleton.dart';

/// Оболочка раздела задач: управляет загрузкой и ошибками.
///
/// Является shell-виджетом для внутреннего [ShellRoute] маршрутов задач.
/// Сохраняется живым при переключении между /tasks/kanban, /tasks/list
/// и /tasks/gantt — [initState] не срабатывает повторно, загрузка
/// происходит один раз при входе в раздел задач.
///
/// Конкретный вид (KanbanBoardPage, TasksListPage, TasksGanttPage)
/// определяется GoRouter и передаётся через [child].
class SpaceTasksHost extends StatefulWidget {
  const SpaceTasksHost({
    super.key,
    required this.spaceKey,
    required this.child,
  });

  final String spaceKey;
  final Widget child;

  @override
  State<SpaceTasksHost> createState() => _SpaceTasksHostState();
}

class _SpaceTasksHostState extends State<SpaceTasksHost> {
  late final TasksBloc _root;
  late final TasksBloc _bloc;
  late final StreamSubscription<TasksState> _viewSubscription;

  @override
  void initState() {
    super.initState();
    _root = context.read<TasksBloc>();
    _bloc = TasksBloc(
      api: TasksApi(spaceKey: widget.spaceKey),
      beginLoading: true,
      initialViewMode: _root.state.spaceViewMode,
    )..add(const TasksBoardLoadRequested());
    _viewSubscription = _bloc.stream.listen((_) => _rememberSpace());
    // Оболочка ниже в этом кадре ещё запишет вид из адреса.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rememberSpace();
    });
  }

  @override
  void didUpdateWidget(SpaceTasksHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceKey != widget.spaceKey) {
      _bloc.switchSpace(widget.spaceKey);
      _rememberSpace();
    }
  }

  /// Корневой блок переживает уход из раздела, блок доски — нет.
  void _rememberSpace() {
    final root = _root.state;
    if (root.spaceViewMode == _bloc.state.viewMode &&
        root.activeSpaceKey == widget.spaceKey) {
      return;
    }
    _root.add(
      TasksSpaceContextChanged(
        spaceKey: widget.spaceKey,
        viewMode: _bloc.state.viewMode,
      ),
    );
  }

  @override
  void dispose() {
    _viewSubscription.cancel();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(value: _bloc, child: widget.child);
  }
}

/// Оболочка раздела задач: управляет загрузкой и ошибками.
///
/// Является shell-виджетом для внутреннего [ShellRoute] маршрутов задач.
/// Сохраняется живым при переключении между kanban/list/gantt.
class TasksShellPage extends StatefulWidget {
  const TasksShellPage({super.key, required this.child});

  final Widget child;

  @override
  State<TasksShellPage> createState() => _TasksShellPageState();
}

class _TasksShellPageState extends State<TasksShellPage> {
  final _chrome = DdtFloatingChromeController();
  String? _syncedPath;

  @override
  void dispose() {
    _chrome.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final bloc = context.read<TasksBloc>();
    if (!bloc.state.isLoading) {
      bloc.add(const TasksBoardLoadRequested());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = GoRouterState.of(context).uri.path;
    if (path == _syncedPath) return;
    _syncedPath = path;
    final mode = TasksViewMode.boardModeFromRoute(path);
    if (mode == null) return;
    final bloc = context.read<TasksBloc>();
    if (bloc.archivedOnly || bloc.state.viewMode == mode) return;
    bloc.add(TasksViewModeChanged(mode));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TasksBloc, TasksState>(
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.errorMessage != current.errorMessage ||
          previous.allTasks.isEmpty != current.allTasks.isEmpty,
      builder: (context, state) {
        // GoRouter's shell child must stay mounted: it is a Navigator keyed
        // globally, and replacing it on load/error duplicates that key.
        final isInitialLoading = state.isLoading && state.allTasks.isEmpty;
        final error = state.errorMessage;
        final isInitialError = error != null && state.allTasks.isEmpty;
        final showKanbanPlaceholder =
            isInitialLoading &&
            GoRouterState.of(context).uri.path.endsWith('/kanban');

        final compact = DdtAdaptive.isCompact(context);
        final path = GoRouterState.of(context).uri.path;
        final onBoard = RoutePaths.isTasksBoardRoute(path);
        final archiveOpen = RoutePaths.isArchiveRoute(path);
        final boardMode = TasksViewMode.boardModeFromRoute(path);

        return DdtFloatingChrome(
          controller: _chrome,
          child: ListenableBuilder(
            listenable: _chrome,
            builder: (context, _) {
              return DdtScrollToTopOverlay(
                enabled: compact && _chrome.visible && onBoard,
                child: Stack(
                fit: StackFit.expand,
                children: [
                  DdtTasksViewTransition(mode: boardMode, child: widget.child),
                  if (compact && _chrome.visible && onBoard) ...[
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: DdtAdaptive.floatingBottomBar(context)
                          ? DdtMobileNavigationBar.clearance(context)
                          : 0,
                      child: const Center(child: TasksMobileViewBar()),
                    ),
                    if (!archiveOpen)
                      Positioned(
                        right: DdtMobileNavigationBar.horizontalMargin(context),
                        bottom: DdtGlassFab.bottomOffset(context),
                        child: DdtGlassFab(
                          icon: DdtIcons.add,
                          tooltip: 'Новая задача',
                          onPressed: () => openTaskCreatePage(context),
                        ),
                      ),
                  ],
                  if (showKanbanPlaceholder)
                    ColoredBox(
                      color: DdtTheme.scaffoldBackground(context),
                      child: const KanbanBoardSkeleton(),
                    )
                  else if (isInitialError)
                    ColoredBox(
                      color: DdtTheme.scaffoldBackground(context),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Не удалось загрузить задачи',
                                style: DdtTheme.style(
                                  fontSize: DdtTypography.sectionTitleSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(error, textAlign: TextAlign.center),
                              SizedBox(height: 16.h),
                              Button(
                                text: 'Повторить',
                                onPressed: () => context.read<TasksBloc>().add(
                                  const TasksBoardLoadRequested(),
                                ),
                                borderRadius: DdtTheme.radius,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
