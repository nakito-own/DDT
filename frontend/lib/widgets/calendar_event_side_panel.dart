import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/ddt_icons.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../models/calendar_meeting_link.dart';
import '../services/ews_api.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import 'ddt_side_panel.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

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
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (_event.detailLoaded || _event.isColleague || _event.isLimited) return;
    setState(() => _loadingDetail = true);
    try {
      final detailed = await ewsApi.fetchCalendarEventDetail(_event);
      if (!mounted) return;
      setState(() {
        _event = detailed;
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
    }
  }

  Future<void> _respond(CalendarEventResponseAction action) async {
    if (_event.isColleague) return;
    context.read<CalendarBloc>().add(
      CalendarEventRespondRequested(event: _event, action: action),
    );

    if (!mounted) return;
    DdtToast.show(
      message: _responseSuccessMessage(action),
      type: ToastType.success,
    );
  }

  String _responseSuccessMessage(CalendarEventResponseAction action) {
    return switch (action) {
      CalendarEventResponseAction.accept => 'Приглашение принято',
      CalendarEventResponseAction.decline => 'Приглашение отклонено',
      CalendarEventResponseAction.tentative =>
        'Ответ «Предварительно» отправлен',
    };
  }

  @override
  Widget build(BuildContext context) {
    final link = meetingLinkFor(location: _event.location, html: _event.body);
    final place = locationWithoutLinks(_event.location);
    final when = _whenLabel(_event);

    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) =>
          previous.isResponding != current.isResponding,
      builder: (context, state) => DdtSidePanelShell(
        title: _event.subject,
        footer: _event.isMeeting && !_event.isColleague
            ? _ResponseActions(
                event: _event,
                isLoading: state.isResponding,
                onRespond: _respond,
              )
            : null,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 36.h, bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_event.isMeeting && !_event.isColleague)
                _ResponseStatusBadge(event: _event),
              if (when != null ||
                  (place != null && place.isNotEmpty) ||
                  (_event.organizer != null && _event.organizer!.isNotEmpty) ||
                  (_event.isColleague &&
                      _event.ownerName != null &&
                      _event.ownerName!.isNotEmpty) ||
                  _event.isLimited) ...[
                SizedBox(height: 12.h),
                _DetailCard(
                  children: [
                    if (when != null)
                      _DetailRow(icon: DdtIcons.clock, text: when),
                    if (place != null && place.isNotEmpty)
                      _DetailRow(icon: DdtIcons.location, text: place),
                    if (_event.organizer != null &&
                        _event.organizer!.isNotEmpty)
                      _DetailRow(icon: DdtIcons.user, text: _event.organizer!),
                    if (_event.isColleague &&
                        _event.ownerName != null &&
                        _event.ownerName!.isNotEmpty)
                      _DetailRow(
                        icon: DdtIcons.calendarDay,
                        text: _event.ownerName!,
                      ),
                    if (_event.isLimited)
                      const _DetailRow(
                        icon: DdtIcons.info,
                        text: 'Ограниченные сведения (занятость)',
                      ),
                  ],
                ),
              ],
              if (link != null) ...[
                SizedBox(height: 12.h),
                _JoinButton(link: link),
              ],
              if (_loadingDetail) ...[
                SizedBox(height: 16.h),
                const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
              if (_event.body != null && _event.body!.trim().isNotEmpty) ...[
                SizedBox(height: 12.h),
                _DetailCard(
                  child: _event.bodyType == 'html'
                      ? HtmlWidget(
                          _event.body!,
                          textStyle: DdtTheme.style(
                            fontSize: DdtTypography.bodySize,
                            height: 1.45,
                            color: DdtTheme.sidePanelTextPrimary(context),
                          ),
                          onTapUrl: _openUrl,
                        )
                      : Text(
                          _event.body!,
                          style: DdtTheme.style(
                            fontSize: DdtTypography.bodySize,
                            height: 1.45,
                            color: DdtTheme.sidePanelTextPrimary(context),
                          ),
                        ),
                ),
              ],
              if (_event.attendees.isNotEmpty) ...[
                SizedBox(height: 12.h),
                _AttendeeSection(attendees: _event.attendees),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? _whenLabel(CalendarEvent event) {
  final start = event.start?.toLocal();
  if (start == null) return null;
  final end = event.end?.toLocal();
  final day = DateFormat('dd.MM.yyyy');
  final time = DateFormat('HH:mm');
  if (end == null) return '${day.format(start)}, ${time.format(start)}';
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) {
    return '${day.format(start)}, ${time.format(start)} – ${time.format(end)}';
  }
  return '${day.format(start)} ${time.format(start)} – ${day.format(end)} ${time.format(end)}';
}

Future<bool> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ResponseStatusBadge extends StatelessWidget {
  const _ResponseStatusBadge({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = event.needsResponse;
    final declined = event.isDeclined;
    final color = pending
        ? AppColors.primary
        : (declined
              ? DdtTheme.sidePanelTextSecondary(context)
              : AppColors.primary);
    final background = color.withValues(alpha: isDark ? 0.16 : 0.1);
    final icon = pending
        ? DdtIcons.clock
        : (declined ? DdtIcons.closeCircle : DdtIcons.checkCircle);

    return _DetailCard(
      background: background,
      children: [
        _DetailRow(icon: icon, text: event.responseLabel, color: color),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({this.child, this.children, this.background});

  final Widget? child;
  final List<Widget>? children;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color:
            background ??
            AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: DdtTheme.radius,
      ),
      child: child ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < children!.length; index++) ...[
                if (index > 0) SizedBox(height: 8.h),
                children![index],
              ],
            ],
          ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text, this.color});

  final FaIconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? DdtTheme.sidePanelTextPrimary(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: DdtIcon(icon, size: 14.sp, color: tint),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              fontWeight: FontWeight.w500,
              color: tint,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendeeSection extends StatefulWidget {
  const _AttendeeSection({required this.attendees});

  final List<CalendarAttendee> attendees;

  @override
  State<_AttendeeSection> createState() => _AttendeeSectionState();
}

class _AttendeeSectionState extends State<_AttendeeSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: _DetailCard(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DetailRow(
                      icon: DdtIcons.users,
                      text: 'Приглашённые · ${widget.attendees.length}',
                    ),
                  ),
                  DdtIcon(
                    _expanded ? DdtIcons.chevronDown : DdtIcons.chevronRight,
                    size: 12.sp,
                    color: DdtTheme.sidePanelTextSecondary(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Column(
                    children: [
                      for (var index = 0; index < widget.attendees.length; index++) ...[
                        if (index > 0) SizedBox(height: 8.h),
                        _AttendeeRow(attendee: widget.attendees[index]),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({required this.attendee});

  final CalendarAttendee attendee;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = DdtTheme.sidePanelTextSecondary(context);
    final status = attendee.responseLabel;
    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
            ),
            child: DdtIcon(
              DdtIcons.user,
              size: 13.sp,
              color: AppColors.primary,
              fitParent: true,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              attendee.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: DdtTypography.bodySize,
                color: DdtTheme.sidePanelTextPrimary(context),
              ),
            ),
          ),
          if (status.isNotEmpty) ...[
            SizedBox(width: 8.w),
            Text(
              status,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                color: muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.link});

  final CalendarMeetingLink link;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: DdtTheme.radius,
      child: InkWell(
        borderRadius: DdtTheme.radius,
        onTap: () => _openUrl(link.url),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            children: [
              if (link.asset.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: Image.asset(
                    link.asset,
                    width: 18.w,
                    height: 18.w,
                    fit: BoxFit.contain,
                  ),
                )
              else
                DdtIcon(
                  DdtIcons.link,
                  size: 16.sp,
                  color: Colors.white,
                ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Подключиться',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.bodySize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              DdtIcon(DdtIcons.arrowUpRight, size: 14.sp, color: Colors.white),
            ],
          ),
        ),
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

