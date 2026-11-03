import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';

class TaskTypeBadge extends StatelessWidget {
  const TaskTypeBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark
        ? Color.lerp(DdtTheme.accentColor, Colors.white, 0.25)!
        : Color.lerp(DdtTheme.primaryColor, Colors.black, 0.12)!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: DdtTheme.primaryColor.withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: DdtTheme.badgeBorderRadius,
        border: Border.all(
          color: (isDark ? DdtTheme.accentColor : DdtTheme.primaryColor)
              .withValues(alpha: isDark ? 0.36 : 0.22),
        ),
      ),
      child: Text(
        label,
        style: DdtTheme.style(
          fontSize: DdtTypography.captionSize,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
