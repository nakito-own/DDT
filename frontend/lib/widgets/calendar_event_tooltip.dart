import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../models/calendar_meeting_link.dart';
import '../router/route_paths.dart';
import '../screens/event_create_page.dart';
import '../services/ews_api.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/calendar_body_html.dart';
import '../utils/ddt_toast.dart';
import 'ddt_adaptive.dart';
import 'ddt_arrow_tooltip.dart';
import 'ddt_icon.dart';
import 'ddt_side_panel.dart';
import 'ddt_user_chip.dart';

const _tooltipDuration = Duration(milliseconds: 280);
const _contentPad = 16.0;

/// Marks the calendar surface so the event tooltip stays inside it.
class CalendarTooltipHost extends StatefulWidget {
  const CalendarTooltipHost({super.key, required this.child});

  final Widget child;

  @override
  State<CalendarTooltipHost> createState() => _CalendarTooltipHostState();
}

class _CalendarTooltipHostState extends State<CalendarTooltipHost> {
  Rect? overlayBounds() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final overlayBox = overlay?.context.findRenderObject();
    final offset = overlayBox is RenderBox
        ? box.localToGlobal(Offset.zero, ancestor: overlayBox)
        : box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

OverlayEntry? _activeTooltip;
var _eventSheetOpen = false;

void showCalendarEventTooltip(BuildContext context, CalendarEvent event) {
  if (DdtAdaptive.isCompact(context)) {
    if (_eventSheetOpen) return;
    _eventSheetOpen = true;
    showDdtFullscreenBottomSheet<void>(
      context,
      child: Builder(
        builder: (sheetContext) => CalendarEventTooltip(
          event: event,
          onClose: () => Navigator.of(sheetContext).maybePop(),
        ),
      ),
    ).whenComplete(() => _eventSheetOpen = false);
    return;
  }

  final anchor = _anchorInOverlay(context);
  final host = context.findAncestorStateOfType<_CalendarTooltipHostState>();
  final theme = Theme.of(context);
  final bloc = context.read<CalendarBloc>();
  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  var removed = false;
  void close() {
    if (removed) return;
    removed = true;
    entry.remove();
    if (identical(_activeTooltip, entry)) _activeTooltip = null;
  }

  entry = OverlayEntry(
    builder: (overlayContext) => Theme(
      data: theme,
      child: BlocProvider.value(
        value: bloc,
        child: _CalendarEventTooltipLayer(
          anchor: anchor,
          event: event,
          onClosed: close,
          readBounds: () => host?.overlayBounds(),
        ),
      ),
    ),
  );

  _activeTooltip?.remove();
  _activeTooltip = entry;
  overlay.insert(entry);
}

Rect? _anchorInOverlay(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  final overlayBox = Overlay.of(
    context,
    rootOverlay: true,
  ).context.findRenderObject();
  final offset = overlayBox is RenderBox
      ? box.localToGlobal(Offset.zero, ancestor: overlayBox)
      : box.localToGlobal(Offset.zero);
  return offset & box.size;
}

class _CalendarEventTooltipLayer extends StatefulWidget {
  const _CalendarEventTooltipLayer({
    required this.anchor,
    required this.event,
    required this.onClosed,
    required this.readBounds,
  });

  final Rect? anchor;
  final CalendarEvent event;
  final VoidCallback onClosed;
  final Rect? Function() readBounds;

  @override
  State<_CalendarEventTooltipLayer> createState() =>
      _CalendarEventTooltipLayerState();
}

class _CalendarEventTooltipLayerState extends State<_CalendarEventTooltipLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _tooltipDuration,
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    await _controller.reverse();
    if (!mounted) return;
    widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final limit = widget.readBounds();
    final placement = ddtPlaceArrowTooltip(
      screen: media.size,
      padding: media.padding,
      anchor: widget.anchor,
      limit: limit,
    );
    final rect = ddtFitTipInside(placement.outer, limit);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          unawaited(_dismiss());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final t = _animation.value;
          final slide = (1 - t) * 8;
          final offset = ddtTipSlideOffset(placement.side, slide);
          final tip = Opacity(
            opacity: t,
            child: Transform.scale(
              alignment: ddtTipScaleAlignment(placement.side),
              scale: 0.94 + 0.06 * t,
              child: child,
            ),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) => unawaited(_dismiss()),
                  child: const SizedBox.expand(),
                ),
              ),
              if (limit == null)
                Positioned(
                  left: rect.left + offset.dx,
                  top: rect.top + offset.dy,
                  width: rect.width,
                  height: rect.height,
                  child: tip,
                )
              else
                Positioned.fromRect(
                  rect: limit,
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: rect.left - limit.left + offset.dx,
                          top: rect.top - limit.top + offset.dy,
                          width: rect.width,
                          height: rect.height,
                          child: tip,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        child: DdtArrowTip(
          side: placement.side,
          arrowCenter: placement.arrowCenter,
          showArrow: placement.showArrow,
          child: CalendarEventTooltip(
            event: widget.event,
            onClose: () => unawaited(_dismiss()),
          ),
        ),
      ),
    );
  }
}

