import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/app_section.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_shell_metrics.dart';

/// Sections that do not fit on the phone tab bar.
class AdditionsPage extends StatelessWidget {
  const AdditionsPage({super.key});

  static const sections = [
    AppSection.contacts,
    AppSection.analytics,
    AppSection.space,
    AppSection.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final scrollPadding = DdtShellMetrics.scrollPadding(context);
    final gap = DdtTheme.shellSizeOf(context, 8);

    return DdtScrollEdgeFade(
      child: ListView.separated(
        padding: scrollPadding.copyWith(
          top: scrollPadding.top + DdtTheme.shellSizeOf(context, 20),
          left: DdtTheme.shellSizeOf(context, 16),
          right: DdtTheme.shellSizeOf(context, 16),
          bottom:
              scrollPadding.bottom +
              DdtTheme.shellSizeOf(context, DdtTheme.spacing),
        ),
        itemCount: sections.length,
        separatorBuilder: (context, index) => SizedBox(height: gap),
        itemBuilder: (context, index) {
          final section = sections[index];
          return DdtTheme.glass(
            context: context,
            padding: EdgeInsets.symmetric(
              horizontal: DdtTheme.shellSizeOf(context, 14),
              vertical: DdtTheme.shellSizeOf(context, 14),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.go(section.routePath),
              child: Row(
                children: [
                  DdtIcon(
                    section.icon,
                    size: DdtTheme.shellSizeOf(context, 16),
                    color: DdtTheme.textPrimary(context),
                  ),
                  SizedBox(width: DdtTheme.shellSizeOf(context, 12)),
                  Expanded(
                    child: Text(
                      section.label,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.bodySize,
                        fontWeight: FontWeight.w600,
                        color: DdtTheme.textPrimary(context),
                      ),
                    ),
                  ),
                  DdtIcon(
                    DdtIcons.chevronRight,
                    size: DdtTheme.shellSizeOf(context, 12),
                    color: DdtTheme.textMuted(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
