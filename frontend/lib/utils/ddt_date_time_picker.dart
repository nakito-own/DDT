import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/ddt_theme.dart';

/// Локаль для Material date/time picker: русский язык, понедельник — первый день недели.
const ddtPickerLocale = Locale('ru', 'RU');

Future<DateTime?> showDdtDateTimePicker({
  required BuildContext context,
  required DateTime initialDateTime,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final first = firstDate ?? DateTime(2020);
  final last = lastDate ?? DateTime(2100);
  var initial = initialDateTime;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return MediaQuery(
        data: MediaQuery.of(
          dialogContext,
        ).copyWith(alwaysUse24HourFormat: true),
        child: _DdtDateTimePickerDialog(
          initialDateTime: initial,
          firstDate: first,
          lastDate: last,
        ),
      );
    },
  );
}

Future<DateTime?> showDdtDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDatePicker(
    context: context,
    locale: ddtPickerLocale,
    initialDate: initialDate,
    firstDate: firstDate ?? DateTime(2020),
    lastDate: lastDate ?? DateTime(2100),
  );
}

Future<TimeOfDay?> showDdtTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    initialEntryMode: TimePickerEntryMode.inputOnly,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

class _DdtDateTimePickerDialog extends StatefulWidget {
  const _DdtDateTimePickerDialog({
    required this.initialDateTime,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDateTime;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DdtDateTimePickerDialog> createState() =>
      _DdtDateTimePickerDialogState();
}

class _DdtDateTimePickerDialogState extends State<_DdtDateTimePickerDialog> {
  late DateTime _selectedDate;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDateTime.year,
      widget.initialDateTime.month,
      widget.initialDateTime.day,
    );
    _hourController = TextEditingController(
      text: _twoDigits(widget.initialDateTime.hour),
    );
    _minuteController = TextEditingController(
      text: _twoDigits(widget.initialDateTime.minute),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  bool _parseTime({required bool showError}) {
    final hour = int.tryParse(_hourController.text.trim());
    final minute = int.tryParse(_minuteController.text.trim());

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      if (showError) {
        setState(() => _timeError = 'Введите время в формате ЧЧ:ММ');
      }
      return false;
    }

    _hourController.text = _twoDigits(hour);
    _minuteController.text = _twoDigits(minute);
    if (showError) {
      setState(() => _timeError = null);
    }
    return true;
  }

  void _confirm() {
    if (!_parseTime(showError: true)) return;

    final hour = int.parse(_hourController.text);
    final minute = int.parse(_minuteController.text);

    Navigator.of(context).pop(
      DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.textPrimary(context);
    final textMuted = DdtTheme.textMuted(context);

    return Dialog(
      backgroundColor: DdtTheme.pickerSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: DdtTheme.radius),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 360.w),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Выберите дату и время',
                style: DdtTheme.style(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    surface: DdtTheme.pickerSurfaceColor(context),
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  currentDate: DateTime.now(),
                  onDateChanged: (date) => setState(() => _selectedDate = date),
                ),
              ),
              Divider(color: DdtTheme.sidePanelDivider(context)),
              SizedBox(height: 8.h),
              Text(
                'Время',
                style: DdtTheme.style(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      controller: _hourController,
                      fillColor: DdtTheme.pickerInputFillColor(context),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      ':',
                      style: DdtTheme.style(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TimeField(
                      controller: _minuteController,
                      fillColor: DdtTheme.pickerInputFillColor(context),
                    ),
                  ),
                ],
              ),
              if (_timeError != null) ...[
                SizedBox(height: 8.h),
                Text(
                  _timeError!,
                  style: DdtTheme.style(
                    fontSize: 12.sp,
                    color: AppColors.error,
                  ),
                ),
              ],
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  TextButton(onPressed: _confirm, child: const Text('ОК')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.controller, required this.fillColor});

  final TextEditingController controller;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: DdtTheme.inputDecoration(
        hintText: '00',
      ).copyWith(fillColor: fillColor),
    );
  }
}
