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
      return const Color(0xFF758599);
    case TaskPriority.low:
      return const Color(0xFF4A90C2);
    case TaskPriority.medium:
      return const Color(0xFFD4943A);
    case TaskPriority.high:
      return const Color(0xFFD67249);
    case TaskPriority.blocker:
      return const Color(0xFFD15462);
  }
}

Color statusColumnColor(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return const Color(0xFF6B85C7);
    case TaskStatus.inProgress:
      return const Color(0xFF4A90C2);
    case TaskStatus.done:
      return const Color(0xFF3E9B74);
  }
}

const _taskTypePalette = <Color>[
  Color(0xFF7269B5),
  Color(0xFF3D9488),
  Color(0xFFC2597E),
  Color(0xFF8C6B5D),
  Color(0xFF5279C7),
  Color(0xFF4A90B8),
  Color(0xFFD4764E),
];

Color taskTypeColor(int typeId) {
  return _taskTypePalette[typeId.abs() % _taskTypePalette.length];
}
