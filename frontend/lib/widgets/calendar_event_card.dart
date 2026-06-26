import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../theme/ddt_theme.dart';

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

    return _StandardEventCard(
      event: event,
      compact: compact,
      onTap: onTap,
    );
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
    final pending = event.needsResponse;
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
            highlighted: pending,
            onTap: onTap,
            child: Opacity(
              opacity: declined ? 0.72 : 1,
              child: child,
            ),
          ),
          if (pending)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
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
    final timeColor = DdtTheme.taskCardIconMuted(context);
    final iconMuted = DdtTheme.taskCardIconMuted(context);
    final pending = event.needsResponse;
    final timeLabel = _formatTimeRange(DateFormat('HH:mm'));
    final showTime = height >= 34 && timeLabel != null;
    final showIcon = height >= 26;
    final titleLines = showTime ? 1 : (height >= 24 ? 2 : 1);
    final titleSize = (height * 0.36).clamp(10.5, 14.sp);
    final metaSize = (height * 0.26).clamp(8.5, 11.sp);
    final cornerRadius = _plannerCornerRadius(height);
    final leftPad = pending ? 6.0 : (showIcon ? 6.0 : 5.0);
    final hPad = showIcon ? leftPad : leftPad;
    final vPad = height >= 34 ? 5.0 : 3.0;

    return SizedBox(
      height: height,
      width: width,
      child: _EventCardShell(
        event: event,
        onTap: onTap,
        cornerRadius: cornerRadius,
        padding: EdgeInsets.fromLTRB(hPad, vPad, 5, vPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pending && height >= 22) ...[
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2, right: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    if (showIcon && !pending) ...[
                      Icon(
                        CupertinoIcons.calendar,
                        size: (height * 0.22).clamp(11.0, 14.sp),
                        color: iconMuted,
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Expanded(
                      child: Text(
                        event.subject,
                        maxLines: titleLines,
                        overflow: TextOverflow.ellipsis,
                        style: DdtTheme.style(
                          fontSize: titleSize,
                          fontWeight: pending ? FontWeight.w700 : FontWeight.w600,
                          color: textPrimary,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showTime) ...[
              SizedBox(height: 2.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.time,
                    size: metaSize,
                    color: timeColor,
                  ),
                  SizedBox(width: 3.w),
                  Flexible(
                    child: Text(
                      timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: metaSize,
                        fontWeight: FontWeight.w500,
                        color: timeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _formatTimeRange(DateFormat timeFormat) {
    final start = event.start?.toLocal();
    final end = event.end?.toLocal();
    if (start == null) return null;
    if (end == null) return timeFormat.format(start);
    return '${timeFormat.format(start)} – ${timeFormat.format(end)}';
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
    final timeColor = DdtTheme.taskCardIconMuted(context);
    final iconMuted = DdtTheme.taskCardIconMuted(context);
    final pending = event.needsResponse;
    final timeFormat = DateFormat('HH:mm');
    final timeLabel = _formatTimeRange(timeFormat);
    final cornerRadius =
        compact ? _calendarCardRadiusCompact.r : _calendarCardRadius.r;

    return _EventCardShell(
      event: event,
      onTap: onTap,
      cornerRadius: cornerRadius,
      padding: EdgeInsets.fromLTRB(
        pending ? (compact ? 10.w : 14.w) : (compact ? 8.w : DdtTheme.spacing.w),
        compact ? 6.h : 10.h,
        compact ? 8.w : DdtTheme.spacing.w,
        compact ? 6.h : 10.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact && !pending) ...[
                Icon(
                  CupertinoIcons.calendar,
                  size: 18.sp,
                  color: iconMuted,
                ),
                SizedBox(width: 8.w),
              ],
              if (pending) ...[
                Container(
                  width: 8.w,
                  height: 8.w,
                  margin: EdgeInsets.only(top: compact ? 2.h : 4.h, right: 6.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  event.subject,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: compact ? 11.sp : 14.sp,
                    fontWeight: pending ? FontWeight.w700 : FontWeight.w600,
                    color: textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (timeLabel != null) ...[
            SizedBox(height: compact ? 4.h : 8.h),
            _MetaRow(
              icon: CupertinoIcons.time,
              label: timeLabel,
              color: timeColor,
              fontSize: compact ? 10.sp : 12.sp,
              iconSize: compact ? 12.sp : 14.sp,
            ),
          ],
          if (!compact &&
              event.location != null &&
              event.location!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            _MetaRow(
              icon: CupertinoIcons.location,
              label: event.location!,
              color: textSecondary,
              fontSize: 12.sp,
              iconSize: 14.sp,
            ),
          ],
        ],
      ),
    );
  }

  String? _formatTimeRange(DateFormat timeFormat) {
    final start = event.start?.toLocal();
    final end = event.end?.toLocal();
    if (start == null) return null;
    if (end == null) return timeFormat.format(start);
    return '${timeFormat.format(start)} – ${timeFormat.format(end)}';
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

  final IconData icon;
  final String label;
  final Color color;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: color),
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
