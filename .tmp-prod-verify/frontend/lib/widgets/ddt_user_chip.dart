import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_user_avatar.dart';

/// Compact person mark used in mail and task details: icon in a circle and a name.
class DdtUserChip extends StatelessWidget {
  const DdtUserChip({
    super.key,
    required this.name,
    this.userId,
    this.email,
    this.fontWeight = FontWeight.w500,
    this.avatarSize,
    this.fontSize,
  });

  final String? name;
  final int? userId;
  final String? email;
  final FontWeight fontWeight;
  final double? avatarSize;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatar = avatarSize ?? 16.w;
    final compact = avatarSize == null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 3.w : 4.w,
        compact ? 2.5.h : 4.h,
        compact ? 7.w : 10.w,
        compact ? 2.5.h : 4.h,
      ),
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
          DdtUserAvatar(
            size: avatar,
            userId: userId,
            email: email,
            name: userId == null ? name : null,
          ),
          SizedBox(width: compact ? 5.w : 8.w),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              name ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: fontSize ?? DdtTypography.captionSize,
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
