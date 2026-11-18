import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import 'ddt_adaptive.dart';
import 'ddt_icon.dart';
import 'ddt_mobile_navigation_bar.dart';

class DdtGlassFab extends StatefulWidget {
  const DdtGlassFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
  });

  static const double size = 48;

  /// Same gap between the create button and the navigation bar on every screen.
  static const double navigationGap = 4;

  static double bottomOffset(BuildContext context) {
    final nav = DdtAdaptive.floatingBottomBar(context)
        ? DdtMobileNavigationBar.clearance(context)
        : 0.0;
    return nav + navigationGap;
  }

  final VoidCallback onPressed;
  final FaIconData icon;
  final String? label;
  final String? tooltip;

  @override
  State<DdtGlassFab> createState() => _DdtGlassFabState();
}

class _DdtGlassFabState extends State<DdtGlassFab> {
  bool _hovered = false;
  bool _pressed = false;

  static const _animationDuration = Duration(milliseconds: 160);
  static const _animationCurve = Curves.easeOutCubic;

  double get _scale {
    if (_pressed) return 0.96;
    if (_hovered) return 1.05;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    final fill = isDark
        ? DdtTheme.darkSurface.withValues(alpha: 0.55)
        : DdtTheme.lightSurface.withValues(alpha: 0.62);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.72);
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: AnimatedScale(
        scale: _scale,
        duration: _animationDuration,
        curve: _animationCurve,
        child: UnconstrainedBox(
          child: SizedBox(
            width: DdtGlassFab.size,
            height: DdtGlassFab.size,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.36 : 0.10,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    onTap: widget.onPressed,
                    child: Center(
                      child: DdtIcon(
                        widget.icon,
                        size: 18,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip ?? widget.label;
    final tappable = kIsWeb ? PointerInterceptor(child: button) : button;
    if (tooltip == null) return tappable;
    return Tooltip(message: tooltip, child: tappable);
  }
}
