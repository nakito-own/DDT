import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gantt/flutter_gantt.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import '../utils/task_gantt_mapper.dart';
import '../widgets/task_side_panel.dart';

class TasksGanttPage extends StatefulWidget {
  const TasksGanttPage({super.key});

  @override
  State<TasksGanttPage> createState() => _TasksGanttPageState();
}

class _TasksGanttPageState extends State<TasksGanttPage> {
  late GanttController _ganttController;

  @override
  void initState() {
    super.initState();
    final filteredTasks = context.read<TasksBloc>().state.filteredTasks;
    _ganttController = GanttController(
      startDate: ganttVisibleStart(filteredTasks),
    );
  }

  @override
  void dispose() {
    _ganttController.dispose();
    super.dispose();
  }

  Widget _buildGlassBar(GanttActivity activity) {
    final task = activity.data as Task?;
    final statusColor =
        task == null ? AppColors.primary : statusColumnColor(task.status);

    return DdtTheme.taskCardGlass(
      context: context,
      cornerRadius: 8.r,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border(
            left: BorderSide(color: statusColor, width: 3.w),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          activity.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DdtTheme.style(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<GanttActivity> _buildActivities(List<Task> tasks) {
    return tasks
        .map(
          (task) => taskToGanttActivity(
            task: task,
            barBuilder: _buildGlassBar,
            onTap: _openTask,
          ),
        )
        .toList();
  }

  Future<void> _openTask(Task task) async {
    final state = context.read<TasksBloc>().state;
    final updated = await showTaskSidePanel(
      context,
      mode: TaskSidePanelMode.view,
      task: task,
      taskTypes: state.taskTypes,
    );

    if (updated == null || !mounted) return;

    context.read<TasksBloc>().add(TaskUpdateRequested(original: task, updated: updated));
    _ganttController.update();
  }

  Future<void> _onActivityChanged(
    GanttActivity activity,
    DateTime? start,
    DateTime? end,
  ) async {
    final task = activity.data as Task?;
    if (task == null) return;

    var updated = task;
    if (start != null) {
      updated = updated.copyWith(timeStart: start);
    }
    if (end != null) {
      updated = updated.copyWith(timeEnd: end);
    }

    context.read<TasksBloc>().add(TaskUpdateRequested(original: task, updated: updated));
    _ganttController.update();
  }

  GanttTheme _ganttTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GanttTheme.of(
      context,
      backgroundColor: Colors.transparent,
      weekendColor: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : AppColors.primary.withValues(alpha: 0.04),
      defaultCellColor: AppColors.primary.withValues(alpha: 0.35),
      cellHeight: 36.h,
      rowPadding: 6.h,
      dayMinWidth: 36.w,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TasksBloc, TasksState>(
      buildWhen: (previous, current) =>
          previous.filteredTasks != current.filteredTasks,
      builder: (context, state) {
        final activities = _buildActivities(state.filteredTasks);

        if (activities.isEmpty) {
          return DdtTheme.glass(
            context: context,
            padding: EdgeInsets.all(24.w),
            child: Center(
              child: Text(
                'Нет задач для отображения на диаграмме',
                style: DdtTheme.style(fontSize: 14.sp),
              ),
            ),
          );
        }

        return DdtTheme.glass(
          context: context,
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GanttRangeSelector(controller: _ganttController),
              SizedBox(height: 8.h),
              Expanded(
                child: Gantt(
                  controller: _ganttController,
                  theme: _ganttTheme(context),
                  activities: activities,
                  activitiesListFlex: 2,
                  gridAreaFlex: 5,
                  onActivityChanged: _onActivityChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
