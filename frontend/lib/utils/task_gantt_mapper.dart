import 'dart:math' as math;

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
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

DateTime ganttVisibleStart(List<Task> tasks) {
  if (tasks.isEmpty) {
    return DateTime.now().subtract(const Duration(days: 7));
  }

  final earliest = tasks
      .map(taskGanttStart)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return earliest.subtract(const Duration(days: 3));
}

GanttActivity taskToGanttActivity({
  required Task task,
  required Widget Function(GanttActivity activity) barBuilder,
  required void Function(Task task) onTap,
}) {
  final start = taskGanttStart(task);
  var end = taskGanttEnd(task);
  if (end.isBefore(start)) {
    end = start;
  }

  return GanttActivity(
    key: 'task_${task.id}',
    start: start,
    end: end,
    title: task.title,
    tooltip: '${task.title}\n${formatTaskDate(start)} — ${formatTaskDate(end)}',
    color: statusColumnColor(task.status),
    data: task,
    builder: barBuilder,
    onCellTap: (activity) => onTap(activity.data as Task),
    listTitleWidget: _TaskGanttListTitle(task: task),
  );
}

Widget buildTaskGanttBar(BuildContext context, GanttActivity activity) {
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

  if (unfinished) {
    bar = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final fade = math.min(56.0, bounds.width * 0.42);
        final start = bounds.width <= 0
            ? 0.0
            : ((bounds.width - fade) / bounds.width).clamp(0.0, 1.0);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0, start, 1],
        ).createShader(bounds);
      },
      child: bar,
    );
  }

  return Tooltip(
    message: activity.tooltip ?? activity.title ?? '',
    child: SizedBox(height: double.infinity, child: bar),
  );
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
