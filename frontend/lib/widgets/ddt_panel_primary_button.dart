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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = _pressed
        ? const Color(0xFF3730A3)
        : _hovered
        ? (isDark ? const Color(0xFF5B52F0) : DdtTheme.primaryHoverColor)
        : DdtTheme.primaryColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          width: double.infinity,
          height: 32,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: DdtTheme.inputControlBorderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: DdtTheme.primaryColor.withValues(
                  alpha: _hovered ? 0.30 : 0.18,
                ),
                blurRadius: _hovered ? 8 : 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              DdtIcon(widget.icon, size: 13.sp, color: Colors.white),
              SizedBox(width: 7.w),
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
    );
  }
}
