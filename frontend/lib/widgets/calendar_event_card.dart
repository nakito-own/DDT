import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../models/calendar_event.dart';
import '../models/colleague_calendar.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

const _calendarCardRadius = 5.0;
const _calendarCardRadiusCompact = 4.0;

class CalendarEventCard extends StatelessWidget {
  const CalendarEventCard({
    super.key,
    required this.event,
    this.compact = false,
    this.onTap,
    this.maxHeight,
    this.maxWidth,
  });

  final CalendarEvent event;
  final bool compact;
  final VoidCallback? onTap;
  final double? maxHeight;
  final double? maxWidth;

  bool get _isPlannerSlot => maxHeight != null && maxWidth != null;

  @override
  Widget build(BuildContext context) {
    if (_isPlannerSlot) {
      return _PlannerEventTile(
        event: event,
        height: maxHeight!,
        width: maxWidth!,
        onTap: onTap,
      );
    }

    return _StandardEventCard(event: event, compact: compact, onTap: onTap);
  }
}

double _plannerCornerRadius(double height) =>
    (height * 0.1).clamp(3.0, _calendarCardRadius);

class _EventCardShell extends StatelessWidget {
  const _EventCardShell({
    required this.event,
    required this.onTap,
    required this.cornerRadius,
    required this.padding,
    required this.child,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;
  final double cornerRadius;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final confirmed = !event.needsResponse;
    final declined = event.isDeclined;

    return ClipRRect(
      borderRadius: BorderRadius.circular(cornerRadius),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DdtTheme.calendarEventGlass(
            context: context,
            cornerRadius: cornerRadius,
            padding: padding,
            confirmed: confirmed,
            accent: CalendarPalette.colorFor(event.colorIndex),
            onTap: onTap,
            child: Opacity(opacity: declined ? 0.72 : 1, child: child),
          ),
          if (!confirmed)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DashedBorderPainter(
                    color: CalendarPalette.colorFor(event.colorIndex),
                    radius: cornerRadius,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _EventAccent(
              color: CalendarPalette.colorFor(event.colorIndex),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - strokeWidth * 2),
      math.max(0, size.height - strokeWidth * 2),
    );
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.max(0, radius - inset)),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _EventAccent extends StatelessWidget {
  const _EventAccent({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: const SizedBox(width: 6),
    );
  }
}

class _PlannerEventTile extends StatelessWidget {
  const _PlannerEventTile({
    required this.event,
    required this.height,
    required this.width,
    this.onTap,
  });

  final CalendarEvent event;
  final double height;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final titleSize = (height * 0.32).clamp(
      DdtTypography.microSize,
      DdtTypography.bodySize,
    );
    const lineHeight = 1.2;
    final cornerRadius = _plannerCornerRadius(height);
    final vPad = height >= 28 ? 4.0 : 2.0;
    final contentHeight = math.max(0.0, height - vPad * 2);
    final titleLines = math.max(
      1,
      (contentHeight / (titleSize * lineHeight)).floor(),
    );

    return SizedBox(
      height: height,
      width: width,
      child: _EventCardShell(
        event: event,
        onTap: onTap,
        cornerRadius: cornerRadius,
        padding: EdgeInsets.fromLTRB(10, vPad, 5, vPad),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            event.subject,
            softWrap: true,
            maxLines: titleLines,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              height: lineHeight,
            ),
          ),
        ),
      ),
    );
  }
}

class _StandardEventCard extends StatelessWidget {
  const _StandardEventCard({
    required this.event,
    required this.compact,
    this.onTap,
  });

  final CalendarEvent event;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final textSecondary = DdtTheme.taskCardTextSecondary(context);
    final cornerRadius = compact
        ? _calendarCardRadiusCompact.r
        : _calendarCardRadius.r;
    final hasLocation =
        !compact && event.location != null && event.location!.isNotEmpty;

    return _EventCardShell(
      event: event,
      onTap: onTap,
      cornerRadius: cornerRadius,
      padding: EdgeInsets.fromLTRB(
        compact ? 10.w : 12.w,
        compact ? 6.h : 10.h,
        compact ? 8.w : 10.w,
        compact ? 6.h : 10.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.subject,
            softWrap: true,
            maxLines: compact ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: compact
                  ? DdtTypography.captionSize
                  : DdtTypography.bodySize,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              height: 1.2,
            ),
          ),
          if (hasLocation) ...[
            SizedBox(height: 6.h),
            _MetaRow(
              icon: DdtIcons.location,
              label: event.location!,
              color: textSecondary,
              fontSize: DdtTypography.labelSmallSize,
              iconSize: 14.sp,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.fontSize,
    required this.iconSize,
  });

  final FaIconData icon;
  final String label;
  final Color color;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtIcon(icon, size: iconSize, color: color),
        SizedBox(width: 4.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
