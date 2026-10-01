import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_icon.dart';

/// Full-width primary action at the top of a sidebar (tasks create, mail compose).
class DdtPanelPrimaryButton extends StatefulWidget {
  const DdtPanelPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final FaIconData icon;
  final VoidCallback onPressed;

  @override
  State<DdtPanelPrimaryButton> createState() => _DdtPanelPrimaryButtonState();
}

class _DdtPanelPrimaryButtonState extends State<DdtPanelPrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = AppColors.primary;
    final fill = _hovered
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: isDark ? 0.14 : 0.2),
            base,
          )
        : base;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hovered ? 1.015 : 1,
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            width: double.infinity,
            height: 28,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: DdtTheme.radius,
              boxShadow: _hovered
                  ? DdtTheme.inputFocusShadow(context)
                  : [
                      BoxShadow(
                        color: base.withValues(alpha: 0.22),
                        blurRadius: 4,
                        offset: Offset(0, 1.5.h),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _hovered ? 1.08 : 1,
                  duration: DdtTheme.selectionAnimationDuration,
                  curve: DdtTheme.selectionAnimationCurve,
                  child: DdtIcon(widget.icon, size: 14.sp, color: Colors.white),
                ),
                SizedBox(width: 8.w),
                Text(
                  widget.label,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSmallSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
