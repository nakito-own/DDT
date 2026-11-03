import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../models/colleague_calendar.dart';
import '../services/ews_api.dart';
import '../theme/ddt_scroll_behavior.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import 'ddt_user_avatar.dart';

const _weekdays = [
  'понедельник',
  'вторник',
  'среда',
  'четверг',
  'пятница',
  'суббота',
  'воскресенье',
];

/// День планируемой встречи: строки участников и их занятость.
class EventScheduleAssistant extends StatefulWidget {
  const EventScheduleAssistant({
    super.key,
    required this.start,
    required this.end,
    required this.participants,
    required this.onStartChanged,
  });

  final DateTime start;
  final DateTime end;
  final List<CalendarPerson> participants;
  final ValueChanged<DateTime> onStartChanged;

  @override
  State<EventScheduleAssistant> createState() => _EventScheduleAssistantState();
}

class _EventScheduleAssistantState extends State<EventScheduleAssistant> {
  static const _rowHeight = 36.0;

  int _generation = 0;
  bool _loading = true;
  List<_ScheduleLane> _lanes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void didUpdateWidget(covariant EventScheduleAssistant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameDay(oldWidget.start, widget.start)) {
      _reload();
      return;
    }
    if (!_samePeople(oldWidget.participants, widget.participants)) {
      _syncParticipants();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    final day = _dateOnly(widget.start.toLocal());
    final dayEnd = day.add(const Duration(days: 1));
    final owner = context.read<CalendarBloc>().state;
    final ownerEmail = owner.ownerEmail?.trim().toLowerCase();
    final calendars = <ColleagueCalendar>[];
    for (var index = 0; index < widget.participants.length; index++) {
      final person = widget.participants[index];
      final email = person.email.trim().toLowerCase();
      if (email.isEmpty || email == ownerEmail) continue;
      calendars.add(
        ColleagueCalendar(
          email: email,
          displayName: _personName(person),
          colorIndex: (index % (CalendarPalette.colors.length - 1)) + 1,
        ),
      );
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    final ownFuture = ownerEmail == null
        ? Future.value((events: const <CalendarEvent>[], error: null))
        : _loadOwn(day, dayEnd);
    final peopleFuture = calendars.isEmpty
        ? Future.value((calendars: const <ColleagueCalendar>[], error: null))
        : _loadPeople(calendars, day, dayEnd);
    final own = await ownFuture;
    final people = await peopleFuture;
    if (!mounted || generation != _generation) return;

    final fetched = {
      for (final calendar in people.calendars)
        calendar.email.toLowerCase(): calendar,
    };
    final loadedEmails = {for (final calendar in calendars) calendar.email};
    final lanes = <_ScheduleLane>[];
    if (ownerEmail != null) {
      lanes.add(
        _ScheduleLane(
          email: ownerEmail,
          name: owner.ownCalendarLabel,
          subtitle: 'Организатор',
          color: CalendarPalette.colorFor(0),
          events: _eventsOnDay(own.events, day),
          error: own.error,
        ),
      );
    }
    for (var index = 0; index < widget.participants.length; index++) {
      final person = widget.participants[index];
      final email = person.email.trim().toLowerCase();
      if (email.isEmpty || email == ownerEmail) continue;
      if (loadedEmails.contains(email)) {
        final calendar = fetched[email];
        lanes.add(
          _participantLane(
            person,
            index,
            events: _eventsOnDay(calendar?.events ?? const [], day),
            error: people.error ?? calendar?.error,
          ),
        );
        continue;
      }
      final kept = _laneByEmail(email);
      if (kept != null) lanes.add(kept);
    }

    setState(() {
      _loading = false;
      _lanes = lanes;
    });
  }

  /// Добавляет и убирает строки, не перезапрашивая уже загруженные календари.
  void _syncParticipants() {
    final ownerEmail = context
        .read<CalendarBloc>()
        .state
        .ownerEmail
        ?.trim()
        .toLowerCase();
    final next = <_ScheduleLane>[];
    final ownerLane = ownerEmail == null ? null : _laneByEmail(ownerEmail);
    if (ownerLane != null) next.add(ownerLane);

    final pending = <({CalendarPerson person, int index})>[];
    for (var index = 0; index < widget.participants.length; index++) {
      final person = widget.participants[index];
      final email = person.email.trim().toLowerCase();
      if (email.isEmpty || email == ownerEmail) continue;
      final existing = _laneByEmail(email);
      if (existing != null) {
        next.add(existing);
        continue;
      }
      next.add(_participantLane(person, index));
      pending.add((person: person, index: index));
    }

    setState(() => _lanes = next);
    for (final item in pending) {
      _loadParticipant(item.person, item.index);
    }
  }

  Future<void> _loadParticipant(CalendarPerson person, int index) async {
    final generation = _generation;
    final email = person.email.trim().toLowerCase();
    final day = _dateOnly(widget.start.toLocal());
    final dayEnd = day.add(const Duration(days: 1));
    try {
      final calendar = await ewsApi.fetchColleagueCalendar(
        email: email,
        colorIndex: _participantColorIndex(index),
        start: day,
        end: dayEnd,
      );
      if (!mounted || generation != _generation) return;
      if (_laneByEmail(email) == null) return;
      _replaceLane(
        email,
        _participantLane(
          person,
          index,
          events: _eventsOnDay(calendar.events, day),
          error: calendar.error,
        ),
      );
    } catch (_) {
      if (!mounted || generation != _generation) return;
      if (_laneByEmail(email) == null) return;
      _replaceLane(
        email,
        _participantLane(person, index, error: 'Нет доступа'),
      );
    }
  }

  _ScheduleLane? _laneByEmail(String email) {
    for (final lane in _lanes) {
      if (lane.email == email) return lane;
    }
    return null;
  }

  void _replaceLane(String email, _ScheduleLane lane) {
    setState(() {
      _lanes = [
        for (final current in _lanes)
          if (current.email == email) lane else current,
      ];
    });
  }

  _ScheduleLane _participantLane(
    CalendarPerson person,
    int index, {
    List<CalendarEvent> events = const [],
    String? error,
  }) {
    return _ScheduleLane(
      email: person.email.trim().toLowerCase(),
      name: _personName(person),
      color: CalendarPalette.colorFor(_participantColorIndex(index)),
      events: events,
      error: error,
    );
  }

  int _participantColorIndex(int index) {
    return (index % (CalendarPalette.colors.length - 1)) + 1;
  }

  Future<({List<CalendarEvent> events, String? error})> _loadOwn(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final events = await ewsApi.fetchCalendarEvents(start: start, end: end);
      return (events: events, error: null);
    } catch (_) {
      return (events: const <CalendarEvent>[], error: 'Нет доступа');
    }
  }

