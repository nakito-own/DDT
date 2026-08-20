import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../theme/ddt_theme.dart';

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
        if (state.isLoading && state.allTasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = state.errorMessage;
        if (error != null && state.allTasks.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Не удалось загрузить задачи',
                    style: DdtTheme.style(
                      fontSize: 16.sp,
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
          );
        }

        return widget.child;
      },
    );
  }
}