class CalendarEventTooltip extends StatefulWidget {
  const CalendarEventTooltip({
    super.key,
    required this.event,
    required this.onClose,
  });

  final CalendarEvent event;
  final VoidCallback onClose;

  @override
  State<CalendarEventTooltip> createState() => _CalendarEventTooltipState();
}

class _CalendarEventTooltipState extends State<CalendarEventTooltip> {
  late CalendarEvent _event;
  bool _loadingDetail = false;
  CalendarEventResponseAction? _pendingAction;

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

  void _respond(CalendarEventResponseAction action) {
    if (_event.isColleague || _pendingAction != null) return;
    setState(() => _pendingAction = action);
    context.read<CalendarBloc>().add(
      CalendarEventRespondRequested(event: _event, action: action),
    );
  }

  void _onResponded(CalendarState state) {
    final action = _pendingAction;
    if (action == null) return;
    if (state.errorMessage != null) {
      setState(() => _pendingAction = null);
      DdtToast.show(message: state.errorMessage!, type: ToastType.error);
      return;
    }
    CalendarEvent? updated;
    for (final item in state.events) {
      if (item.id == _event.id) {
        updated = item;
        break;
      }
    }
    final response =
        updated?.myResponseType ??
        switch (action) {
          CalendarEventResponseAction.accept => 'Accept',
          CalendarEventResponseAction.decline => 'Decline',
          CalendarEventResponseAction.tentative => 'Tentative',
        };
    setState(() {
      _pendingAction = null;
      _event = _event.copyWith(
        myResponseType: response,
        needsResponse: updated?.needsResponse ?? false,
      );
    });
    DdtToast.show(
      message: _responseSuccessMessage(action),
      type: ToastType.success,
    );
  }

