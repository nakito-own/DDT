import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../models/task_status.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/task_formatters.dart';
import 'ddt_section_refresh.dart';
import '../widgets/ddt_icon.dart';

/// Kanban-shaped loading placeholder with shimmering empty cards.
class KanbanBoardSkeleton extends StatelessWidget {
  const KanbanBoardSkeleton({super.key});

  static const _cardHeights = {
    TaskStatus.todo: [112.0, 88.0, 100.0],
    TaskStatus.inProgress: [108.0, 92.0],
    TaskStatus.done: [96.0, 84.0],
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < TaskStatus.values.length; index++) ...[
                if (index > 0) DdtTheme.horizontalGap(),
                Expanded(
                  child: _SkeletonColumn(status: TaskStatus.values[index]),
                ),
              ],
            ],
          );
        }

        return SizedBox(
          height: constraints.maxHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: TaskStatus.values.length,
            separatorBuilder: (context, index) => DdtTheme.horizontalGap(),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 320.w,
                child: _SkeletonColumn(status: TaskStatus.values[index]),
              );
            },
          ),
        );
      },
    );
  }
}

class _SkeletonColumn extends StatelessWidget {
  const _SkeletonColumn({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = statusColumnColor(status);
    final baseTrack = isDark
        ? DdtTheme.darkSurface.withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.62);
    final columnColor = Color.alphaBlend(
      statusColor.withValues(alpha: isDark ? 0.06 : 0.04),
      baseTrack,
    );
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : DdtTheme.lightBorderSubtle.withValues(alpha: 0.90);
    final heights = KanbanBoardSkeleton._cardHeights[status] ?? const [100.0];

    return ClipRRect(
      borderRadius: DdtTheme.radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.all(DdtTheme.spacing.w),
          decoration: BoxDecoration(
            color: columnColor,
            borderRadius: DdtTheme.radius,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SkeletonColumnHeader(status: status),
              SizedBox(height: DdtTheme.spacing.h),
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: heights.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(height: DdtTheme.spacing.h),
                  itemBuilder: (context, index) {
                    return _SkeletonTaskCard(height: heights[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonColumnHeader extends StatelessWidget {
  const _SkeletonColumnHeader({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = statusColumnColor(status);

    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.35),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            status.label,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodyLargeSize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.textPrimary(context),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.80),
            borderRadius: DdtTheme.badgeBorderRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : DdtTheme.lightBorderSubtle,
            ),
          ),
          child: Text(
            '0',
            style: DdtTheme.style(
              fontSize: DdtTypography.captionSize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.textSecondary(context),
            ),
          ),
        ),
        SizedBox(width: 6.w),
        IgnorePointer(
          child: IconButton(
            tooltip: 'Добавить задачу',
            onPressed: () {},
            icon: DdtIcon(
              DdtIcons.add,
              size: 16.sp,
              color: DdtTheme.textSecondary(context),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

class _SkeletonTaskCard extends StatelessWidget {
  const _SkeletonTaskCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DdtTheme.radius,
      child: SizedBox(
        height: height.h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DdtTheme.taskCardGlass(
              context: context,
              padding: EdgeInsets.zero,
              child: const SizedBox.expand(),
            ),
            const DdtShimmerSweep(visible: true),
          ],
        ),
      ),
    );
  }
}
