import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';

/// Единый чекбокс приложения с общей анимацией и визуальными состояниями.
class DdtCheckbox extends StatelessWidget {
  const DdtCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onChanged != null;
    final activeColor = AppColors.primary.withValues(
      alpha: isEnabled ? 1 : 0.48,
    );

    final indicator = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value
              ? activeColor
              : DdtTheme.inputBorderColor(
                  context,
                ).withValues(alpha: isEnabled ? 0.55 : 0.3),
          width: 1.4,
        ),
        boxShadow: value && isEnabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        scale: value ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      ),
    );

    return Semantics(
      checked: value,
      enabled: isEnabled,
      label: label,
      child: InkWell(
        onTap: isEnabled ? () => onChanged!(!value) : null,
        borderRadius: DdtTheme.inputControlBorderRadius,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: label == null ? MainAxisSize.min : MainAxisSize.max,
            children: [
              indicator,
              if (label != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label!,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.bodySize,
                      fontWeight: FontWeight.w500,
                      color: DdtTheme.textPrimary(
                        context,
                      ).withValues(alpha: isEnabled ? 1 : 0.55),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