  void _edit(CalendarState calendar) {
    final draft = EventCreateDraft.fromEvent(
      _event,
      ownerEmail: calendar.ownerEmail,
    );
    final router = GoRouter.of(context);
    widget.onClose();
    router.push(RoutePaths.calendarNew, extra: draft);
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
    return BlocConsumer<CalendarBloc, CalendarState>(
      listenWhen: (previous, current) =>
          previous.isResponding && !current.isResponding,
      listener: (context, state) => _onResponded(state),
      buildWhen: (previous, current) =>
          previous.isResponding != current.isResponding ||
          previous.ownerEmail != current.ownerEmail ||
          previous.ownerDisplayName != current.ownerDisplayName,
      builder: (context, state) {
        final canEdit = _event.authoredBy(
          email: state.ownerEmail,
          displayName: state.ownerDisplayName,
        );
        final canRespond = _event.isMeeting && !_event.isColleague && !canEdit;
        final showStatus = _event.isMeeting && !_event.isColleague;
        final link = meetingLinkFor(
          location: _event.location,
          html: _event.body,
        );
        final place = locationWithoutLinks(_event.location);
        final when = _whenLabel(_event);
        final requiredAttendees = [
          for (final attendee in _event.attendees)
            if (!attendee.optional) attendee,
        ];
        final optionalAttendees = [
          for (final attendee in _event.attendees)
            if (attendee.optional) attendee,
        ];
        final calendarName = _event.isColleague
            ? _event.ownerName
            : 'Мои события';
        final pad = _contentPad.w;
        final topBand = 76.h;
        final bottomBand = showStatus || canRespond ? 72.h : 0.0;

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    pad,
                    topBand,
                    pad,
                    bottomBand > 0 ? bottomBand : pad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (when != null)
                        _FieldLine(label: 'Время и дата', value: when),
                      if (_event.isRecurring)
                        const _FieldLine(label: 'Повтор', value: 'Повторяется'),
                      if ((place != null && place.isNotEmpty) || link != null)
                        _FieldLine(
                          label: 'Место',
                          valueWidget: _PlaceValue(place: place, link: link),
                        ),
                      if (_event.organizer != null &&
                          _event.organizer!.isNotEmpty)
                        _FieldLine(
                          label: 'Организатор',
                          value: _event.organizer!,
                        ),
                      if (requiredAttendees.isNotEmpty)
                        _FieldLine(
                          label: 'Участники',
                          valueWidget: _AttendeeChips(
                            attendees: requiredAttendees,
                          ),
                        ),
                      if (optionalAttendees.isNotEmpty)
                        _FieldLine(
                          label: 'Опциональные участники',
                          valueWidget: _AttendeeChips(
                            attendees: optionalAttendees,
                          ),
                        ),
                      if (calendarName != null && calendarName.isNotEmpty)
                        _FieldLine(
                          label: 'Календарь',
                          valueWidget: _CalendarValue(
                            name: calendarName,
                            own: !_event.isColleague,
                          ),
                        ),
                      if (_event.isLimited)
                        const _FieldLine(
                          label: 'Сведения',
                          value: 'Ограниченные сведения (занятость)',
                        ),
                      if (_loadingDetail) ...[
                        SizedBox(height: 8.h),
                        const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ],
                      if (_event.body != null && _event.body!.trim().isNotEmpty)
                        _FieldLine(
                          label: 'Описание',
                          valueWidget: _event.bodyType == 'html'
                              ? _AgendaHtml(html: _event.body!)
                              : Text(
                                  _event.body!,
                                  textAlign: TextAlign.start,
                                  style: DdtTheme.style(
                                    fontSize: DdtTypography.bodySize,
                                    height: 1.45,
                                    color: DdtTheme.sidePanelTextPrimary(
                                      context,
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topBand,
                child: _EdgeFade(
                  top: true,
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 6, pad, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _event.subject,
                            textAlign: TextAlign.start,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DdtTheme.style(
                              fontSize: DdtTypography.panelTitleSize,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: DdtTheme.sidePanelTextPrimary(context),
                            ),
                          ),
                        ),
                        if (canEdit)
                          _TooltipIconButton(
                            icon: DdtIcons.edit,
                            tooltip: 'Редактировать',
                            onTap: () => _edit(state),
                          ),
                        _TooltipIconButton(
                          icon: DdtIcons.close,
                          tooltip: 'Закрыть',
                          onTap: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showStatus || canRespond)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: bottomBand,
                  child: _EdgeFade(
                    top: false,
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 2, pad, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (showStatus)
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _ResponseStatusBadge(event: _event),
                              ),
                            )
                          else
                            const Spacer(),
                          if (canRespond) ...[
                            if (showStatus) SizedBox(width: 8.w),
                            _ResponseActions(
                              isLoading:
                                  state.isResponding || _pendingAction != null,
                              pending: _pendingAction,
                              onRespond: _respond,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

const _weekdays = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String? _whenLabel(CalendarEvent event) {
  final start = event.start?.toLocal();
  if (start == null) return null;
  final end = event.end?.toLocal();
  final time = DateFormat('HH:mm');
  final head = _dayHeading(start);
  if (end == null) return '$head, ${time.format(start)}';
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) {
    return '$head, ${time.format(start)} — ${time.format(end)}';
  }
  return '$head, ${time.format(start)} — ${_dayHeading(end)}, ${time.format(end)}';
}

String _dayHeading(DateTime date) {
  return '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
}

class _AttendeeChips extends StatefulWidget {
  const _AttendeeChips({required this.attendees});

  final List<CalendarAttendee> attendees;

  @override
  State<_AttendeeChips> createState() => _AttendeeChipsState();
}

class _AttendeeChipsState extends State<_AttendeeChips> {
  static const _previewCount = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final attendees = widget.attendees;
    final hidden = !_expanded && attendees.length > _previewCount;
    final visible = hidden ? attendees.take(_previewCount) : attendees;
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final attendee in visible)
          DdtUserChip(
            name: attendee.name,
            email: attendee.email,
            avatarSize: 22,
            fontSize: DdtTypography.labelSize,
          ),
        if (hidden)
          _MoreAttendeesButton(onTap: () => setState(() => _expanded = true)),
      ],
    );
  }
}

class _MoreAttendeesButton extends StatelessWidget {
  const _MoreAttendeesButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.72),
      borderRadius: DdtTheme.badgeBorderRadius,
      child: InkWell(
        borderRadius: DdtTheme.badgeBorderRadius,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            borderRadius: DdtTheme.badgeBorderRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : DdtTheme.lightBorderSubtle.withValues(alpha: 0.9),
            ),
          ),
          child: Text(
            '…',
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              fontWeight: FontWeight.w700,
              height: 1,
              color: DdtTheme.sidePanelTextPrimary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceValue extends StatelessWidget {
  const _PlaceValue({required this.place, required this.link});

  final String? place;
  final CalendarMeetingLink? link;

  @override
  Widget build(BuildContext context) {
    final name = place?.trim() ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (name.isNotEmpty)
          Expanded(
            child: Text(
              name,
              textAlign: TextAlign.start,
              style: DdtTheme.style(
                fontSize: DdtTypography.bodySize,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: DdtTheme.sidePanelTextPrimary(context),
              ),
            ),
          ),
        if (link != null) ...[
          if (name.isNotEmpty) SizedBox(width: 8.w),
          _JoinButton(link: link!),
        ],
      ],
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
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (link.asset.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: Image.asset(
                    link.asset,
                    width: 16.w,
                    height: 16.w,
                    fit: BoxFit.contain,
                  ),
                )
              else
                DdtIcon(DdtIcons.link, size: 14.sp, color: Colors.white),
              SizedBox(width: 8.w),
              Text(
                'Подключиться',
                style: DdtTheme.style(
                  fontSize: DdtTypography.bodySize,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8.w),
              DdtIcon(DdtIcons.arrowUpRight, size: 13.sp, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaHtml extends StatelessWidget {
  const _AgendaHtml({required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = DdtTheme.sidePanelTextPrimary(context);
    final link = _cssColor(DdtTheme.primaryColor);
    return HtmlWidget(
      adaptCalendarBodyHtml(html, isDark: isDark),
      textStyle: DdtTheme.style(
        fontSize: DdtTypography.bodySize,
        height: 1.45,
        color: color,
      ),
      onTapUrl: _openUrl,
      customStylesBuilder: (element) {
        switch (element.localName) {
          case 'a':
            return {'color': link, 'text-decoration': 'underline'};
          case 'p':
            return {'margin-top': '0', 'margin-bottom': '0.65em'};
          case 'ul':
          case 'ol':
            return {
              'margin-top': '0.2em',
              'margin-bottom': '0.65em',
              'padding-left': '1.3em',
            };
          case 'li':
            return {'margin-bottom': '0.2em'};
          default:
            return null;
        }
      },
    );
  }
}

String _cssColor(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0')}';
}

Future<bool> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({
    required this.top,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  final bool top;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? DdtTheme.darkSurface
        : DdtTheme.lightSurface;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [surface, surface, surface.withValues(alpha: 0)],
              stops: const [0, 0.46, 1],
            ),
          ),
        ),
        Align(alignment: alignment, child: child),
      ],
    );
  }
}

class _TooltipIconButton extends StatelessWidget {
  const _TooltipIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: DdtIcon(
            icon,
            size: 15.sp,
            color: DdtTheme.sidePanelTextSecondary(context),
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

Color _glassForeground(BuildContext context, Color color) {
  if (Theme.of(context).brightness != Brightness.dark) return color;
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness(math.max(hsl.lightness, 0.76))
      .withSaturation(math.min(0.58, math.max(hsl.saturation, 0.22)))
      .toColor();
}

class _ResponseStatusBadge extends StatelessWidget {
  const _ResponseStatusBadge({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final pending = event.needsResponse;
    final declined = event.isDeclined;
    final color = pending
        ? DdtTheme.primaryColor
        : (declined ? DdtTheme.textMuted(context) : DdtTheme.successColor);
    final foreground = _glassForeground(context, color);
    final icon = pending
        ? DdtIcons.clock
        : (declined ? DdtIcons.closeCircle : DdtIcons.checkCircle);

    return _FrostedGlass(
      color: color,
      borderRadius: 8.r,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DdtIcon(icon, size: 13.sp, color: foreground),
            SizedBox(width: 6.w),
            Text(
              event.responseLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSize,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLine extends StatelessWidget {
  const _FieldLine({required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final valueChild =
        valueWidget ??
        Text(
          value ?? '',
          textAlign: TextAlign.start,
          style: DdtTheme.style(
            fontSize: DdtTypography.bodySize,
            fontWeight: FontWeight.w500,
            height: 1.35,
            color: DdtTheme.sidePanelTextPrimary(context),
          ),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: DdtTheme.style(
                fontSize: DdtTypography.bodySize,
                height: 1.35,
                color: DdtTheme.sidePanelTextSecondary(context),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(flex: 8, child: valueChild),
        ],
      ),
    );
  }
}

class _CalendarValue extends StatelessWidget {
  const _CalendarValue({required this.name, required this.own});

  final String name;
  final bool own;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (own) ...[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: DdtTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
        ],
        Flexible(
          child: Text(
            name,
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              fontWeight: FontWeight.w500,
              color: DdtTheme.sidePanelTextPrimary(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponseActions extends StatelessWidget {
  const _ResponseActions({
    required this.isLoading,
    required this.pending,
    required this.onRespond,
  });

  final bool isLoading;
  final CalendarEventResponseAction? pending;
  final ValueChanged<CalendarEventResponseAction> onRespond;

  @override
  Widget build(BuildContext context) {
    final gray = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB7C0CE)
        : const Color(0xFF6B7280);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _RsvpIconButton(
          icon: DdtIcons.check,
          color: DdtTheme.successColor,
          tooltip: 'Принять',
          busy: isLoading && pending == CalendarEventResponseAction.accept,
          onTap: isLoading
              ? null
              : () => onRespond(CalendarEventResponseAction.accept),
        ),
        SizedBox(width: 6.w),
        _RsvpIconButton(
          icon: DdtIcons.close,
          color: DdtTheme.dangerColor,
          tooltip: 'Отклонить',
          busy: isLoading && pending == CalendarEventResponseAction.decline,
          onTap: isLoading
              ? null
              : () => onRespond(CalendarEventResponseAction.decline),
        ),
        SizedBox(width: 6.w),
        _RsvpIconButton(
          icon: DdtIcons.question,
          color: gray,
          tooltip: 'Предварительно',
          busy: isLoading && pending == CalendarEventResponseAction.tentative,
          onTap: isLoading
              ? null
              : () => onRespond(CalendarEventResponseAction.tentative),
        ),
      ],
    );
  }
}

class _RsvpIconButton extends StatelessWidget {
  const _RsvpIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.busy,
    required this.onTap,
  });

  final FaIconData icon;
  final Color color;
  final String tooltip;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = 36.w;
    final foreground = _glassForeground(context, color);
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onTap == null && !busy ? 0.45 : 1,
        child: _FrostedGlass(
          color: color,
          borderRadius: 8.r,
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : DdtIcon(
                      icon,
                      size: 16.sp,
                      color: foreground,
                      fitParent: true,
                      semanticLabel: tooltip,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostedGlass extends StatelessWidget {
  const _FrostedGlass({
    required this.color,
    required this.borderRadius,
    required this.child,
    this.onTap,
  });

  final Color color;
  final double borderRadius;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final surface = isDark ? DdtTheme.darkSurface : DdtTheme.lightSurface;
    final fill = isDark
        ? Color.alphaBlend(
            color.withValues(alpha: 0.22),
            surface.withValues(alpha: 0.94),
          )
        : Color.alphaBlend(
            color.withValues(alpha: 0.4),
            surface.withValues(alpha: 0.68),
          );
    final edge = isDark
        ? color.withValues(alpha: 0.42)
        : Color.alphaBlend(
            Colors.white.withValues(alpha: 0.7),
            color.withValues(alpha: 0.9),
          );
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: edge.withValues(alpha: 0.8)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              splashColor: color.withValues(alpha: 0.16),
              highlightColor: color.withValues(alpha: 0.08),
              borderRadius: radius,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
