import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../theme/ddt_scroll_behavior.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import 'task_create_page.dart';
import 'task_details_page.dart';
import '../widgets/task_card.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_app_bar_section_actions.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/tasks_filters_panel.dart';
import '../theme/ddt_typography.dart';

class TasksListPage extends StatelessWidget {
  const TasksListPage({super.key});

  void _openTask(BuildContext context, Task task) {
    openTaskDetailsPage(context, task);
  }

  void _createTask(BuildContext context) {
    openTaskCreatePage(context);
  }

  Future<void> _archiveTask(BuildContext context, Task task) async {
    context.read<TasksBloc>().add(
      TaskArchiveRequested(task: task, status: task.status),
    );
    DdtToast.show(
      message: '«${task.title}» перенесена в архив',
      type: ToastType.success,
    );
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
          previous.authorFilter != current.authorFilter ||
          previous.executorFilter != current.executorFilter ||
          previous.responsibleFilter != current.responsibleFilter ||
          previous.dateFilters != current.dateFilters ||
          previous.sortOption != current.sortOption ||
          previous.isLoading != current.isLoading,
      builder: (context, state) {
        final tasks = state.filteredTasks;
        final archivedOnly = context.read<TasksBloc>().archivedOnly;

        return DdtAdaptiveSectionColumns(
          sheetTitle: 'Фильтры',
          sidebar: TasksFiltersPanel(
            onCreatePressed: archivedOnly ? null : () => _createTask(context),
          ),
          body: state.isLoading && tasks.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : tasks.isEmpty
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: DdtShellMetrics.fixedTopPadding(context),
                    child: Text(
                      archivedOnly
                          ? 'В архиве нет задач'
                          : 'Нет задач по выбранным фильтрам',
                      style: DdtTheme.style(fontSize: DdtTypography.bodySize),
                    ),
                  ),
                )
              : DdtScrollEdgeFade(
                  child: ScrollConfiguration(
                    behavior: const DdtScrollBehavior(),
                    child: ListView.separated(
                      padding: DdtShellMetrics.scrollPadding(context).copyWith(
                        bottom:
                            DdtScrollEdgeFade.listBottomPadding(context) +
                            (DdtAdaptive.isCompact(context)
                                ? TasksMobileViewBar.reserve
                                : 0),
                      ),
                      clipBehavior: Clip.none,
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => SizedBox(height: 10.h),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return TaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          onTap: () => _openTask(context, task),
                          onArchive: archivedOnly
                              ? null
                              : () => _archiveTask(context, task),
                        );
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}