  Future<({List<ColleagueCalendar> calendars, String? error})> _loadPeople(
    List<ColleagueCalendar> calendars,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final fetched = await ewsApi.fetchColleagueCalendars(
        calendars: calendars,
        start: start,
        end: end,
      );
      return (calendars: fetched, error: null);
    } catch (_) {
      return (calendars: const <ColleagueCalendar>[], error: 'Нет доступа');
    }
  }

  void _place(double dx, double width) {
    if (width <= 0) return;
    final window = _window(widget.start, widget.end);
    final span = window.end.difference(window.start).inSeconds;
    if (span <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    final seconds = (fraction * span).round();
    final raw = window.start.add(Duration(seconds: seconds));
    final snappedMinutes = (raw.hour * 60 + raw.minute) / 15;
    final minutes = (snappedMinutes.round() * 15).clamp(0, 24 * 60 - 15);
    final day = _dateOnly(widget.start.toLocal());
    widget.onStartChanged(day.add(Duration(minutes: minutes)));
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.start.toLocal();
    final end = widget.end.toLocal();
    final window = _window(start, end);
    final conflicts = _conflictCount(start, end);
    final failed = _lanes.any((lane) => lane.error != null);

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = constraints.maxWidth < 640 ? 176.0 : 268.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                day: start,
                start: start,
                end: end,
                loading: _loading,
                conflicts: conflicts,
                failed: failed,
                hasLanes: _lanes.isNotEmpty,
              ),
              SizedBox(height: 12.h),
              _TimeAxis(
                labelWidth: labelWidth,
                window: window,
                start: start,
                end: end,
              ),
              SizedBox(height: 6.h),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bodyConstraints) {
                    final rows = math.max(_lanes.length, 1);
                    final gridHeight = math.max(
                      bodyConstraints.maxHeight,
                      rows * _rowHeight,
                    );
                    return ScrollConfiguration(
                      behavior: const DdtScrollBehavior(),
                      child: SingleChildScrollView(
                        primary: false,
                        child: SizedBox(
                          height: gridHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: labelWidth,
                                child: _LaneLabels(
                                  lanes: _lanes,
                                  rowHeight: _rowHeight,
                                ),
                              ),
                              Expanded(
                                child: _Timeline(
                                  lanes: _lanes,
                                  window: window,
                                  meetingStart: start,
                                  meetingEnd: end,
                                  rowHeight: _rowHeight,
                                  gridHeight: gridHeight,
                                  conflicts: conflicts,
                                  onPlace: _place,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _conflictCount(DateTime start, DateTime end) {
    var count = 0;
    for (final lane in _lanes) {
      for (final event in lane.events) {
        if (_overlaps(event, start, end)) count++;
      }
    }
    return count;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.day,
    required this.start,
    required this.end,
    required this.loading,
    required this.conflicts,
    required this.failed,
    required this.hasLanes,
  });

  final DateTime day;
  final DateTime start;
  final DateTime end;
  final bool loading;
  final int conflicts;
  final bool failed;
  final bool hasLanes;

  @override
  Widget build(BuildContext context) {
    final weekday = _weekdays[day.weekday - 1];
    final date =
        '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
    final range = '${_hm(start)}–${_hm(end)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ПОМОЩЬ ПРИ ПЛАНИРОВАНИИ',
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: DdtTheme.sidePanelTextMuted(
                    context,
                  ).withValues(alpha: 0.55),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '$weekday, $date · $range',
                style: DdtTheme.style(
                  fontSize: DdtTypography.entityTitleSize,
                  fontWeight: FontWeight.w700,
                  color: DdtTheme.textPrimary(context),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'День встречи по календарям участников. Нажмите на шкалу, чтобы перенести начало.',
                style: DdtTheme.style(
                  fontSize: DdtTypography.captionSize,
                  color: DdtTheme.textMuted(context),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        _StatusPill(
          loading: loading,
          conflicts: conflicts,
          failed: failed,
          hasLanes: hasLanes,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.loading,
    required this.conflicts,
    required this.failed,
    required this.hasLanes,
  });

  final bool loading;
  final int conflicts;
  final bool failed;
  final bool hasLanes;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (loading) {
      color = DdtTheme.textMuted(context);
      label = 'Загрузка';
    } else if (!hasLanes) {
      color = DdtTheme.textMuted(context);
      label = 'Нет участников';
    } else if (failed) {
      color = DdtTheme.warningColor;
      label = 'Часть календарей скрыта';
    } else if (conflicts > 0) {
      color = DdtTheme.warningColor;
      label = conflicts == 1 ? '1 пересечение' : 'Пересечений: $conflicts';
    } else {
      color = DdtTheme.successColor;
      label = 'Все свободны';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
          ),
          SizedBox(width: 6.w),
        ],
        Text(
          label,
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSmallSize,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({
    required this.labelWidth,
    required this.window,
    required this.start,
    required this.end,
  });

  final double labelWidth;
  final _DayWindow window;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final hours = window.endHour - window.startHour;
    return SizedBox(
      height: 18.h,
      child: Row(
        children: [
          SizedBox(width: labelWidth),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hourWidth = constraints.maxWidth / hours;
                final step = hourWidth >= 46 ? 1 : 2;
                return Stack(
                  children: [
                    for (
                      var hour = window.startHour;
                      hour < window.endHour;
                      hour++
                    )
                      if ((hour - window.startHour) % step == 0)
                        Positioned(
                          left: (hour - window.startHour) * hourWidth,
                          top: 0,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: DdtTheme.style(
                              fontSize: DdtTypography.microSize,
                              fontWeight: FontWeight.w600,
                              color: _hourInside(hour)
                                  ? DdtTheme.primaryColor
                                  : DdtTheme.textMuted(context),
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _hourInside(int hour) {
    final slotStart = DateTime(start.year, start.month, start.day, hour);
    final slotEnd = slotStart.add(const Duration(hours: 1));
    return slotStart.isBefore(end) && slotEnd.isAfter(start);
  }
}

class _LaneLabels extends StatelessWidget {
  const _LaneLabels({required this.lanes, required this.rowHeight});

  final List<_ScheduleLane> lanes;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    if (lanes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final lane in lanes)
          SizedBox(
            height: rowHeight,
            child: Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: lane.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  DdtUserAvatar(size: 18.w, name: lane.name, email: lane.email),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lane.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DdtTheme.style(
                            fontSize: DdtTypography.labelSize,
                            fontWeight: FontWeight.w600,
                            color: DdtTheme.textPrimary(context),
                          ),
                        ),
                        if (lane.subtitle != null || lane.error != null)
                          Text(
                            lane.error ?? lane.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DdtTheme.style(
                              fontSize: DdtTypography.microSize,
                              color: lane.error != null
                                  ? DdtTheme.warningColor
                                  : DdtTheme.textMuted(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.lanes,
    required this.window,
    required this.meetingStart,
    required this.meetingEnd,
    required this.rowHeight,
    required this.gridHeight,
    required this.conflicts,
    required this.onPlace,
  });

  final List<_ScheduleLane> lanes;
  final _DayWindow window;
  final DateTime meetingStart;
  final DateTime meetingEnd;
  final double rowHeight;
  final double gridHeight;
  final int conflicts;
  final void Function(double dx, double width) onPlace;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final band = (conflicts > 0 ? DdtTheme.warningColor : DdtTheme.successColor)
        .withValues(alpha: isDark ? 0.22 : 0.16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bandRect = _span(meetingStart, meetingEnd, width);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => onPlace(details.localPosition.dx, width),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(width, gridHeight),
                  painter: _DayGridPainter(
                    startHour: window.startHour,
                    endHour: window.endHour,
                    lineColor: DdtTheme.borderSubtle(context),
                    band: bandRect,
                    bandColor: band,
                  ),
                ),
                for (var laneIndex = 0; laneIndex < lanes.length; laneIndex++)
                  for (final event in lanes[laneIndex].events)
                    if (_span(
                          event.start!.toLocal(),
                          (event.end ?? event.start)!.toLocal(),
                          width,
                        )
                        case final rect?)
                      Positioned(
                        key: ValueKey(
                          '${lanes[laneIndex].email}:${event.id}',
                        ),
                        left: rect.left,
                        width: math.max(rect.width, 2),
                        top: laneIndex * rowHeight + (rowHeight - 18) / 2,
                        height: 18,
                        child: _BusyBlock(
                          event: event,
                          color: lanes[laneIndex].color,
                          onTapUp: (localDx) =>
                              onPlace(rect.left + localDx, width),
                        ),
                      ),
                if (lanes.isEmpty)
                  IgnorePointer(
                    child: Center(
                      child: Text(
                        'Добавьте участников — здесь появится их день',
                        textAlign: TextAlign.center,
                        style: DdtTheme.style(
                          fontSize: DdtTypography.bodySize,
                          color: DdtTheme.textMuted(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Rect? _span(DateTime start, DateTime end, double width) {
    if (!start.isBefore(window.end) || !end.isAfter(window.start)) {
      return null;
    }
    final visibleStart = start.isBefore(window.start) ? window.start : start;
    final visibleEnd = end.isAfter(window.end) ? window.end : end;
    final span = window.end.difference(window.start).inSeconds;
    if (span <= 0 || width <= 0) return null;
    final left = visibleStart.difference(window.start).inSeconds / span * width;
    final right = visibleEnd.difference(window.start).inSeconds / span * width;
    return Rect.fromLTWH(left, 0, math.max(right - left, 2), 0);
  }
}

class _BusyBlock extends StatelessWidget {
  const _BusyBlock({
    required this.event,
    required this.color,
    required this.onTapUp,
  });

  final CalendarEvent event;
  final Color color;
  final ValueChanged<double> onTapUp;

  @override
  Widget build(BuildContext context) {
    final tentative = event.busyStatus == 'Tentative';
    final away = event.busyStatus == 'OOF' || event.busyStatus == 'Oof';
    final declined = event.isDeclined;
    final strong = !tentative && !declined;
    final fill = away ? DdtTheme.warningColor : color;
    final start = event.start?.toLocal();
    final end = event.end?.toLocal();
    final when = start == null
        ? event.subject
        : '${_hm(start)}–${end == null ? '…' : _hm(end)} · ${event.subject}';

    final radius = BorderRadius.circular(6);
    final edge = (away ? DdtTheme.warningColor : color).withValues(
      alpha: strong ? 0.72 : 0.45,
    );
    final glass = fill.withValues(alpha: strong ? 0.46 : 0.24);

    return Tooltip(
      message: when,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => onTapUp(details.localPosition.dx),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: glass,
                borderRadius: radius,
                border: Border.all(color: edge),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayGridPainter extends CustomPainter {
  const _DayGridPainter({
    required this.startHour,
    required this.endHour,
    required this.lineColor,
    required this.band,
    required this.bandColor,
  });

  final int startHour;
  final int endHour;
  final Color lineColor;
  final Rect? band;
  final Color bandColor;

  @override
  void paint(Canvas canvas, Size size) {
    final hours = endHour - startHour;
    if (hours > 0) {
      final hourWidth = size.width / hours;
      final grid = Paint()
        ..color = lineColor
        ..strokeWidth = 1;
      for (var index = 0; index <= hours; index++) {
        final x = index * hourWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
    }

    if (band != null && band!.width > 0) {
      canvas.drawRect(
        Rect.fromLTWH(band!.left, 0, band!.width, size.height),
        Paint()..color = bandColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DayGridPainter oldDelegate) {
    return oldDelegate.startHour != startHour ||
        oldDelegate.endHour != endHour ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.band != band ||
        oldDelegate.bandColor != bandColor;
  }
}

class _ScheduleLane {
  const _ScheduleLane({
    required this.email,
    required this.name,
    required this.color,
    required this.events,
    this.subtitle,
    this.error,
  });

  final String email;
  final String name;
  final String? subtitle;
  final Color color;
  final String? error;
  final List<CalendarEvent> events;
}

class _DayWindow {
  const _DayWindow({
    required this.startHour,
    required this.endHour,
    required this.start,
    required this.end,
  });

  final int startHour;
  final int endHour;
  final DateTime start;
  final DateTime end;
}

_DayWindow _window(DateTime start, DateTime end) {
  final day = _dateOnly(start.toLocal());
  var startHour = 8;
  var endHour = 20;

  void include(DateTime value) {
    final local = value.toLocal();
    if (local.isBefore(day)) {
      startHour = 0;
      return;
    }
    if (!local.isBefore(day.add(const Duration(days: 1)))) {
      endHour = 24;
      return;
    }
    startHour = math.min(startHour, local.hour);
    final edge = local.minute == 0 && local.second == 0
        ? local.hour
        : local.hour + 1;
    endHour = math.max(endHour, math.min(24, edge));
  }

  include(start);
  include(end);
  if (endHour <= startHour) endHour = math.min(24, startHour + 1);

  return _DayWindow(
    startHour: startHour,
    endHour: endHour,
    start: day.add(Duration(hours: startHour)),
    end: day.add(Duration(hours: endHour)),
  );
}

List<CalendarEvent> _eventsOnDay(List<CalendarEvent> events, DateTime day) {
  final dayEnd = day.add(const Duration(days: 1));
  return [
    for (final event in events)
      if (event.start != null &&
          event.start!.toLocal().isBefore(dayEnd) &&
          (event.end ?? event.start)!.toLocal().isAfter(day))
        event,
  ];
}

bool _overlaps(CalendarEvent event, DateTime start, DateTime end) {
  final eventStart = event.start?.toLocal();
  final eventEnd = (event.end ?? event.start)?.toLocal();
  if (eventStart == null || eventEnd == null) return false;
  return eventStart.isBefore(end) && eventEnd.isAfter(start);
}

bool _sameDay(DateTime a, DateTime b) {
  final left = a.toLocal();
  final right = b.toLocal();
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _samePeople(List<CalendarPerson> left, List<CalendarPerson> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].email.toLowerCase() != right[index].email.toLowerCase()) {
      return false;
    }
  }
  return true;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _personName(CalendarPerson person) {
  final name = person.displayName.trim();
  return name.isEmpty ? person.email : name;
}

String _hm(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
