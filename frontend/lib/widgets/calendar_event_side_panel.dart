import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../theme/ddt_theme.dart';
import 'ddt_side_panel.dart';

Future<void> showCalendarEventSidePanel(
  BuildContext context,
  CalendarEvent event,
) {
  return showDdtSidePanel<void>(
    context,
    child: CalendarEventSidePanel(event: event),
  );
}

class CalendarEventSidePanel extends StatefulWidget {
  const CalendarEventSidePanel({super.key, required this.event});

  final CalendarEvent event;

  @override
  State<CalendarEventSidePanel> createState() => _CalendarEventSidePanelState();
}

class _CalendarEventSidePanelState extends State<CalendarEventSidePanel> {
  late CalendarEvent _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  Future<void> _respond(CalendarEventResponseAction action) async {
    context
        .read<CalendarBloc>()
        .add(CalendarEventRespondRequested(event: _event, action: action));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_responseSuccessMessage(action))),
    );
  }

  String _responseSuccessMessage(CalendarEventResponseAction action) {
    return switch (action) {
      CalendarEventResponseAction.accept => 'Приглашение принято',
      CalendarEventResponseAction.decline => 'Приглашение отклонено',
      CalendarEventResponseAction.tentative => 'Ответ «Предварительно» отправлен',
    };
  }

  static final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.sidePanelTextPrimary(context);
    final textSecondary = DdtTheme.sidePanelTextSecondary(context);
    final pending = _event.needsResponse;

    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) =>
          previous.isResponding != current.isResponding,
      builder: (context, state) => DdtSidePanelShell(
        title: 'Событие',
        footer: _event.isMeeting
            ? _ResponseActions(
                event: _event,
                isLoading: state.isResponding,
                onRespond: _respond,
              )
            : null,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 16.h, bottom: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _event.subject,
              style: DdtTheme.style(
                fontSize: 22.sp,
                fontWeight: pending ? FontWeight.w800 : FontWeight.w700,
                color: textPrimary,
              ),
            ),
            if (_event.isMeeting) ...[
              SizedBox(height: 12.h),
              _ResponseStatusBadge(
                event: _event,
                color: textSecondary,
              ),
            ],
            SizedBox(height: 20.h),
            if (_event.start != null)
              _InfoField(
                icon: CupertinoIcons.time,
                label: 'Начало',
                value: _dateFormat.format(_event.start!.toLocal()),
                color: textSecondary,
              ),
            if (_event.end != null) ...[
              SizedBox(height: 14.h),
              _InfoField(
                icon: CupertinoIcons.time_solid,
                label: 'Окончание',
                value: _dateFormat.format(_event.end!.toLocal()),
                color: textSecondary,
              ),
            ],
            if (_event.location != null && _event.location!.isNotEmpty) ...[
              SizedBox(height: 14.h),
              _InfoField(
                icon: CupertinoIcons.location,
                label: 'Место',
                value: _event.location!,
                color: textSecondary,
              ),
            ],
            if (_event.organizer != null && _event.organizer!.isNotEmpty) ...[
              SizedBox(height: 14.h),
              _InfoField(
                icon: CupertinoIcons.person,
                label: 'Организатор',
                value: _event.organizer!,
                color: textSecondary,
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

class _ResponseStatusBadge extends StatelessWidget {
  const _ResponseStatusBadge({
    required this.event,
    required this.color,
  });

  final CalendarEvent event;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = event.needsResponse;
    final background = pending
        ? AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.1)
        : (event.isDeclined
            ? Colors.grey.withValues(alpha: isDark ? 0.18 : 0.12)
            : AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08));
    final borderColor = pending
        ? AppColors.primary.withValues(alpha: 0.55)
        : color.withValues(alpha: 0.25);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: DdtTheme.radius,
        border: Border.all(color: borderColor, width: pending ? 1.5 : 1),
      ),
      child: Row(
        children: [
          if (pending)
            Container(
              width: 8.w,
              height: 8.w,
              margin: EdgeInsets.only(right: 8.w),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            event.responseLabel,
            style: DdtTheme.style(
              fontSize: 13.sp,
              fontWeight: pending ? FontWeight.w700 : FontWeight.w600,
              color: pending ? AppColors.primary : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseActions extends StatelessWidget {
  const _ResponseActions({
    required this.event,
    required this.isLoading,
    required this.onRespond,
  });

  final CalendarEvent event;
  final bool isLoading;
  final ValueChanged<CalendarEventResponseAction> onRespond;

  @override
  Widget build(BuildContext context) {
    if (!event.needsResponse && !event.isTentative) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (event.needsResponse) ...[
          Button(
            text: isLoading ? 'Отправка...' : 'Принять',
            borderRadius: DdtTheme.radius,
            onPressed: isLoading
                ? null
                : () => onRespond(CalendarEventResponseAction.accept),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Button(
                  text: 'Предварительно',
                  type: ButtonType.outlined,
                  borderRadius: DdtTheme.radius,
                  onPressed: isLoading
                      ? null
                      : () => onRespond(CalendarEventResponseAction.tentative),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Button(
                  text: 'Отклонить',
                  type: ButtonType.outlined,
                  borderRadius: DdtTheme.radius,
                  onPressed: isLoading
                      ? null
                      : () => onRespond(CalendarEventResponseAction.decline),
                ),
              ),
            ],
          ),
        ] else if (event.isTentative) ...[
          Row(
            children: [
              Expanded(
                child: Button(
                  text: isLoading ? 'Отправка...' : 'Принять',
                  borderRadius: DdtTheme.radius,
                  onPressed: isLoading
                      ? null
                      : () => onRespond(CalendarEventResponseAction.accept),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Button(
                  text: 'Отклонить',
                  type: ButtonType.outlined,
                  borderRadius: DdtTheme.radius,
                  onPressed: isLoading
                      ? null
                      : () => onRespond(CalendarEventResponseAction.decline),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15.sp, color: color),
            SizedBox(width: 6.w),
            Text(
              label,
              style: DdtTheme.style(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: DdtTheme.style(
            fontSize: 15.sp,
            color: DdtTheme.sidePanelTextPrimary(context),
          ),
        ),
      ],
    );
  }
}
