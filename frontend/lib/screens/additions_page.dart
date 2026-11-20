import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_section.dart';
import '../utils/section_navigation.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_shell_metrics.dart';
import 'settings_page.dart';

/// Phone "more" section: profile, then a two-column grid of areas.
class AdditionsPage extends StatelessWidget {
  const AdditionsPage({super.key});

  static const _problemReportUri = 'https://t.me/panovv';
  static const _maxContentWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final scrollPadding = DdtShellMetrics.scrollPadding(context);
    final gap = DdtTheme.shellSizeOf(context, 12);
    final tiles = _tiles(context);
    final rows = <Widget>[
      const UserProfileSettingsSection(),
      SizedBox(height: gap),
    ];
    for (var index = 0; index < tiles.length; index += 2) {
      if (index > 0) rows.add(SizedBox(height: gap));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[index]),
            SizedBox(width: gap),
            Expanded(child: tiles[index + 1]),
          ],
        ),
      );
    }

    return DdtScrollEdgeFade(
      child: SingleChildScrollView(
        padding: scrollPadding.copyWith(
          top: scrollPadding.top + DdtTheme.shellSizeOf(context, 8),
          left: DdtTheme.shellSizeOf(context, 4),
          right: DdtTheme.shellSizeOf(context, 4),
          bottom:
              DdtShellMetrics.contentBottomPadding(context) +
              DdtTheme.shellSizeOf(context, DdtTheme.spacing),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _tiles(BuildContext context) {
    const sections = [
      AppSection.boards,
      AppSection.contacts,
      AppSection.analytics,
      AppSection.space,
      AppSection.settings,
    ];
    return [
      for (final section in sections)
        _AdditionTile(
          icon: section.icon,
          label: section.label,
          onTap: () => openAppSection(context, section),
        ),
      _AdditionTile(
        icon: DdtIcons.warning,
        label: 'Сообщить о проблеме',
        alert: true,
        onTap: () {
          launchUrl(
            Uri.parse(_problemReportUri),
            mode: LaunchMode.externalApplication,
          );
        },
      ),
    ];
  }
}

class _AdditionTile extends StatelessWidget {
  const _AdditionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.alert = false,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool alert;

  static const _height = 112.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leading = alert ? DdtTheme.warningColor : DdtTheme.accentColor;
    final trailing = alert ? DdtTheme.dangerColor : DdtTheme.successColor;
    final iconColor = alert
        ? DdtTheme.warningColor
        : (isDark ? DdtTheme.accentColor : DdtTheme.primaryColor);
    final head = isDark ? 0.11 : 0.06;
    final tail = isDark ? 0.015 : 0.01;
    final mark = DdtTheme.shellSizeOf(context, 36);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DdtTheme.glass(
          context: context,
          height: _height,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        leading.withValues(alpha: head),
                        leading.withValues(alpha: tail),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        trailing.withValues(alpha: head),
                        trailing.withValues(alpha: tail),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: DdtTheme.shellSizeOf(context, 12),
                right: DdtTheme.shellSizeOf(context, 12),
                child: DdtIcon(
                  DdtIcons.chevronRight,
                  size: DdtTheme.shellSizeOf(context, 12),
                  color: DdtTheme.textMuted(context),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(DdtTheme.shellSizeOf(context, 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: mark,
                      height: mark,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(
                          DdtTheme.shellSizeOf(context, 10),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: DdtIcon(
                        icon,
                        size: DdtTheme.shellSizeOf(context, 16),
                        color: iconColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: DdtTypography.bodySize,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: DdtTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
