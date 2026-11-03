import 'package:flutter/material.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import 'ddt_icon.dart';

/// Circular back control used on fullscreen create screens.
class DdtRoundBackButton extends StatelessWidget {
  const DdtRoundBackButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final String tooltip;

  static const double size = 32;

  /// Shared inset of the button from the left edge of the page content.
  static const double screenInset = 4;

  /// Gap between the button and the "New …" label.
  static const double labelGap = 6;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: DdtIcon(DdtIcons.chevronLeft, size: 13, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
