import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/task.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import 'task_priority_badge.dart';
import 'task_type_badge.dart';
import '../theme/ddt_typography.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.isDragging = false,
    this.onDelete,
    this.onTap,
  });

  final Task task;
  final bool isDragging;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = isTaskOverdue(task);
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final textSecondary = DdtTheme.taskCardTextSecondary(context);
    final iconMuted = DdtTheme.taskCardIconMuted(context);

    final card = DdtTheme.taskCardGlass(
      context: context,
      isDragging: isDragging,
      onTap: isDragging ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.line_horizontal_3,
                size: 18.sp,
                color: iconMuted,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  task.title,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Удалить',
                  onPressed: onDelete,
                  icon: Icon(
                    CupertinoIcons.xmark,
                    size: 18.sp,
                    color: textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (task.description.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                color: textSecondary,
                height: 1.3,
              ),
            ),
          ],
          SizedBox(height: 10.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              if (task.type != null) TaskTypeBadge(label: task.type!.name),
              if (task.priority != null)
                TaskPriorityBadge(priority: task.priority!),
            ],
          ),
          if (task.deadline != null ||
              task.executorId != null ||
              (task.links?.isNotEmpty ?? false) ||
              task.comments.isNotEmpty) ...[
            SizedBox(height: 10.h),
            _TaskCardMeta(
              task: task,
              overdue: overdue,
              textSecondary: textSecondary,
            ),
          ],
        ],
      ),
    );

    if (!isDragging) return card;

    return _TaskCardEdgeGlow(borderRadius: DdtTheme.radius, child: card);
  }
}

class _TaskCardEdgeGlow extends StatelessWidget {
  const _TaskCardEdgeGlow({required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _TaskCardEdgeGlowPainter(
                borderRadius: borderRadius,
                glowColor: isDark
                    ? Colors.black.withValues(alpha: 0.38)
                    : Colors.black.withValues(alpha: 0.16),
                maxSpread: 8,
                intensity: isDark ? 0.46 : 0.32,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _TaskCardEdgeGlowPainter extends CustomPainter {
  _TaskCardEdgeGlowPainter({
    required this.borderRadius,
    required this.glowColor,
    required this.maxSpread,
    required this.intensity,
  });

  final BorderRadius borderRadius;
  final Color glowColor;
  final double maxSpread;
  final double intensity;

  static const _steps = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    for (var step = 1; step <= _steps; step++) {
      final t = step / _steps;
      final spread = maxSpread * t;
      final alpha = glowColor.a * (1 - t) * intensity;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = glowColor.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread * 0.78);

      canvas.drawRRect(rrect.inflate(spread), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TaskCardEdgeGlowPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.maxSpread != maxSpread ||
        oldDelegate.intensity != intensity;
  }
}

class _TaskCardMeta extends StatelessWidget {
  const _TaskCardMeta({
    required this.task,
    required this.overdue,
    required this.textSecondary,
  });

  final Task task;
  final bool overdue;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.w,
      runSpacing: 6.h,
      children: [
        if (task.deadline != null)
          _MetaItem(
            icon: CupertinoIcons.calendar,
            label: formatTaskDate(task.deadline!),
            color: overdue ? AppColors.error : textSecondary,
          ),
        if (task.executorId != null)
          _MetaItem(
            icon: CupertinoIcons.person,
            label: formatUserRef(task.executorId, fallback: '—'),
            color: textSecondary,
          ),
        if (task.links?.isNotEmpty ?? false)
          _MetaItem(
            icon: CupertinoIcons.link,
            label: '${task.links!.length}',
            color: textSecondary,
          ),
        if (task.comments.isNotEmpty)
          _MetaItem(
            icon: CupertinoIcons.chat_bubble,
            label: '${task.comments.length}',
            color: textSecondary,
          ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? DdtTheme.taskCardTextSecondary(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: textColor),
        SizedBox(width: 4.w),
        Text(
          label,
          style: DdtTheme.style(
            fontSize: DdtTypography.captionSize,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
