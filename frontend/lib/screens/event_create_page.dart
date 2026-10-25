import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../router/route_paths.dart';
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
import '../widgets/ddt_side_panel_divider.dart';

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
  final _bodyFocus = FocusNode();

  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day, now.hour + 1);
    _end = _start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _locationController.dispose();
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
      ),
    );
    DdtToast.show(message: 'Событие создаётся...', type: ToastType.info);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EventToolbar(onClose: _close, onSubmit: _submit),
        SizedBox(height: 12.h),
        _EventTextField(
          controller: _subjectController,
          hint: 'Название',
          autofocus: true,
          style: DdtTheme.style(
            fontSize: DdtTypography.entityTitleSize,
            fontWeight: FontWeight.w700,
            color: DdtTheme.textPrimary(context),
          ),
          onSubmitted: (_) => _bodyFocus.requestFocus(),
        ),
        SizedBox(height: 20.h),
        _EventTextField(
          controller: _bodyController,
          focusNode: _bodyFocus,
          hint: 'Описание',
          minLines: 8,
          style: DdtTheme.style(
            fontSize: DdtTypography.bodySize,
            height: 1.55,
            color: DdtTheme.textPrimary(context),
          ),
        ),
      ],
    );

    final parameters = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Параметры',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
        SizedBox(height: 12.h),
        _EventDateRow(
          label: 'Начало',
          value: _start,
          onTap: () => _pick(isStart: true),
        ),
        _EventDateRow(
          label: 'Окончание',
          value: _end,
          onTap: () => _pick(isStart: false),
        ),
        _EventFieldRow(
          label: 'Место',
          child: DdtAppInput(
            hint: 'Не указано',
            controller: _locationController,
            variant: DdtInputVariant.compact,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        if (!wide) {
          return _EventScroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                main,
                SizedBox(height: 24.h),
                parameters,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _EventScroll(child: main)),
            const DdtSidePanelDivider(),
            SizedBox(width: 320.w, child: _EventScroll(child: parameters)),
          ],
        );
      },
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
              child: Padding(
                padding: EdgeInsets.all(4.w),
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
              color: DdtTheme.sidePanelTextMuted(context).withValues(alpha: 0.55),
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
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextStyle style;
  final FocusNode? focusNode;
  final bool autofocus;
  final int minLines;
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
        maxLines: minLines == 1 ? 4 : null,
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
  const _EventScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = DdtShellMetrics.maybeOf(context)?.contentInsetTop ?? 0;
    final bottom = DdtShellMetrics.maybeOf(context)?.contentInsetBottom ?? 24.h;

    return ScrollConfiguration(
      behavior: const DdtScrollBehavior(),
      child: ListView(
        primary: false,
        padding: EdgeInsets.fromLTRB(20.w, top + 16.h, 20.w, bottom),
        children: [child],
      ),
    );
  }
}

class _EventFieldRow extends StatelessWidget {
  const _EventFieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          SizedBox(
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
