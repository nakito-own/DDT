import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/app_section.dart';
import '../theme/ddt_theme.dart';

class DdtGlassNavigationRail extends StatelessWidget {
  const DdtGlassNavigationRail({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;

  static const double railWidth = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : AppColors.primary;

    return RepaintBoundary(
      child: DdtTheme.glass(
        context: context,
        width: DdtTheme.shellSizeOf(context, railWidth),
        height: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: DdtTheme.shellSizeOf(context, 12),
          horizontal: DdtTheme.shellSizeOf(context, 8),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in AppSection.values) ...[
            _NavigationRailItem(
              section: section,
              isSelected: section == selectedSection,
              foregroundColor: foregroundColor,
              onTap: () => onSectionSelected(section),
            ),
            if (section != AppSection.values.last)
              SizedBox(height: DdtTheme.shellSizeOf(context, 4)),
          ],
          const Spacer(),
        ],
        ),
      ),
    );
  }
}

class _NavigationRailItem extends StatelessWidget {
  const _NavigationRailItem({
    required this.section,
    required this.isSelected,
    required this.foregroundColor,
    required this.onTap,
  });

  final AppSection section;
  final bool isSelected;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : foregroundColor.withValues(alpha: 0.75);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DdtTheme.radius,
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: DdtTheme.radius,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: DdtTheme.shellSizeOf(context, 10),
              horizontal: DdtTheme.shellSizeOf(context, 4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  section.icon,
                  color: color,
                  size: DdtTheme.shellSizeOf(context, 22),
                ),
                SizedBox(height: DdtTheme.shellSizeOf(context, 4)),
                Text(
                  section.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: color,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
