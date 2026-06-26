import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/calendar_controller.dart';
import '../theme/ddt_theme.dart';
import 'ddt_side_panel.dart';

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
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }

    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
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

    final controller = Get.find<CalendarController>();
    final success = await controller.createEvent(
      subject: _subjectController.text.trim(),
      start: _start,
      end: _end,
      location: _locationController.text.trim(),
      body: _bodyController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Событие создано')),
      );
    }
  }

  Widget _dateTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    final format = DateFormat('dd.MM.yyyy HH:mm');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: DdtTheme.style(fontSize: 13.sp)),
      subtitle: Text(format.format(value)),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CalendarController>();

    return DdtSidePanelShell(
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
            child: Obx(
              () => Button(
                text: controller.isCreating.value ? 'Создание...' : 'Создать',
                borderRadius: DdtTheme.radius,
                onPressed: controller.isCreating.value ? null : _submit,
              ),
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
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                labelText: 'Место',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 4,
              maxLines: 10,
            ),
            Obx(() {
              final error = controller.errorMessage.value;
              if (error == null || error.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Text(
                  error,
                  style: DdtTheme.style(
                    fontSize: 13.sp,
                    color: Colors.redAccent,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
