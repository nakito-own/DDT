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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = priorityColor(priority);
    final labelColor = isDark
        ? Color.lerp(baseColor, Colors.white, 0.36)!
        : Color.lerp(baseColor, Colors.black, 0.14)!;
    final dotColor = isDark
        ? Color.lerp(baseColor, Colors.white, 0.22)!
        : baseColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: DdtTheme.badgeBorderRadius,
        border: Border.all(
          color: baseColor.withValues(alpha: isDark ? 0.38 : 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.w,
            height: 5.w,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: 5.w),
          Text(
            priority.label,
            style: DdtTheme.style(
              fontSize: DdtTypography.captionSize,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
