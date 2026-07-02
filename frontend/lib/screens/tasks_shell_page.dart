import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/tasks_view_mode.dart';
import '../theme/ddt_theme.dart';
import 'kanban_board_page.dart';
import 'tasks_gantt_page.dart';
import 'tasks_list_page.dart';

class TasksShellPage extends StatefulWidget {
  const TasksShellPage({super.key});

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
          previous.viewMode != current.viewMode ||
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
                    onPressed: () => context
                        .read<TasksBloc>()
                        .add(const TasksBoardLoadRequested()),
                    borderRadius: DdtTheme.radius,
                  ),
                ],
              ),
            ),
          );
        }

        return switch (state.viewMode) {
          TasksViewMode.kanban => const KanbanBoardPage(),
          TasksViewMode.list => const TasksListPage(),
          TasksViewMode.gantt => const TasksGanttPage(),
        };
      },
    );
  }
}
