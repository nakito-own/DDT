import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/task_status.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/task_formatters.dart';
import 'ddt_section_refresh.dart';

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
    final statusColor = statusColumnColor(status);
    final columnColor = statusColor.withValues(
      alpha: status == TaskStatus.inProgress ? 0.12 : 0.08,
    );
    final heights = KanbanBoardSkeleton._cardHeights[status] ?? const [100.0];

    return AppCard(
      type: CardType.outlined,
      borderRadius: DdtTheme.radius,
      padding: EdgeInsets.all(DdtTheme.spacing.w),
      backgroundColor: columnColor,
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
    );
  }
}

class _SkeletonColumnHeader extends StatelessWidget {
  const _SkeletonColumnHeader({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            status.label,
            style: DdtTheme.style(
              fontSize: DdtTypography.sectionTitleSize,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: DdtTheme.radius,
          ),
          child: Text(
            '0',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        IgnorePointer(
          child: IconButton(
            tooltip: 'Добавить задачу',
            onPressed: () {},
            icon: Icon(
              CupertinoIcons.add,
              size: 20.sp,
              color: AppColors.primary,
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
