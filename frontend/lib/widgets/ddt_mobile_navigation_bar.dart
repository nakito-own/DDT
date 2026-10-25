import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_native/liquid_glass_native.dart';

import '../models/app_section.dart';
import '../theme/ddt_theme.dart';
import 'ddt_adaptive.dart';
import 'ddt_icon.dart';

/// Bottom navigation for phone layouts.
///
/// iPhone uses the system tab bar, which is Liquid Glass on iOS 26.
/// Web and Android use a floating frosted rectangle in the same stack slot,
/// so page content and the scroll-edge gradient run underneath it.
class DdtMobileNavigationBar extends StatelessWidget {
  const DdtMobileNavigationBar({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;

  static const List<AppSection> tabs = [
    AppSection.tasks,
    AppSection.mail,
    AppSection.calendar,
    AppSection.notes,
    AppSection.more,
  ];

  static const List<String> _symbols = [
    'checklist',
    'envelope',
    'calendar',
    'square.and.pencil',
    'square.grid.2x2',
  ];

  static const double _bodyHeight = 56;
  static const double _bottomGap = 10;
  static const double _horizontalMargin = 12;
  static const double _innerHorizontalPadding = 10;
  static const double _radius = 28;

  /// How much of the screen bottom the floating bar covers.
  static double clearance(BuildContext context) {
    if (DdtAdaptive.usesLiquidGlassNavigation) return 100;
    return _bodyHeight + _bottomGap + MediaQuery.paddingOf(context).bottom;
  }

  static int indexOf(AppSection section) {
    final index = tabs.indexOf(section);
    return index == -1 ? tabs.length - 1 : index;
  }

  void _select(int index) {
    final section = tabs[index];
    if (section == selectedSection) return;
    onSectionSelected(section);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = indexOf(selectedSection);
    if (DdtAdaptive.usesLiquidGlassNavigation) {
      return LiquidGlassTabBar(
        currentIndex: currentIndex,
        tint: DdtTheme.primaryColor,
        brightness: Theme.of(context).brightness,
        onTap: _select,
        items: [
          for (var i = 0; i < tabs.length; i++)
            TabItem(label: tabs[i].label, sfSymbol: _symbols[i]),
        ],
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = DdtTheme.textSecondary(context);
    final selected = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    final fill = isDark
        ? DdtTheme.darkSurface.withValues(alpha: 0.55)
        : DdtTheme.lightSurface.withValues(alpha: 0.62);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.72);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _horizontalMargin,
        0,
        _horizontalMargin,
        bottom + _bottomGap,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _innerHorizontalPadding,
                ),
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  removeTop: true,
                  child: NavigationBar(
                    selectedIndex: currentIndex,
                    height: _bodyHeight,
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    indicatorColor: selected.withValues(
                      alpha: isDark ? 0.28 : 0.16,
                    ),
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    labelPadding: const EdgeInsets.only(top: 1),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final isSelected = states.contains(WidgetState.selected);
                      return TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        letterSpacing: 0,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected ? selected : foreground,
                      );
                    }),
                    onDestinationSelected: _select,
                    destinations: [
                      for (final tab in tabs)
                        NavigationDestination(
                          tooltip: tab.label,
                          label: tab.label,
                          icon: DdtIcon(tab.icon, size: 20, color: foreground),
                          selectedIcon: DdtIcon(
                            tab.icon,
                            size: 20,
                            color: selected,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
