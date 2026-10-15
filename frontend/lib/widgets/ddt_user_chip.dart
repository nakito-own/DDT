import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_icon.dart';

/// Compact person mark used in mail and task details: icon in a circle and a name.
class DdtUserChip extends StatelessWidget {
  const DdtUserChip({
    super.key,
    required this.name,
    this.fontWeight = FontWeight.w400,
  });

  final String? name;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(2.w, 3.h, 6.w, 3.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
            ),
            child: DdtIcon(
              DdtIcons.user,
              size: 10.sp,
              color: AppColors.primary,
              fitParent: true,
            ),
          ),
          SizedBox(width: 4.w),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              name ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: DdtTypography.captionSize,
                fontWeight: fontWeight,
                color: DdtTheme.taskCardTextSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
