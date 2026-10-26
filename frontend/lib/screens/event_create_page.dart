import 'dart:async';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../models/colleague_calendar.dart';
import '../router/route_paths.dart';
import '../services/ews_api.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_scroll_behavior.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/ddt_date_time_picker.dart';
import '../utils/ddt_toast.dart';
import '../utils/task_formatters.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_user_avatar.dart';
import '../widgets/ddt_user_chip.dart';
import '../widgets/event_schedule_assistant.dart';

/// Полноэкранное создание события вместо боковой панели.
void openEventCreatePage(BuildContext context) {
  context.push(RoutePaths.calendarNew);
}

class EventCreatePage extends StatefulWidget {
  const EventCreatePage({super.key});

  @override
  State<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends State<EventCreatePage> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _locationController = TextEditingController();
  final _peopleController = TextEditingController();
  final _bodyFocus = FocusNode();

  late DateTime _start;
  late DateTime _end;
  final List<CalendarPerson> _participants = [];
  List<CalendarPerson> _peopleResults = const [];
  bool _searchingPeople = false;
  Timer? _searchDebounce;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day, now.hour + 1);
    _end = _start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _subjectController.dispose();
    _bodyController.dispose();
    _locationController.dispose();
    _peopleController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.calendar);
  }

  Future<void> _pick({required bool isStart}) async {
    final picked = await showDdtDateTimePicker(
      context: context,
      initialDateTime: isStart ? _start : _end,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = picked;
      }
    });
  }

  void _moveStart(DateTime start) {
    final duration = _end.difference(_start);
    final length = duration > Duration.zero
        ? duration
        : const Duration(hours: 1);
    setState(() {
      _start = start;
      _end = start.add(length);
    });
  }

  void _onPeopleQueryChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _searchPeople(value);
    });
  }

  Future<void> _searchPeople(String value) async {
    final query = value.trim();
    final generation = ++_searchGeneration;
    if (query.isEmpty) {
      setState(() {
        _searchingPeople = false;
        _peopleResults = const [];
      });
      return;
    }
    setState(() => _searchingPeople = true);
    try {
      final results = await ewsApi.searchCalendarPeople(query);
      if (!mounted || generation != _searchGeneration) return;
      final taken = {
        for (final person in _participants) person.email.toLowerCase(),
      };
      setState(() {
        _searchingPeople = false;
        _peopleResults = [
          for (final person in results)
            if (!taken.contains(person.email.toLowerCase())) person,
        ];
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchingPeople = false;
        _peopleResults = const [];
      });
    }
  }

  void _submitPeopleQuery(String value) {
    _searchDebounce?.cancel();
    final needle = value.trim();
    if (needle.contains('@')) {
      _addParticipant(
        CalendarPerson(email: needle.toLowerCase(), displayName: needle),
      );
      return;
    }
    _searchPeople(needle);
  }

  void _addParticipant(CalendarPerson person) {
    final email = person.email.trim().toLowerCase();
    if (email.isEmpty) return;
    final owner = context.read<CalendarBloc>().state.ownerEmail?.toLowerCase();
    if (owner != null && email == owner) {
      DdtToast.show(
        message: 'Вы уже организатор этой встречи',
        type: ToastType.info,
      );
      return;
    }
    if (_participants.any((item) => item.email.toLowerCase() == email)) {
      return;
    }
    _searchDebounce?.cancel();
    setState(() {
      _participants.add(
        CalendarPerson(
          email: email,
          displayName: person.displayName.trim().isEmpty
              ? email
              : person.displayName.trim(),
        ),
      );
      _peopleResults = const [];
      _searchingPeople = false;
    });
    _searchGeneration++;
    _peopleController.clear();
  }

  void _removeParticipant(String email) {
    setState(() {
      _participants.removeWhere(
        (person) => person.email.toLowerCase() == email.toLowerCase(),
      );
    });
  }

  void _submit() {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      DdtToast.show(
        message: 'Введите название события',
        type: ToastType.warning,
      );
      return;
    }
    if (!_end.isAfter(_start)) {
      DdtToast.show(
        message: 'Время окончания должно быть позже начала',
        type: ToastType.warning,
      );
      return;
    }

    context.read<CalendarBloc>().add(
      CalendarEventCreateRequested(
        subject: subject,
        start: _start,
        end: _end,
        location: _locationController.text.trim(),
        body: _bodyController.text.trim(),
        attendees: List<CalendarPerson>.from(_participants),
      ),
    );
    DdtToast.show(message: 'Событие создаётся...', type: ToastType.info);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final form = _EventForm(
      subjectController: _subjectController,
      bodyController: _bodyController,
      locationController: _locationController,
      peopleController: _peopleController,
      bodyFocus: _bodyFocus,
      start: _start,
      end: _end,
      participants: _participants,
      peopleResults: _peopleResults,
      searchingPeople: _searchingPeople,
      onPickStart: () => _pick(isStart: true),
      onPickEnd: () => _pick(isStart: false),
      onPeopleQueryChanged: _onPeopleQueryChanged,
      onPeopleQuerySubmitted: _submitPeopleQuery,
      onAddParticipant: _addParticipant,
      onRemoveParticipant: _removeParticipant,
      onSubjectSubmitted: () => _bodyFocus.requestFocus(),
    );
    final assistant = EventScheduleAssistant(
      start: _start,
      end: _end,
      participants: List<CalendarPerson>.of(_participants),
      onStartChanged: _moveStart,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = _shellPadding(context);
        final wide = constraints.maxWidth >= 980;
        if (!wide) {
          return _EventScroll(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventToolbar(onClose: _close, onSubmit: _submit),
                SizedBox(height: 20.h),
                form,
                SizedBox(height: 28.h),
                SizedBox(height: 560, child: assistant),
              ],
            ),
          );
        }

        final formWidth = (constraints.maxWidth * 0.30).clamp(320.0, 400.0);
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EventToolbar(onClose: _close, onSubmit: _submit),
              SizedBox(height: 12.h),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: formWidth,
                      child: _EventScroll(child: form),
                    ),
                    Container(
                      width: 1,
                      color: DdtTheme.borderSubtle(context),
                    ),
                    SizedBox(width: 20.w),
                    Expanded(child: assistant),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  EdgeInsets _shellPadding(BuildContext context) {
    final top = DdtShellMetrics.maybeOf(context)?.contentInsetTop ?? 0;
    final bottom = DdtShellMetrics.maybeOf(context)?.contentInsetBottom ?? 24.h;
    final right = DdtShellMetrics.maybeOf(context)?.contentInsetRight ?? 0;
    return EdgeInsets.fromLTRB(20.w, top + 2.h, 20.w + right, bottom);
  }
}

