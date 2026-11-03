import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../models/task.dart';
import '../models/user_profile.dart';
import '../services/directory_users.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import 'task_priority_badge.dart';
import 'task_type_badge.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';
import 'ddt_markdown_body.dart';
import 'ddt_user_chip.dart';

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
          SizedBox(height: 9.h),
          Container(
            height: 1,
            color: DdtTheme.borderSubtle(context).withValues(alpha: 0.7),
          ),
          SizedBox(height: 7.h),
          _TaskCardTags(task: task, overdue: overdue),
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

class _TaskCardTags extends StatelessWidget {
  const _TaskCardTags({required this.task, required this.overdue});

  final Task task;
  final bool overdue;

  bool get _inSpace =>
      task.spaceId != null || (task.spaceKey != null && task.spaceKey!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final executorId = task.executorId;

    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _StatusTag(
          label: task.status.label,
          color: statusColumnColor(task.status),
        ),
        if (task.type != null) TaskTypeBadge(label: task.type!.name),
        if (task.priority != null) TaskPriorityBadge(priority: task.priority!),
        if (task.comments.isNotEmpty)
          _MetaTag(icon: DdtIcons.comment, label: '${task.comments.length}'),
        if (task.deadline != null)
          _MetaTag(
            icon: DdtIcons.calendar,
            label: formatTaskDate(task.deadline!),
            color: overdue ? DdtTheme.dangerColor : null,
          ),
        if (_inSpace && executorId != null) _TaskCardUser(userId: executorId),
      ],
    );
  }
}

class _TaskCardUser extends StatelessWidget {
  const _TaskCardUser({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: loadDirectoryUsers(),
      builder: (context, snapshot) {
        final person = directoryUserById(
          snapshot.data ?? const <UserProfile>[],
          userId,
        );
        final waiting =
            snapshot.connectionState == ConnectionState.waiting &&
            person == null;
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 220.w;
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: DdtUserChip(
                      name:
                          person?.label ??
                          (waiting ? 'Загрузка…' : 'Пользователь'),
                      userId: person?.id ?? userId,
                      email: person?.email,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? Color.lerp(color, Colors.white, 0.36)!
        : Color.lerp(color, Colors.black, 0.14)!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: DdtTheme.badgeBorderRadius,
        border: Border.all(color: color.withValues(alpha: isDark ? 0.38 : 0.24)),
      ),
      child: Text(
        label,
        style: DdtTheme.style(
          fontSize: DdtTypography.captionSize,
          fontWeight: FontWeight.w600,
          color: labelColor,
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.icon, required this.label, this.color});

  final FaIconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = color ?? DdtTheme.textSecondary(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF1F5F9),
        borderRadius: DdtTheme.badgeBorderRadius,
        border: Border.all(
          color: (color ?? DdtTheme.borderSubtle(context)).withValues(
            alpha: color == null ? 1 : (isDark ? 0.38 : 0.28),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DdtIcon(icon, size: 11.sp, color: tint),
          SizedBox(width: 4.w),
          Text(
            label,
            style: DdtTheme.style(
              fontSize: DdtTypography.captionSize,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
