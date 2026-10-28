import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gantt/flutter_gantt.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_gantt_mapper.dart';
import 'task_details_page.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_app_bar_section_actions.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_mobile_navigation_bar.dart';
import '../widgets/ddt_shell_metrics.dart';

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
    _ganttController = GanttController(startDate: ganttVisibleStart());
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

  void _openTask(Task task) {
    openTaskDetailsPage(
      context,
      task,
      onSheetClosed: () {
        if (mounted) _ganttController.update();
      },
    );
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
      final shift = end.difference(activity.end);
      final storedEnd = task.timeEnd ?? taskGanttEnd(task);
      updated = updated.copyWith(timeEnd: storedEnd.add(shift));
    }

    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: task, updated: updated),
    );
    _ganttController.update();
  }

  GanttTheme _ganttTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridLineColor = DdtTheme.borderSubtle(context);

    return GanttTheme.of(
      context,
      backgroundColor: Colors.transparent,
      weekendColor: isDark
          ? Colors.white.withValues(alpha: 0.025)
          : const Color(0xFFF1F5F9).withValues(alpha: 0.7),
      defaultCellColor: gridLineColor,
      todayBackgroundColor: DdtTheme.primaryColor,
      todayTextColor: Colors.white,
      cellHeight: 28.h,
      rowPadding: 4.h,
      rowsGroupPadding: 2.h,
      headerHeight: 56.h,
      dayMinWidth: _baseDayMinWidth.w * _zoom,
    );
  }

  Widget _buildToolbar() {
    final textSecondary = DdtTheme.taskCardTextSecondary(context);
    final zoomPercent = (_zoom * 100).round();

    return Row(
      children: [
        _GanttChevron(
          tooltip: 'Назад на неделю',
          icon: DdtIcons.chevronLeft,
          onPressed: () => _ganttController.prev(days: 7),
        ),
        SizedBox(width: 2.w),
        _GanttChevron(
          tooltip: 'Вперёд на неделю',
          icon: DdtIcons.chevronRight,
          onPressed: () => _ganttController.next(days: 7),
        ),
        SizedBox(width: 12.w),
        Text(
          'Масштаб',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSmallSize,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        SizedBox(width: 8.w),
        _GanttToolbarButton(
          tooltip: 'Отдалить',
          icon: DdtIcons.remove,
          onPressed: _zoom > _minZoom
              ? () => _setZoom(_zoom - _zoomStep)
              : null,
        ),
        SizedBox(
          width: 44.w,
          child: Text(
            '$zoomPercent%',
            textAlign: TextAlign.center,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _GanttToolbarButton(
          tooltip: 'Приблизить',
          icon: DdtIcons.add,
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
          previous.authorFilter != current.authorFilter ||
          previous.executorFilter != current.executorFilter ||
          previous.responsibleFilter != current.responsibleFilter ||
          previous.dateFilters != current.dateFilters ||
          previous.sortOption != current.sortOption,
      builder: (context, state) {
        final activities = _buildActivities(state.filteredTasks);

        if (activities.isEmpty) {
          return Center(
            child: Text(
              'Нет задач для отображения на диаграмме',
              style: DdtTheme.style(fontSize: DdtTypography.bodySize),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: DdtShellMetrics.fixedTopPadding(context),
              child: _buildToolbar(),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: DdtAdaptive.isCompact(context)
                      ? TasksMobileViewBar.reserve +
                            (DdtAdaptive.floatingBottomBar(context)
                                ? DdtMobileNavigationBar.clearance(context)
                                : 0)
                      : 0,
                ),
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
            ),
          ],
        );
      },
    );
  }
}

class _GanttChevron extends StatelessWidget {
  const _GanttChevron({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final FaIconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        splashFactory: NoSplash.splashFactory,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
          child: DdtIcon(
            icon,
            size: 14.sp,
            color: DdtTheme.taskCardTextPrimary(context),
          ),
        ),
      ),
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
  final FaIconData icon;
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
          borderRadius: DdtTheme.inputControlBorderRadius,
          splashFactory: NoSplash.splashFactory,
          child: Ink(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              borderRadius: DdtTheme.inputControlBorderRadius,
              color: isDark
                  ? Colors.white.withValues(alpha: enabled ? 0.07 : 0.03)
                  : Colors.white.withValues(alpha: enabled ? 0.78 : 0.45),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : DdtTheme.borderSubtle(context),
              ),
            ),
            child: DdtIcon(icon, size: 14.sp, color: color, fitParent: true),
          ),
        ),
      ),
    );
  }
}