class _EventForm extends StatelessWidget {
  const _EventForm({
    required this.subjectController,
    required this.bodyController,
    required this.locationController,
    required this.peopleController,
    required this.bodyFocus,
    required this.start,
    required this.end,
    required this.participants,
    required this.peopleResults,
    required this.searchingPeople,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPeopleQueryChanged,
    required this.onPeopleQuerySubmitted,
    required this.onAddParticipant,
    required this.onRemoveParticipant,
    required this.onSubjectSubmitted,
  });

  final TextEditingController subjectController;
  final TextEditingController bodyController;
  final TextEditingController locationController;
  final TextEditingController peopleController;
  final FocusNode bodyFocus;
  final DateTime start;
  final DateTime end;
  final List<CalendarPerson> participants;
  final List<CalendarPerson> peopleResults;
  final bool searchingPeople;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String> onPeopleQueryChanged;
  final ValueChanged<String> onPeopleQuerySubmitted;
  final ValueChanged<CalendarPerson> onAddParticipant;
  final ValueChanged<String> onRemoveParticipant;
  final VoidCallback onSubjectSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EventTextField(
          controller: subjectController,
          hint: 'Название',
          autofocus: true,
          style: DdtTheme.style(
            fontSize: DdtTypography.entityTitleSize,
            fontWeight: FontWeight.w700,
            color: DdtTheme.textPrimary(context),
          ),
          onSubmitted: (_) => onSubjectSubmitted(),
        ),
        SizedBox(height: 16.h),
        _EventTextField(
          controller: bodyController,
          focusNode: bodyFocus,
          hint: 'Описание',
          minLines: 4,
          maxLines: 8,
          style: DdtTheme.style(
            fontSize: DdtTypography.bodySize,
            height: 1.55,
            color: DdtTheme.textPrimary(context),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Divider(height: 1, color: DdtTheme.borderSubtle(context)),
        ),
        _EventDateRow(label: 'Начало', value: start, onTap: onPickStart),
        _EventDateRow(label: 'Окончание', value: end, onTap: onPickEnd),
        _EventFieldRow(
          label: 'Место',
          child: DdtAppInput(
            hint: 'Не указано',
            controller: locationController,
            variant: DdtInputVariant.compact,
          ),
        ),
        _EventFieldRow(
          label: 'Участники',
          alignTop: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PeopleSearchField(
                controller: peopleController,
                searching: searchingPeople,
                results: peopleResults,
                onChanged: onPeopleQueryChanged,
                onSubmitted: onPeopleQuerySubmitted,
                onAdd: onAddParticipant,
              ),
              if (participants.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    for (final person in participants)
                      _ParticipantChip(
                        person: person,
                        onRemove: () => onRemoveParticipant(person.email),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PeopleSearchField extends StatefulWidget {
  const _PeopleSearchField({
    required this.controller,
    required this.searching,
    required this.results,
    required this.onChanged,
    required this.onSubmitted,
    required this.onAdd,
  });

  final TextEditingController controller;
  final bool searching;
  final List<CalendarPerson> results;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<CalendarPerson> onAdd;

  @override
  State<_PeopleSearchField> createState() => _PeopleSearchFieldState();
}

class _PeopleSearchFieldState extends State<_PeopleSearchField> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _fieldKey = GlobalKey();

  bool get _open => widget.searching || widget.results.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scheduleMenu();
  }

  @override
  void didUpdateWidget(covariant _PeopleSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMenu();
  }

  void _scheduleMenu() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_open && !_portal.isShowing) _portal.show();
      if (!_open && _portal.isShowing) _portal.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final width = box != null && box.hasSize ? box.size.width : 280.0;
        return CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: Offset(0, 6.h),
          child: UnconstrainedBox(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: _PeopleMenu(
                searching: widget.searching,
                results: widget.results,
                onAdd: widget.onAdd,
              ),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: KeyedSubtree(
          key: _fieldKey,
          child: DdtAppInput(
            hint: 'Найти коллегу',
            controller: widget.controller,
            variant: DdtInputVariant.compact,
            prefixIcon: DdtIcons.search,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ),
      ),
    );
  }
}

class _PeopleMenu extends StatelessWidget {
  const _PeopleMenu({
    required this.searching,
    required this.results,
    required this.onAdd,
  });

