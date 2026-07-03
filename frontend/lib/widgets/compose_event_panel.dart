import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_date_time_picker.dart';
import 'ddt_side_panel.dart';
import 'ddt_tappable.dart';

Future<bool?> showComposeEventPanel(BuildContext context) {
  return showDdtSidePanel<bool>(
    context,
    child: const ComposeEventPanel(),
  );
}

class ComposeEventPanel extends StatefulWidget {
  const ComposeEventPanel({super.key});

  @override
  State<ComposeEventPanel> createState() => _ComposeEventPanelState();
}

class _ComposeEventPanelState extends State<ComposeEventPanel> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _locationController = TextEditingController();
  final _bodyController = TextEditingController();

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
    _locationController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({
    required bool isStart,
  }) async {
    final initial = isStart ? _start : _end;
    final value = await showDdtDateTimePicker(
      context: context,
      initialDateTime: initial,
    );
    if (value == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _start = value;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = value;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Время окончания должно быть позже начала')),
      );
      return;
    }

    context.read<CalendarBloc>().add(CalendarEventCreateRequested(
          subject: _subjectController.text.trim(),
          start: _start,
          end: _end,
          location: _locationController.text.trim(),
          body: _bodyController.text.trim(),
        ));

    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Событие создаётся...')),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    final format = DateFormat('dd.MM.yyyy HH:mm');

    return DdtTappable(
      onTap: onTap,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DdtTheme.style(fontSize: 13.sp)),
                Text(format.format(value)),
              ],
            ),
          ),
          const Icon(Icons.calendar_today_outlined),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) =>
          previous.isCreating != current.isCreating,
      builder: (context, state) => DdtSidePanelShell(
        title: 'Новое событие',
        footer: Row(
          children: [
            Expanded(
              child: Button(
                text: 'Отмена',
                type: ButtonType.outlined,
                borderRadius: DdtTheme.radius,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Button(
                text: state.isCreating ? 'Создание...' : 'Создать',
                borderRadius: DdtTheme.radius,
                onPressed: state.isCreating ? null : _submit,
              ),
            ),
          ],
        ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(DdtTheme.spacing.w),
          children: [
            TextFormField(
              controller: _subjectController,
              decoration: DdtTheme.inputDecoration(labelText: 'Название'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Укажите название события'
                  : null,
            ),
            SizedBox(height: 12.h),
            _dateTile(
              label: 'Начало',
              value: _start,
              onTap: () => _pickDateTime(isStart: true),
            ),
            _dateTile(
              label: 'Окончание',
              value: _end,
              onTap: () => _pickDateTime(isStart: false),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _locationController,
              decoration: DdtTheme.inputDecoration(labelText: 'Место'),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _bodyController,
              decoration: DdtTheme.inputDecoration(
                labelText: 'Описание',
                alignLabelWithHint: true,
              ),
              minLines: 4,
              maxLines: 10,
            ),
            if (state.errorMessage != null &&
                state.errorMessage!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Text(
                  state.errorMessage!,
                  style: DdtTheme.style(
                    fontSize: 13.sp,
                    color: Colors.redAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}
