import 'package:flutter/material.dart';

import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';

String formatTaskDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$day.$month.${value.year} $hour:$minute';
}

String formatTaskDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');

  return '$day.$month.${value.year}';
}

String formatUserRef(int? userId, {required String fallback}) {
  if (userId == null) return fallback;
  return '#$userId';
}

bool isTaskOverdue(Task task) {
  if (task.deadline == null || task.status == TaskStatus.done) {
    return false;
  }

  return task.deadline!.isBefore(DateTime.now());
}

Color priorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.insignificant:
      return Colors.grey;
    case TaskPriority.low:
      return const Color(0xFF1976D2);
    case TaskPriority.medium:
      return const Color(0xFFF57C00);
    case TaskPriority.high:
      return const Color(0xFFE65100);
    case TaskPriority.blocker:
      return const Color(0xFFC62828);
  }
}

Color statusColumnColor(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return const Color(0xFF1976D2);
    case TaskStatus.inProgress:
      return const Color(0xFF64B5F6);
    case TaskStatus.done:
      return const Color(0xFF07753F);
  }
}

const _taskTypePalette = <Color>[
  Color(0xFF5E35B1),
  Color(0xFF00897B),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
  Color(0xFF3949AB),
  Color(0xFF00ACC1),
  Color(0xFFF4511E),
];

Color taskTypeColor(int typeId) {
  return _taskTypePalette[typeId.abs() % _taskTypePalette.length];
}
