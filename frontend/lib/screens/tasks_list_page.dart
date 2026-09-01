import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import '../widgets/task_card.dart';
import '../widgets/task_side_panel.dart';
import '../widgets/tasks_filters_panel.dart';
import '../theme/ddt_typography.dart';

class TasksListPage extends StatelessWidget {
  const TasksListPage({super.key});

  Future<void> _openTask(BuildContext context, Task task) async {
    final state = context.read<TasksBloc>().state;
    final updated = await showTaskSidePanel(
      context,
      mode: TaskSidePanelMode.view,
      task: task,
      taskTypes: state.taskTypes,
    );

    if (updated == null || !context.mounted) return;

    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: task, updated: updated),
    );
  }

  Future<void> _createTask(BuildContext context) async {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : null;
    final state = context.read<TasksBloc>().state;

    final created = await showTaskSidePanel(
      context,
      mode: TaskSidePanelMode.create,
      taskTypes: state.taskTypes,
      defaultAuthorId: currentUserId,
    );

    if (created == null || !context.mounted) return;

    final now = DateTime.now();
    final draft = Task(
      id: 0,
      title: created.title,
      status: created.status,
      typeId: created.typeId,
      type: created.type,
      description: created.description,
      authorId: currentUserId ?? created.authorId,
      executorId: created.executorId,
      responsibleId: created.responsibleId,
      spaceId: context.read<TasksBloc>().spaceId,
      timeSet: created.timeSet,
      timeStart:
          created.timeStart ??
          (created.status == TaskStatus.inProgress ? now : null),
      timeEnd:
          created.timeEnd ?? (created.status == TaskStatus.done ? now : null),
      deadline: created.deadline,
      priority: created.priority,
      links: created.links,
      comments: created.comments,
    );

    context.read<TasksBloc>().add(TaskCreateRequested(draft));
    DdtToast.show(message: 'Задача создаётся...', type: ToastType.info);
  }

  Future<void> _deleteTask(BuildContext context, Task task) async {
    context.read<TasksBloc>().add(
      TaskDeleteRequested(task: task, status: task.status),
    );
    DdtToast.show(message: '«${task.title}» удалена', type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TasksBloc, TasksState>(
      buildWhen: (previous, current) =>
          previous.columns != current.columns ||
          previous.searchQuery != current.searchQuery ||
          previous.statusFilters != current.statusFilters ||
          previous.priorityFilter != current.priorityFilter ||
          previous.typeFilter != current.typeFilter ||
          previous.sortOption != current.sortOption,
      builder: (context, state) {
        final tasks = state.filteredTasks;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: DdtTheme.glass(
                context: context,
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Задачи',
                            style: DdtTheme.style(
                              fontSize: DdtTypography.sectionTitleSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Button(
                          text: 'Создать',
                          onPressed: () => _createTask(context),
                          borderRadius: DdtTheme.radius,
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Expanded(
                      child: tasks.isEmpty
                          ? Center(
                              child: Text(
                                'Нет задач по выбранным фильтрам',
                                style: DdtTheme.style(
                                  fontSize: DdtTypography.bodySize,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: tasks.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 10.h),
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                return TaskCard(
                                  key: ValueKey(task.id),
                                  task: task,
                                  onTap: () => _openTask(context, task),
                                  onDelete: () => _deleteTask(context, task),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16.w),
            const Expanded(flex: 3, child: TasksFiltersPanel()),
          ],
        );
      },
    );
  }
}
