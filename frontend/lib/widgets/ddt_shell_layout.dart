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
  });

  final String title;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            DdtTheme.shellSizeOf(context, DdtTheme.spacing),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DdtGlassNavigationRail(
                selectedSection: selectedSection,
                onSectionSelected: onSectionSelected,
              ),
              SizedBox(width: DdtTheme.shellSizeOf(context, DdtTheme.spacing)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DdtGlassAppBar(
                      title: title,
                      actions: DdtAppBarSectionActions(
                        section: selectedSection,
                      ),
                    ),
                    SizedBox(
                      height: DdtTheme.shellSizeOf(context, DdtTheme.spacing),
                    ),
                    Expanded(child: RepaintBoundary(child: child)),
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
