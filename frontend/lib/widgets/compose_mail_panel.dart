import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/mail_controller.dart';
import '../theme/ddt_theme.dart';
import 'ddt_side_panel.dart';

Future<bool?> showComposeMailPanel(BuildContext context) {
  return showDdtSidePanel<bool>(
    context,
    child: const ComposeMailPanel(),
  );
}

class ComposeMailPanel extends StatefulWidget {
  const ComposeMailPanel({super.key});

  @override
  State<ComposeMailPanel> createState() => _ComposeMailPanelState();
}

class _ComposeMailPanelState extends State<ComposeMailPanel> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _ccController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<String> _parseEmails(String raw) {
    return raw
        .split(RegExp(r'[;,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = Get.find<MailController>();
    final success = await controller.sendMessage(
      to: _parseEmails(_toController.text),
      cc: _parseEmails(_ccController.text),
      subject: _subjectController.text.trim(),
      body: _bodyController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Письмо отправлено')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MailController>();

    return DdtSidePanelShell(
      title: 'Новое письмо',
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
                text: controller.isSending.value ? 'Отправка...' : 'Отправить',
                borderRadius: DdtTheme.radius,
                onPressed: controller.isSending.value ? null : _submit,
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
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'Кому',
                hintText: 'email1@example.com, email2@example.com',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final emails = _parseEmails(value ?? '');
                if (emails.isEmpty) {
                  return 'Укажите хотя бы одного получателя';
                }
                return null;
              },
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _ccController,
              decoration: const InputDecoration(
                labelText: 'Копия',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Тема',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Укажите тему' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Сообщение',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 8,
              maxLines: 16,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Введите текст письма'
                  : null,
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
