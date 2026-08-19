import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme/ddt_theme.dart';

class DdtGlassFab extends StatefulWidget {
  const DdtGlassFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String? label;

  @override
  State<DdtGlassFab> createState() => _DdtGlassFabState();
}

class _DdtGlassFabState extends State<DdtGlassFab> {
  bool _hovered = false;
  bool _pressed = false;

  static const _animationDuration = Duration(milliseconds: 160);
  static const _animationCurve = Curves.easeOutCubic;
  static const _hoverScale = 1.05;
  static const _pressedScale = 0.96;

  double get _scale {
    if (_pressed) return _pressedScale;
    if (_hovered) return _hoverScale;
    return 1.0;
  }

  Widget _buildContent(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final label = widget.label;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: 20.sp, color: AppColors.primary),
        if (label != null) ...[
          SizedBox(width: 8.w),
          Text(
            label,
            style: DdtTheme.style(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTapLayer() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: const SizedBox.expand(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DdtTheme.taskCardGlass(
              context: context,
              padding: widget.label == null
                  ? EdgeInsets.all(14.w)
                  : EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
              child: _buildContent(context),
            ),
            Positioned.fill(
              child: kIsWeb
                  ? PointerInterceptor(child: _buildTapLayer())
                  : _buildTapLayer(),
            ),
          ],
        ),
      ),
    );
  }
}
