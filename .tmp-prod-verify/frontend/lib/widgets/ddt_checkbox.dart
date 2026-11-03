import 'package:flutter/material.dart';
import '../theme/ddt_icons.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

/// Единый чекбокс приложения с общей анимацией и визуальными состояниями.
class DdtCheckbox extends StatefulWidget {
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
  State<DdtCheckbox> createState() => _DdtCheckboxState();
}

class _DdtCheckboxState extends State<DdtCheckbox> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && widget.onChanged != null;
    final activeColor = DdtTheme.primaryColor.withValues(
      alpha: isEnabled ? 1 : 0.48,
    );
    final uncheckedBorder = _hovered && isEnabled
        ? DdtTheme.borderStrong(context)
        : DdtTheme.inputBorderColor(
            context,
          ).withValues(alpha: isEnabled ? 0.85 : 0.45);

    final indicator = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: widget.value ? activeColor : DdtTheme.inputFillColor(context),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: widget.value ? activeColor : uncheckedBorder,
          width: 1.4,
        ),
        boxShadow: widget.value && isEnabled
            ? [
                BoxShadow(
                  color: DdtTheme.primaryColor.withValues(alpha: 0.22),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: widget.value ? 1 : 0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: DdtIcon(
          DdtIcons.check,
          size: 11,
          color: Colors.white,
          fitParent: true,
        ),
      ),
    );

    return Semantics(
      checked: widget.value,
      enabled: isEnabled,
      label: widget.label,
      child: MouseRegion(
        onEnter: isEnabled ? (_) => setState(() => _hovered = true) : null,
        onExit: isEnabled ? (_) => setState(() => _hovered = false) : null,
        child: InkWell(
          onTap: isEnabled ? () => widget.onChanged!(!widget.value) : null,
          borderRadius: DdtTheme.inputControlBorderRadius,
          child: Padding(
            padding: widget.padding,
            child: Row(
              mainAxisSize: widget.label == null
                  ? MainAxisSize.min
                  : MainAxisSize.max,
              children: [
                indicator,
                if (widget.label != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label!,
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
      ),
    );
  }
}
