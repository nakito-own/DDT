import 'package:flutter/material.dart';
import 'package:flutter_gantt/flutter_gantt.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/task.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';

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
    tooltip:
        '${task.title}\n${formatTaskDate(start)} — ${formatTaskDate(end)}',
    color: statusColumnColor(task.status),
    data: task,
    builder: barBuilder,
    onCellTap: (activity) => onTap(activity.data as Task),
    listTitleWidget: _TaskGanttListTitle(task: task),
  );
}

class _TaskGanttListTitle extends StatelessWidget {
  const _TaskGanttListTitle({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: statusColumnColor(task.status),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
