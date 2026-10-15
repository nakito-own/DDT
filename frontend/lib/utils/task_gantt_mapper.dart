import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gantt/flutter_gantt.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/task.dart';
import '../models/task_status.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import '../theme/ddt_typography.dart';

const _ganttMonthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

String ganttMonthLabel(BuildContext context, DateTime date) {
  return '${_ganttMonthNames[date.month - 1]} ${date.year}';
}

DateTime taskGanttStart(Task task) {
  final source = task.timeStart ?? task.timeSet;
  return DateTime(source.year, source.month, source.day);
}

DateTime taskGanttEnd(Task task) {
  if (task.timeEnd != null) {
    final end = task.timeEnd!;
    return DateTime(end.year, end.month, end.day);
  }

  if (task.deadline != null) {
    final deadline = task.deadline!;
    return DateTime(deadline.year, deadline.month, deadline.day);
  }

  return taskGanttStart(task).add(const Duration(days: 1));
}

DateTime ganttToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _utcDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// How many day columns an unfinished bar fades across after today.
const int ganttUnfinishedFadeDays = 3;

/// Last day drawn for the bar. Unfinished work stays solid through today
/// and only fades on the following days.
DateTime taskGanttVisualEnd(Task task) {
  final scheduled = taskGanttEnd(task);
  if (task.status == TaskStatus.done) return scheduled;

  final fadeThrough = ganttToday().add(
    const Duration(days: ganttUnfinishedFadeDays),
  );
  return scheduled.isAfter(fadeThrough) ? scheduled : fadeThrough;
}

/// First day of the right-edge fade. Never earlier than the day after today.
DateTime taskGanttFadeStart(Task task) {
  final afterToday = ganttToday().add(const Duration(days: 1));
  final tailStart = taskGanttVisualEnd(
    task,
  ).subtract(Duration(days: ganttUnfinishedFadeDays - 1));
  return tailStart.isBefore(afterToday) ? afterToday : tailStart;
}

DateTime ganttVisibleStart() {
  return ganttToday().subtract(const Duration(days: 3));
}

GanttActivity taskToGanttActivity({
  required Task task,
  required Widget Function(GanttActivity activity) barBuilder,
  required void Function(Task task) onTap,
}) {
  final start = taskGanttStart(task);
  var scheduledEnd = taskGanttEnd(task);
  if (scheduledEnd.isBefore(start)) {
    scheduledEnd = start;
  }
  var end = taskGanttVisualEnd(task);
  if (end.isBefore(start)) {
    end = start;
  }

  return GanttActivity(
    key: 'task_${task.id}',
    start: start,
    end: end,
    title: task.title,
    tooltip:
        '${task.title}\n${formatTaskDate(start)} — ${formatTaskDate(scheduledEnd)}',
    color: statusColumnColor(task.status),
    data: task,
    builder: barBuilder,
    onCellTap: (activity) => onTap(activity.data as Task),
    listTitleWidget: _TaskGanttListTitle(task: task),
  );
}

Widget buildTaskGanttBar(BuildContext context, GanttActivity activity) {
  return _TaskGanttBar(activity: activity);
}

class _TaskGanttBar extends StatelessWidget {
  const _TaskGanttBar({required this.activity});

  final GanttActivity activity;

  @override
  Widget build(BuildContext context) {
    final task = activity.data as Task?;
    final statusColor = task == null
        ? AppColors.primary
        : statusColumnColor(task.status);
    final unfinished = task == null || task.status != TaskStatus.done;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(5.r);
    final fill = statusColor.withValues(alpha: isDark ? 0.5 : 0.28);

    Widget bar = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => activity.onCellTap?.call(activity),
        borderRadius: radius,
        splashFactory: NoSplash.splashFactory,
        child: Ink(
          decoration: BoxDecoration(color: fill, borderRadius: radius),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                activity.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  fontWeight: FontWeight.w600,
                  color: DdtTheme.taskCardTextPrimary(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (unfinished && task != null) {
      final ctrl = context.read<GanttActivityCtrl>();
      bar = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          return _fadeAfterToday(bounds, task, ctrl);
        },
        child: bar,
      );
    }

    return Tooltip(
      message: activity.tooltip ?? activity.title ?? '',
      child: SizedBox(height: double.infinity, child: bar),
    );
  }

  Shader _fadeAfterToday(Rect bounds, Task task, GanttActivityCtrl ctrl) {
    final width = bounds.width;
    final dayWidth = ctrl.dayColumnWidth;
    final visibleStart = _utcDay(
      ctrl.controller.clampToGanttRange(activity.start),
    );
    final fadeStartPx =
        _utcDay(taskGanttFadeStart(task)).difference(visibleStart).inDays *
        dayWidth;
    final fadeEndPx =
        _utcDay(
          taskGanttVisualEnd(task),
        ).add(const Duration(days: 1)).difference(visibleStart).inDays *
        dayWidth;

    if (width <= 0 || dayWidth <= 0 || fadeEndPx <= fadeStartPx) {
      return const LinearGradient(
        colors: [Colors.white, Colors.white],
      ).createShader(bounds);
    }

    final startT = (fadeStartPx / width).clamp(0.0, 1.0);
    final endT = (fadeEndPx / width).clamp(0.0, 1.0);
    if (endT - startT < 0.001) {
      final solid = startT >= 1;
      return LinearGradient(
        colors: [
          solid ? Colors.white : Colors.transparent,
          solid ? Colors.white : Colors.transparent,
        ],
      ).createShader(bounds);
    }

    final stops = <double>[];
    final colors = <Color>[];
    if (startT > 0) {
      stops.add(0);
      colors.add(Colors.white);
    }
    stops.add(startT);
    colors.add(Colors.white);
    stops.add(endT);
    colors.add(Colors.transparent);
    if (endT < 1) {
      stops.add(1);
      colors.add(Colors.transparent);
    }

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: colors,
      stops: stops,
    ).createShader(bounds);
  }
}

class _TaskGanttListTitle extends StatelessWidget {
  const _TaskGanttListTitle({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final statusColor = statusColumnColor(task.status);

    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
