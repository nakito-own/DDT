import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_section.dart';
import '../theme/ddt_theme.dart';
import '../widgets/ddt_icon.dart';

class DdtGlassNavigationRail extends StatelessWidget {
  const DdtGlassNavigationRail({
    super.key,
    required this.selectedSection,
    required this.onSectionSelected,
  });

  final AppSection selectedSection;
  final ValueChanged<AppSection> onSectionSelected;

  static const double railWidth = 52;
  static const double _railTopInset = 10;
  static const double _railBottomInset = 8;

  static final List<AppSection> _primarySections = AppSection.values
      .where((section) => section != AppSection.settings)
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: DdtTheme.glass(
        context: context,
        showBorder: true,
        width: DdtTheme.shellSizeOf(context, railWidth),
        height: double.infinity,
        padding: EdgeInsets.fromLTRB(
          DdtTheme.shellSizeOf(context, 6),
          DdtTheme.shellSizeOf(context, _railTopInset),
          DdtTheme.shellSizeOf(context, 6),
          DdtTheme.shellSizeOf(context, _railBottomInset),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _primarySections.length; i++) ...[
              _NavigationRailItem(
                section: _primarySections[i],
                isSelected: _primarySections[i] == selectedSection,
                isDark: isDark,
                onTap: () => onSectionSelected(_primarySections[i]),
              ),
              if (i < _primarySections.length - 1)
                SizedBox(height: DdtTheme.shellSizeOf(context, 4)),
            ],
            const Spacer(),
            Container(
              height: 1,
              margin: EdgeInsets.symmetric(
                horizontal: DdtTheme.shellSizeOf(context, 6),
                vertical: DdtTheme.shellSizeOf(context, 6),
              ),
              color: DdtTheme.borderSubtle(context),
            ),
            _NavigationRailItem(
              section: AppSection.settings,
              isSelected: selectedSection == AppSection.settings,
              isDark: isDark,
              onTap: () => onSectionSelected(AppSection.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationRailItem extends StatefulWidget {
  const _NavigationRailItem({
    required this.section,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final AppSection section;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_NavigationRailItem> createState() => _NavigationRailItemState();
}

class _NavigationRailItemState extends State<_NavigationRailItem>
    with SingleTickerProviderStateMixin {
  static const Duration _tooltipFadeIn = Duration(milliseconds: 140);
  static const Duration _tooltipFadeOut = Duration(milliseconds: 75);

  bool _hovered = false;
  final LayerLink _tooltipLink = LayerLink();
  OverlayEntry? _tooltipOverlay;
  late final AnimationController _tooltipController;
  late final Animation<Offset> _tooltipSlide;

  @override
  void initState() {
    super.initState();
    _tooltipController = AnimationController(
      vsync: this,
      duration: _tooltipFadeIn,
      reverseDuration: _tooltipFadeOut,
    );
    _tooltipSlide = Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _tooltipController,
        curve: Curves.fastOutSlowIn,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _tooltipOverlay?.remove();
    _tooltipOverlay?.dispose();
    _tooltipController.dispose();
    super.dispose();
  }

  void _showTooltip() {
    if (!mounted) return;

    if (_tooltipOverlay == null) {
      _tooltipOverlay = OverlayEntry(
        builder: (context) => Stack(
          clipBehavior: Clip.none,
          children: [
            _RailSideTooltip(
              link: _tooltipLink,
              message: widget.section.label,
              opacity: _tooltipController,
              slide: _tooltipSlide,
            ),
          ],
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(_tooltipOverlay!);
    }

    _tooltipController.forward();
  }

  Future<void> _hideTooltip() async {
    final entry = _tooltipOverlay;
    if (entry == null) return;

    if (_tooltipController.status != AnimationStatus.dismissed) {
      await _tooltipController.reverse();
    }
    if (!mounted || _hovered) return;

    entry.remove();
    entry.dispose();
    if (_tooltipOverlay == entry) {
      _tooltipOverlay = null;
    }
  }

  Color _foregroundColor(BuildContext context) {
    if (widget.isSelected) {
      return widget.isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    }
    if (_hovered) {
      return DdtTheme.textPrimary(context);
    }
    return DdtTheme.textMuted(context);
  }

  Color _backgroundColor() {
    if (widget.isSelected) {
      return DdtTheme.primaryColor.withValues(
        alpha: widget.isDark
            ? (_hovered ? 0.24 : 0.18)
            : (_hovered ? 0.15 : 0.10),
      );
    }

    if (widget.isDark) {
      return Colors.white.withValues(alpha: _hovered ? 0.07 : 0.0);
    }

    return DdtTheme.primaryColor.withValues(alpha: _hovered ? 0.09 : 0.0);
  }

  Color _borderColor() {
    if (widget.isSelected) {
      return DdtTheme.primaryColor.withValues(
        alpha: widget.isDark ? 0.32 : 0.20,
      );
    }
    return DdtTheme.primaryColor.withValues(alpha: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _foregroundColor(context);
    final backgroundColor = _backgroundColor();
    final borderColor = _borderColor();
    final itemRadius = BorderRadius.circular(
      DdtTheme.shellSizeOf(context, DdtTheme.inputControlRadius),
    );

    return CompositedTransformTarget(
      link: _tooltipLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hovered = true);
          _showTooltip();
        },
        onExit: (_) {
          setState(() => _hovered = false);
          unawaited(_hideTooltip());
        },
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: DdtTheme.selectionAnimationDuration,
                curve: DdtTheme.selectionAnimationCurve,
                padding: EdgeInsets.symmetric(
                  vertical: DdtTheme.shellSizeOf(context, 10),
                  horizontal: DdtTheme.shellSizeOf(context, 4),
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: itemRadius,
                  border: Border.all(color: borderColor),
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: foregroundColor),
                  duration: DdtTheme.selectionAnimationDuration,
                  curve: DdtTheme.selectionAnimationCurve,
                  builder: (context, color, _) {
                    final resolvedColor = color ?? foregroundColor;

                    return Center(
                      child: DdtIcon(
                        widget.section.icon,
                        color: resolvedColor,
                        size: DdtTheme.shellSizeOf(context, 18),
                      ),
                    );
                  },
                ),
              ),
              AnimatedContainer(
                duration: DdtTheme.selectionAnimationDuration,
                curve: DdtTheme.selectionAnimationCurve,
                width: DdtTheme.shellSizeOf(context, 3),
                height: widget.isSelected
                    ? DdtTheme.shellSizeOf(context, 18)
                    : 0,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? DdtTheme.accentColor
                      : DdtTheme.primaryColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailSideTooltip extends StatelessWidget {
  const _RailSideTooltip({
    required this.link,
    required this.message,
    required this.opacity,
    required this.slide,
  });

  final LayerLink link;
  final String message;
  final Animation<double> opacity;
  final Animation<Offset> slide;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final gap = DdtTheme.shellSizeOf(context, _gap);

    return CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.centerRight,
      followerAnchor: Alignment.centerLeft,
      offset: Offset(gap, 0),
      showWhenUnlinked: false,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: opacity,
          child: SlideTransition(
            position: slide,
            child: _MaterialTooltipBox(message: message),
          ),
        ),
      ),
    );
  }
}

/// Matches default [Tooltip] appearance from Material.
class _MaterialTooltipBox extends StatelessWidget {
  const _MaterialTooltipBox({required this.message});

  final String message;

  static double _fontSize(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        12.0,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS =>
        14.0,
    };
  }

  static EdgeInsets _padding(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS =>
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    };
  }

  static double _minHeight(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        26.0,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.iOS =>
        32.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooltipTheme = TooltipTheme.of(context);
    final platform = theme.platform;

    final (TextStyle defaultTextStyle, BoxDecoration defaultDecoration) =
        switch (theme.brightness) {
          Brightness.dark => (
            theme.textTheme.bodyMedium!.copyWith(
              color: DdtTheme.darkTextPrimary,
              fontSize: _fontSize(platform),
            ),
            BoxDecoration(
              color: const Color(0xFF232C3F).withValues(alpha: 0.94),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Brightness.light => (
            theme.textTheme.bodyMedium!.copyWith(
              color: Colors.white,
              fontSize: _fontSize(platform),
            ),
            BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.92),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
          ),
        };

    final textStyle = tooltipTheme.textStyle ?? defaultTextStyle;
    final decoration = tooltipTheme.decoration ?? defaultDecoration;
    final padding = tooltipTheme.padding ?? _padding(platform);
    final margin = tooltipTheme.margin ?? EdgeInsets.zero;
    final constraints =
        tooltipTheme.constraints ??
        BoxConstraints(minHeight: _minHeight(platform));

    return ConstrainedBox(
      constraints: constraints,
      child: DefaultTextStyle(
        style: textStyle,
        textAlign: tooltipTheme.textAlign ?? TextAlign.start,
        child: Container(
          decoration: decoration,
          padding: padding,
          margin: margin,
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(message, style: textStyle),
          ),
        ),
      ),
    );
  }
}
