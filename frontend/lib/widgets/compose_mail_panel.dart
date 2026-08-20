import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/mail/mail_bloc.dart';
import '../theme/ddt_theme.dart';
import 'ddt_side_panel.dart';

Future<bool?> showComposeMailPanel(BuildContext context) {
  return showDdtSidePanel<bool>(context, child: const ComposeMailPanel());
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

    context.read<MailBloc>().add(
      MailMessageSendRequested(
        to: _parseEmails(_toController.text),
        cc: _parseEmails(_ccController.text),
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Письмо отправляется...')));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailBloc, MailState>(
      buildWhen: (previous, current) =>
          previous.isSending != current.isSending ||
          previous.errorMessage != current.errorMessage,
      builder: (context, state) => DdtSidePanelShell(
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
              child: Button(
                text: state.isSending ? 'Отправка...' : 'Отправить',
                borderRadius: DdtTheme.radius,
                onPressed: state.isSending ? null : _submit,
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
                decoration: DdtTheme.inputDecoration(
                  labelText: 'Кому',
                  hintText: 'email1@example.com, email2@example.com',
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
                decoration: DdtTheme.inputDecoration(labelText: 'Копия'),
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _subjectController,
                decoration: DdtTheme.inputDecoration(labelText: 'Тема'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Укажите тему'
                    : null,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _bodyController,
                decoration: DdtTheme.inputDecoration(
                  labelText: 'Сообщение',
                  alignLabelWithHint: true,
                ),
                minLines: 8,
                maxLines: 16,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите текст письма'
                    : null,
              ),
              if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
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
