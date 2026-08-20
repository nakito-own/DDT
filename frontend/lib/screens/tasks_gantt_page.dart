import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gantt/flutter_gantt.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_gantt_mapper.dart';
import '../widgets/task_side_panel.dart';

class TasksGanttPage extends StatefulWidget {
  const TasksGanttPage({super.key});

  @override
  State<TasksGanttPage> createState() => _TasksGanttPageState();
}

class _TasksGanttPageState extends State<TasksGanttPage> {
  static const _minZoom = 0.6;
  static const _maxZoom = 2.4;
  static const _zoomStep = 0.2;
  static const _baseDayMinWidth = 44.0;

  late GanttController _ganttController;
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    final filteredTasks = context.read<TasksBloc>().state.filteredTasks;
    _ganttController = GanttController(
      startDate: ganttVisibleStart(filteredTasks),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyTheme();
    });
  }

  @override
  void dispose() {
    _ganttController.dispose();
    super.dispose();
  }

  void _setZoom(double zoom) {
    final next = zoom.clamp(_minZoom, _maxZoom);
    if ((next - _zoom).abs() < 0.001) return;
    setState(() => _zoom = next);
    _applyTheme();
  }

  void _applyTheme() {
    _ganttController.theme = _ganttTheme(context);
    _ganttController.daysViews = null;
  }

  void _goToToday() {
    _ganttController.startDate = DateTime.now().subtract(
      const Duration(days: 3),
    );
    _ganttController.update();
  }

  Widget _buildTaskBar(GanttActivity activity) =>
      buildTaskGanttBar(context, activity);

  List<GanttActivity> _buildActivities(List<Task> tasks) {
    return tasks
        .map(
          (task) => taskToGanttActivity(
            task: task,
            barBuilder: _buildTaskBar,
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

    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: task, updated: updated),
    );
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

    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: task, updated: updated),
    );
    _ganttController.update();
  }

  GanttTheme _ganttTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridLineColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.primary.withValues(alpha: 0.12);

    return GanttTheme.of(
      context,
      backgroundColor: Colors.transparent,
      weekendColor: isDark
          ? Colors.white.withValues(alpha: 0.03)
          : AppColors.primary.withValues(alpha: 0.03),
      defaultCellColor: gridLineColor,
      todayBackgroundColor: AppColors.primary,
      todayTextColor: Colors.white,
      cellHeight: 48.h,
      rowPadding: 10.h,
      headerHeight: 56.h,
      dayMinWidth: _baseDayMinWidth.w * _zoom,
    );
  }

  Widget _buildToolbar() {
    final textSecondary = DdtTheme.taskCardTextSecondary(context);
    final zoomPercent = (_zoom * 100).round();

    return Row(
      children: [
        _GanttToolbarButton(
          tooltip: 'Назад на неделю',
          icon: CupertinoIcons.chevron_left,
          onPressed: () => _ganttController.prev(days: 7),
        ),
        _GanttToolbarButton(
          tooltip: 'Вперёд на неделю',
          icon: CupertinoIcons.chevron_right,
          onPressed: () => _ganttController.next(days: 7),
        ),
        SizedBox(width: 12.w),
        Text(
          'Масштаб',
          style: DdtTheme.style(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        SizedBox(width: 8.w),
        _GanttToolbarButton(
          tooltip: 'Отдалить',
          icon: CupertinoIcons.minus,
          onPressed: _zoom > _minZoom
              ? () => _setZoom(_zoom - _zoomStep)
              : null,
        ),
        SizedBox(
          width: 44.w,
          child: Text(
            '$zoomPercent%',
            textAlign: TextAlign.center,
            style: DdtTheme.style(fontSize: 12.sp, fontWeight: FontWeight.w600),
          ),
        ),
        _GanttToolbarButton(
          tooltip: 'Приблизить',
          icon: CupertinoIcons.plus,
          onPressed: _zoom < _maxZoom
              ? () => _setZoom(_zoom + _zoomStep)
              : null,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.h,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.r),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 12.r),
            ),
            child: Slider(
              value: _zoom,
              min: _minZoom,
              max: _maxZoom,
              onChanged: _setZoom,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Button(
          text: 'Сегодня',
          type: ButtonType.outlined,
          onPressed: _goToToday,
          borderRadius: DdtTheme.radius,
        ),
      ],
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
          previous.sortOption != current.sortOption,
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
              _buildToolbar(),
              SizedBox(height: 8.h),
              Expanded(
                child: Gantt(
                  controller: _ganttController,
                  theme: _ganttTheme(context),
                  activities: activities,
                  activitiesListFlex: 2,
                  gridAreaFlex: 5,
                  monthToText: ganttMonthLabel,
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

class _GanttToolbarButton extends StatelessWidget {
  const _GanttToolbarButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;
    final color = enabled
        ? DdtTheme.taskCardTextPrimary(context)
        : DdtTheme.taskCardIconMuted(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: DdtTheme.radius,
          splashFactory: NoSplash.splashFactory,
          child: Ink(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              borderRadius: DdtTheme.radius,
              color: isDark
                  ? Colors.white.withValues(alpha: enabled ? 0.06 : 0.03)
                  : AppColors.primary.withValues(alpha: enabled ? 0.06 : 0.03),
              border: Border.all(
                color: DdtTheme.glassBorderColor(Theme.of(context).brightness)
                    .withValues(
                      alpha:
                          DdtTheme.glassBorderOpacity(
                            Theme.of(context).brightness,
                          ) *
                          0.45,
                    ),
              ),
            ),
            child: Icon(icon, size: 16.sp, color: color),
          ),
        ),
      ),
    );
  }
}
