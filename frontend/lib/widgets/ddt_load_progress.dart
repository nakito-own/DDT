import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_dialog.dart';

/// Shows the dashboard skeleton and paints the load status on a full-screen
/// dim, the same veil a modal uses. The status itself is not wrapped in a window.
class DashboardLoadVeil extends StatefulWidget {
  const DashboardLoadVeil({
    super.key,
    required this.skeleton,
    required this.title,
    required this.detail,
    this.showProgress = true,
    this.progress,
    this.error,
    this.action,
  });

  final Widget skeleton;
  final String title;
  final String detail;
  final bool showProgress;
  final double? progress;
  final String? error;
  final Widget? action;

  @override
  State<DashboardLoadVeil> createState() => _DashboardLoadVeilState();
}

class _DashboardLoadVeilState extends State<DashboardLoadVeil> {
  OverlayEntry? _entry;
  bool _inserted = false;
  bool _frameScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleOverlay();
  }

  @override
  void didUpdateWidget(covariant DashboardLoadVeil oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOverlay();
  }

  /// The root overlay is an ancestor and has already built this frame.
  /// Inserting or marking it dirty here throws.
  void _scheduleOverlay() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;
      if (!_inserted) {
        final overlay = Overlay.maybeOf(context, rootOverlay: true);
        if (overlay == null) return;
        _entry = OverlayEntry(builder: _buildStatus);
        overlay.insert(_entry!);
        _inserted = true;
        return;
      }
      _entry?.markNeedsBuild();
    });
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _inserted = false;
    super.dispose();
  }

  Widget _buildStatus(BuildContext context) {
    const foreground = Colors.white;
    final barrier = DdtModalBarrier(
      animation: const AlwaysStoppedAnimation<double>(1),
    );
    final status = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: DdtTheme.style(
                  fontSize: DdtTypography.panelTitleSize,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
              SizedBox(height: 14.h),
              if (widget.error != null)
                Text(
                  widget.error!,
                  textAlign: TextAlign.center,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    height: 1.4,
                    color: const Color(0xFFFFABAB),
                  ),
                )
              else if (widget.showProgress)
                DdtLoadProgress(
                  label: widget.detail,
                  value: widget.progress,
                  foreground: foreground,
                )
              else
                Text(
                  widget.detail,
                  textAlign: TextAlign.center,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    height: 1.4,
                    color: foreground.withValues(alpha: 0.92),
                  ),
                ),
              if (widget.action != null) ...[
                SizedBox(height: 16.h),
                widget.action!,
              ],
            ],
          ),
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          kIsWeb ? PointerInterceptor(child: barrier) : barrier,
          SafeArea(child: status),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: widget.skeleton);
  }
}

/// Rounded progress bar. A null [value] plays the indeterminate animation.
class DdtLoadProgress extends StatelessWidget {
  const DdtLoadProgress({
    super.key,
    required this.label,
    this.value,
    this.foreground,
  });

  final String label;

  /// Fraction from 0 to 1. Null means the total size is not known yet.
  final double? value;

  /// Label and track color. Set when the bar sits on the modal dim.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fraction = value?.clamp(0.0, 1.0);
    final percent = fraction == null ? null : (fraction * 100).round();
    final foreground = this.foreground;
    final track = foreground == null
        ? DdtTheme.textMuted(context).withValues(alpha: 0.16)
        : foreground.withValues(alpha: 0.28);
    final labelColor =
        foreground?.withValues(alpha: 0.92) ?? DdtTheme.textSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: fraction == null
              ? LinearProgressIndicator(
                  minHeight: 8.h,
                  backgroundColor: track,
                  color: DdtTheme.primaryColor,
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: fraction),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, animated, _) {
                    return LinearProgressIndicator(
                      value: animated,
                      minHeight: 8.h,
                      backgroundColor: track,
                      color: DdtTheme.primaryColor,
                    );
                  },
                ),
        ),
        SizedBox(height: 8.h),
        Text(
          percent == null ? label : '$label · $percent%',
          textAlign: foreground == null ? TextAlign.start : TextAlign.center,
          style: DdtTheme.style(
            fontSize: DdtTypography.captionSize,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
