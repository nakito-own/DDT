import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';

/// Toggle in DDT desktop web styling (solid active indigo track + crisp thumb).
class DdtSwitch extends StatelessWidget {
  const DdtSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  static const double _trackWidth = 42;
  static const double _trackHeight = 24;
  static const double _thumbSize = 18;
  static const double _thumbPadding = 3;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final interactive = enabled && onChanged != null;

    final trackOn = DdtTheme.primaryColor;
    final trackOff = isDark ? const Color(0xFF262B38) : const Color(0xFFCBD5E1);
    final borderColor = value
        ? DdtTheme.primaryColor
        : (isDark ? DdtTheme.darkBorderStrong : DdtTheme.lightBorderStrong);

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          width: _trackWidth.w,
          height: _trackHeight.h,
          decoration: BoxDecoration(
            color: value ? trackOn : trackOff,
            borderRadius: BorderRadius.circular(_trackHeight.r),
            border: Border.all(color: borderColor),
          ),
          child: AnimatedAlign(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.all(_thumbPadding.w),
              child: Container(
                width: _thumbSize.w,
                height: _thumbSize.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.14,
                      ),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
