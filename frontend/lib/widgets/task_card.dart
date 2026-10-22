import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../models/task.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import 'task_priority_badge.dart';
import 'task_type_badge.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';
import 'ddt_markdown_body.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.isDragging = false,
    this.onArchive,
    this.onTap,
  });

  final Task task;
  final bool isDragging;
  final VoidCallback? onArchive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = isTaskOverdue(task);
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final textSecondary = DdtTheme.taskCardTextSecondary(context);
    final metaMuted = DdtTheme.textMuted(context);

    final card = DdtTheme.taskCardGlass(
      context: context,
      isDragging: isDragging,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      onTap: isDragging ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              DdtIcon(
                DdtIcons.dragHandle,
                size: 11.sp,
                color: metaMuted.withValues(alpha: 0.65),
              ),
              if (task.key.isNotEmpty) ...[
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    task.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.captionSize,
                      fontWeight: FontWeight.w600,
                      color: metaMuted,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              if (task.archive) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF1F5F9),
                    borderRadius: DdtTheme.badgeBorderRadius,
                    border: Border.all(color: DdtTheme.borderSubtle(context)),
                  ),
                  child: Text(
                    'Архив',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.microSize,
                      fontWeight: FontWeight.w600,
                      color: metaMuted,
                    ),
                  ),
                ),
                if (onArchive != null) SizedBox(width: 6.w),
              ],
              if (onArchive != null)
                IconButton(
                  tooltip: 'В архив',
                  onPressed: onArchive,
                  icon: DdtIcon(
                    DdtIcons.close,
                    size: 13.sp,
                    color: metaMuted,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: 5.h),
          Text(
            task.title,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              fontWeight: FontWeight.w600,
              height: 1.32,
              color: textPrimary,
            ),
          ),
          if (task.description.isNotEmpty) ...[
            SizedBox(height: 5.h),
            Text(
              DdtMarkdownBody.plainTextPreview(task.description),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                color: textSecondary,
                height: 1.35,
              ),
            ),
          ],
          if (task.type != null || task.priority != null) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                if (task.type != null) TaskTypeBadge(label: task.type!.name),
                if (task.priority != null)
                  TaskPriorityBadge(priority: task.priority!),
              ],
            ),
          ],
          if (task.deadline != null ||
              task.executorId != null ||
              (task.links?.isNotEmpty ?? false) ||
              task.comments.isNotEmpty) ...[
            SizedBox(height: 9.h),
            Container(
              height: 1,
              color: DdtTheme.borderSubtle(context).withValues(alpha: 0.7),
            ),
            SizedBox(height: 7.h),
            _TaskCardMeta(
              task: task,
              overdue: overdue,
              textSecondary: metaMuted,
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
            icon: DdtIcons.calendar,
            label: formatTaskDate(task.deadline!),
            color: overdue ? DdtTheme.dangerColor : textSecondary,
          ),
        if (task.executorId != null)
          _MetaItem(
            icon: DdtIcons.user,
            label: formatUserRef(task.executorId, fallback: '—'),
            color: textSecondary,
          ),
        if (task.links?.isNotEmpty ?? false)
          _MetaItem(
            icon: DdtIcons.link,
            label: '${task.links!.length}',
            color: textSecondary,
          ),
        if (task.comments.isNotEmpty)
          _MetaItem(
            icon: DdtIcons.comment,
            label: '${task.comments.length}',
            color: textSecondary,
          ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label, this.color});

  final FaIconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? DdtTheme.textMuted(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtIcon(icon, size: 12.sp, color: textColor),
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
