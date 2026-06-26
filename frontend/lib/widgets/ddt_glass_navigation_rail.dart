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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                isDark: isDark,
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

class _NavigationRailItem extends StatefulWidget {
  const _NavigationRailItem({
    required this.section,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final AppSection section;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_NavigationRailItem> createState() => _NavigationRailItemState();
}

class _NavigationRailItemState extends State<_NavigationRailItem> {
  bool _hovered = false;

  Color _foregroundColor(BuildContext context) {
    if (widget.isDark) {
      if (widget.isSelected) {
        return AppColors.primary;
      }
      return _hovered
          ? Colors.white.withValues(alpha: 0.88)
          : Colors.white.withValues(alpha: 0.58);
    }

    if (widget.isSelected) {
      return DdtTheme.loginTitleColor(context);
    }

    return _hovered
        ? DdtTheme.lightTextPrimary
        : DdtTheme.textSecondary(context);
  }

  Color _backgroundColor() {
    if (widget.isSelected) {
      return AppColors.primary.withValues(
        alpha: widget.isDark
            ? (_hovered ? 0.26 : 0.2)
            : (_hovered ? 0.16 : 0.12),
      );
    }

    if (!_hovered) {
      return Colors.transparent;
    }

    return AppColors.primary.withValues(
      alpha: widget.isDark ? 0.12 : 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _foregroundColor(context);
    final backgroundColor = _backgroundColor();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          padding: EdgeInsets.symmetric(
            vertical: DdtTheme.shellSizeOf(context, 10),
            horizontal: DdtTheme.shellSizeOf(context, 4),
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: DdtTheme.radius,
          ),
          child: AnimatedScale(
            scale: _hovered ? 1.04 : 1,
            alignment: Alignment.center,
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: foregroundColor),
              duration: DdtTheme.selectionAnimationDuration,
              curve: DdtTheme.selectionAnimationCurve,
              builder: (context, color, _) {
                final resolvedColor = color ?? foregroundColor;
                final labelStyle = DdtTheme.style(
                  fontSize: 10.sp,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: resolvedColor,
                  height: 1.15,
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.section.icon,
                      color: resolvedColor,
                      size: DdtTheme.shellSizeOf(context, 22),
                    ),
                    SizedBox(height: DdtTheme.shellSizeOf(context, 4)),
                    Text(
                      widget.section.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
