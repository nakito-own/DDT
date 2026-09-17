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

  @override
  Widget build(BuildContext context) {
    final shellInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing);
    final contentTopInset = DdtTheme.shellSizeOf(context, DdtTheme.spacing / 2);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(shellInset),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DdtGlassNavigationRail(
                selectedSection: selectedSection,
                onSectionSelected: onSectionSelected,
              ),
              SizedBox(width: shellInset),
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
                    SizedBox(height: contentTopInset),
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
            ],
          ),
        ),
      ),
    );
  }
}
