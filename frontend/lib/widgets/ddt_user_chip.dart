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
    this.fontWeight = FontWeight.w500,
  });

  final String? name;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(3.w, 2.5.h, 7.w, 2.5.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: DdtTheme.badgeBorderRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.11)
              : DdtTheme.lightBorderSubtle.withValues(alpha: 0.90),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16.w,
            height: 16.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DdtTheme.primaryColor.withValues(
                alpha: isDark ? 0.24 : 0.12,
              ),
            ),
            child: DdtIcon(
              DdtIcons.user,
              size: 9.sp,
              color: isDark ? DdtTheme.accentColor : DdtTheme.primaryColor,
              fitParent: true,
            ),
          ),
          SizedBox(width: 5.w),
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
