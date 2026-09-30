import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
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
class TasksShellPage extends StatefulWidget {
  const TasksShellPage({super.key, required this.child});

  final Widget child;

  @override
  State<TasksShellPage> createState() => _TasksShellPageState();
}

class _TasksShellPageState extends State<TasksShellPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TasksBloc>().add(const TasksBoardLoadRequested());
    });
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

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (isInitialLoading)
              ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const KanbanBoardSkeleton(),
              )
            else if (isInitialError)
              ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
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
                        Text(error!, textAlign: TextAlign.center),
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
        );
      },
    );
  }
}
