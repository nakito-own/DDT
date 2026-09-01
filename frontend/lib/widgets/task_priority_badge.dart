import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/task_priority.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import '../theme/ddt_typography.dart';

class TaskPriorityBadge extends StatelessWidget {
  const TaskPriorityBadge({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: DdtTheme.radius,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        priority.label,
        style: DdtTheme.style(
          fontSize: DdtTypography.captionSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
