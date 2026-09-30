import 'package:flutter/material.dart';

import '../theme/ddt_theme.dart';
import 'ddt_glass_app_bar.dart';
import 'ddt_shell_layout.dart';

/// Vertical rule between a side panel and main content: inset below the app
/// bar and above the bottom edge (same gap as [DdtShellLayout] shell inset).
class DdtSidePanelDivider extends StatelessWidget {
  const DdtSidePanelDivider({super.key, this.color});

  final Color? color;

  static EdgeInsets _padding(BuildContext context) {
    final edgeInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing);
    final railLeftInset =
        DdtTheme.shellSizeOf(context, DdtShellLayout.railAreaLeftInset);
    final barHeight =
        DdtTheme.shellSizeOf(context, DdtGlassAppBar.barHeight);
    final belowAppBar = railLeftInset + barHeight + edgeInset;

    return EdgeInsets.only(top: belowAppBar, bottom: edgeInset);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _padding(context),
      child: Container(
        width: 1,
        color: color ?? DdtTheme.sidePanelDivider(context),
      ),
    );
  }
}
