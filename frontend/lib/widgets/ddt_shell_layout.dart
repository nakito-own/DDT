import 'package:flutter/material.dart';

import '../models/app_section.dart';
import '../theme/ddt_theme.dart';
import 'ddt_app_bar_section_actions.dart';
import 'ddt_glass_app_bar.dart';
import 'ddt_glass_navigation_rail.dart';

class DdtShellLayout extends StatelessWidget {
  const DdtShellLayout({
    super.key,
    required this.title,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.child,
    this.padContent = true,
  });

  final String title;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;
  final Widget child;
  final bool padContent;

  static const double _railAreaLeftInset = 8;

  @override
  Widget build(BuildContext context) {
    final shellInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing);
    final contentTopInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing / 2);
    final railLeftInset = DdtTheme.shellSizeOf(context, _railAreaLeftInset);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.all(railLeftInset).copyWith(bottom: 0),
              child: DdtGlassAppBar(
                title: title,
                actions: DdtAppBarSectionActions(section: selectedSection),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  railLeftInset,
                  contentTopInset,
                  shellInset,
                  shellInset,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DdtGlassNavigationRail(
                      selectedSection: selectedSection,
                      onSectionSelected: onSectionSelected,
                    ),
                    SizedBox(width: contentTopInset),
                    Expanded(
                      child: padContent
                          ? Padding(
                              padding: EdgeInsets.fromLTRB(
                                shellInset,
                                contentTopInset,
                                shellInset,
                                shellInset,
                              ),
                              child: child,
                            )
                          : child,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