  final bool searching;
  final List<CalendarPerson> results;
  final ValueChanged<CalendarPerson> onAdd;

  @override
  Widget build(BuildContext context) {
    return DdtTheme.contextMenuGlass(
      context: context,
      padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 6.h),
      child: searching
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 260.h),
              child: ListView(
                shrinkWrap: true,
                primary: false,
                padding: EdgeInsets.zero,
                children: [
                  for (final person in results)
                    _PersonResultRow(
                      name: person.displayName,
                      email: person.email,
                      onTap: () => onAdd(person),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  const _ParticipantChip({required this.person, required this.onRemove});

  final CalendarPerson person;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final closeSlot = 22.w;
        final chipMax = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - closeSlot).clamp(0.0, constraints.maxWidth)
            : double.infinity;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: chipMax),
              child: DdtUserChip(
                name: person.displayName,
                email: person.email,
                avatarSize: 22,
                fontSize: DdtTypography.labelSize,
              ),
            ),
            Tooltip(
              message: 'Убрать',
              child: Semantics(
                button: true,
                label: 'Убрать ${person.displayName}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4.w, 4.h, 2.w, 4.h),
                    child: DdtIcon(
                      DdtIcons.close,
                      size: 11.sp,
                      color: DdtTheme.textMuted(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PersonResultRow extends StatefulWidget {
  const _PersonResultRow({
    required this.name,
    required this.email,
    required this.onTap,
  });

  final String name;
  final String email;
  final VoidCallback onTap;

  @override
  State<_PersonResultRow> createState() => _PersonResultRowState();
}

class _PersonResultRowState extends State<_PersonResultRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    final background = isDark
        ? Colors.white.withValues(alpha: _hovered ? 0.06 : 0)
        : DdtTheme.primaryColor.withValues(alpha: _hovered ? 0.08 : 0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Row(
              children: [
                DdtUserAvatar(
                  size: 18.w,
                  name: widget.name,
                  email: widget.email,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DdtTheme.style(
                          fontSize: DdtTypography.labelSize,
                          fontWeight: FontWeight.w500,
                          color: DdtTheme.textPrimary(context),
                        ),
                      ),
                      Text(
                        widget.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DdtTheme.style(
                          fontSize: DdtTypography.microSize,
                          color: DdtTheme.textMuted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                DdtIcon(DdtIcons.add, size: 11.sp, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventToolbar extends StatelessWidget {
  const _EventToolbar({required this.onClose, required this.onSubmit});

  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Назад к календарю',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Transform.translate(
                offset: Offset(
                  -(14 / DdtIcon.visualScale) * (1 - DdtIcon.visualScale) / 2,
                  0,
                ),
                child: DdtIcon(
                  DdtIcons.chevronLeft,
                  size: 14 / DdtIcon.visualScale,
                  color: DdtTheme.sidePanelTextSecondary(context),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'НОВОЕ СОБЫТИЕ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              height: 1,
              fontWeight: FontWeight.w500,
              color: DdtTheme.sidePanelTextMuted(
                context,
              ).withValues(alpha: 0.55),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Button(
          text: 'Создать',
          onPressed: onSubmit,
          borderRadius: DdtTheme.radius,
        ),
      ],
    );
  }
}

class _EventTextField extends StatelessWidget {
  const _EventTextField({
    required this.controller,
    required this.hint,
    required this.style,
    this.focusNode,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextStyle style;
  final FocusNode? focusNode;
  final bool autofocus;
  final int minLines;
  final int? maxLines;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        inputDecorationTheme: const InputDecorationTheme(
          filled: false,
          isCollapsed: true,
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines ?? (minLines == 1 ? 4 : null),
        textCapitalization: TextCapitalization.sentences,
        textInputAction: minLines == 1
            ? TextInputAction.next
            : TextInputAction.newline,
        style: style,
        cursorColor: accent,
        cursorWidth: 1.4,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          isCollapsed: true,
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          hintText: hint,
          hintStyle: style.copyWith(color: DdtTheme.textMuted(context)),
        ),
      ),
    );
  }
}

class _EventScroll extends StatelessWidget {
  const _EventScroll({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const DdtScrollBehavior(),
      child: ListView(
        primary: false,
        padding: padding ?? EdgeInsets.zero,
        children: [child],
      ),
    );
  }
}

class _EventFieldRow extends StatelessWidget {
  const _EventFieldRow({
    required this.label,
    required this.child,
    this.alignTop = false,
  });

  final String label;
  final Widget child;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: alignTop ? 8.h : 0),
            child: SizedBox(
              width: 108.w,
              child: Text(
                label,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  fontWeight: FontWeight.w600,
                  color: DdtTheme.sidePanelTextMuted(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EventDateRow extends StatelessWidget {
  const _EventDateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _EventFieldRow(
      label: label,
      child: DdtFilterDropdownAnchor(
        label: formatTaskDateTime(value.toLocal()),
        active: true,
        onTap: onTap,
      ),
    );
  }
}
