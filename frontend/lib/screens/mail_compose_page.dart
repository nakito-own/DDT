import 'dart:async';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/mail/mail_bloc.dart';
import '../models/colleague_calendar.dart';
import '../models/mail_message.dart';
import '../router/route_paths.dart';
import '../services/ews_api.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_scroll_behavior.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/ddt_toast.dart';
import '../utils/mail_compose.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_markdown_body.dart';
import '../widgets/ddt_markdown_description_input.dart';
import '../widgets/ddt_markdown_live_controller.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_side_panel_divider.dart';
import '../widgets/ddt_user_avatar.dart';
import '../widgets/ddt_user_chip.dart';

const _maxAttachmentBytes = 25 * 1024 * 1024;

/// Полноэкранное написание письма вместо боковой панели.
void openMailComposePage(BuildContext context, {MailComposeDraft? draft}) {
  context.push(RoutePaths.mailNew, extra: draft);
}

class MailComposePage extends StatefulWidget {
  const MailComposePage({super.key, this.draft});

  final MailComposeDraft? draft;

  @override
  State<MailComposePage> createState() => _MailComposePageState();
}

class _MailComposePageState extends State<MailComposePage> {
  final _subjectController = TextEditingController();
  final _bodyController = DdtMarkdownLiveController();
  final _bodyFocus = FocusNode();
  final List<CalendarPerson> _to = [];
  final List<CalendarPerson> _cc = [];
  final List<MailOutgoingAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft == null) return;
    _subjectController.text = draft.subject;
    if (draft.body.isNotEmpty) {
      _bodyController.value = TextEditingValue(
        text: draft.body,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    _to.addAll(draft.to);
    if (draft.body.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bodyFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RoutePaths.mail);
  }

  Set<String> get _takenEmails => {
    for (final person in [..._to, ..._cc]) person.email.toLowerCase(),
  };

  void _addRecipient(List<CalendarPerson> target, CalendarPerson person) {
    final email = person.email.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      DdtToast.show(message: 'Укажите адрес почты', type: ToastType.warning);
      return;
    }
    if (_takenEmails.contains(email)) {
      DdtToast.show(message: 'Этот адрес уже указан', type: ToastType.info);
      return;
    }
    setState(() {
      target.add(
        CalendarPerson(
          email: email,
          displayName: person.displayName.trim().isEmpty
              ? email
              : person.displayName.trim(),
        ),
      );
    });
  }

  void _removeRecipient(List<CalendarPerson> target, String email) {
    setState(() {
      target.removeWhere(
        (person) => person.email.toLowerCase() == email.toLowerCase(),
      );
    });
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;
    final next = <MailOutgoingAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        DdtToast.show(
          message: 'Не удалось прочитать ${file.name}',
          type: ToastType.warning,
        );
        continue;
      }
      if (bytes.length > _maxAttachmentBytes) {
        DdtToast.show(
          message: '${file.name} больше 25 МБ',
          type: ToastType.warning,
        );
        continue;
      }
      next.add(
        MailOutgoingAttachment(
          name: file.name,
          bytes: bytes,
          contentType: _contentType(file.name),
        ),
      );
    }
    if (next.isEmpty || !mounted) return;
    setState(() => _attachments.addAll(next));
  }

  void _submit() {
    final subject = _subjectController.text.trim();
    final markdown = _bodyController.text.trim();
    if (_to.isEmpty) {
      DdtToast.show(
        message: 'Укажите хотя бы одного получателя',
        type: ToastType.warning,
      );
      return;
    }
    if (subject.isEmpty) {
      DdtToast.show(message: 'Укажите тему', type: ToastType.warning);
      return;
    }
    if (markdown.isEmpty) {
      DdtToast.show(message: 'Введите текст письма', type: ToastType.warning);
      return;
    }

    context.read<MailBloc>().add(
      MailMessageSendRequested(
        to: [for (final person in _to) person.email],
        cc: [for (final person in _cc) person.email],
        subject: subject,
        body: DdtMarkdownBody.markdownToHtml(markdown),
        bodyType: 'HTML',
        attachments: List<MailOutgoingAttachment>.of(_attachments),
      ),
    );
    DdtToast.show(message: 'Письмо отправляется...', type: ToastType.info);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.draft != null && widget.draft!.body.isNotEmpty;
    final parameters = _ComposeParameters(
      to: _to,
      cc: _cc,
      taken: _takenEmails,
      attachments: _attachments,
      recipientHint: widget.draft?.recipientHint,
      onAddTo: (person) => _addRecipient(_to, person),
      onAddCc: (person) => _addRecipient(_cc, person),
      onRemoveTo: (email) => _removeRecipient(_to, email),
      onRemoveCc: (email) => _removeRecipient(_cc, email),
      onPickAttachments: _pickAttachments,
      onRemoveAttachment: (index) {
        setState(() => _attachments.removeAt(index));
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final main = _ComposeMain(
          label: reply ? 'ОТВЕТ' : 'НОВОЕ ПИСЬМО',
          subjectController: _subjectController,
          bodyController: _bodyController,
          bodyFocus: _bodyFocus,
          autofocusSubject: !reply,
          onClose: _close,
          onSubmit: _submit,
          trailing: wide ? null : parameters,
        );
        if (!wide) return main;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: main),
            const DdtSidePanelDivider(),
            SizedBox(
              width: 320.w,
              child: _ComposeScroll(child: parameters),
            ),
          ],
        );
      },
    );
  }
}

class _ComposeMain extends StatelessWidget {
  const _ComposeMain({
    required this.label,
    required this.subjectController,
    required this.bodyController,
    required this.bodyFocus,
    required this.autofocusSubject,
    required this.onClose,
    required this.onSubmit,
    this.trailing,
  });

  final String label;
  final TextEditingController subjectController;
  final DdtMarkdownLiveController bodyController;
  final FocusNode bodyFocus;
  final bool autofocusSubject;
  final VoidCallback onClose;
  final VoidCallback onSubmit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top = DdtShellMetrics.maybeOf(context)?.contentInsetTop ?? 0;
    final bottom = DdtShellMetrics.maybeOf(context)?.contentInsetBottom ?? 24.h;
    final titleStyle = DdtTheme.style(
      fontSize: DdtTypography.entityTitleSize,
      fontWeight: FontWeight.w700,
      color: DdtTheme.textPrimary(context),
    );

    return ScrollConfiguration(
      behavior: const DdtScrollBehavior(),
      child: ListView(
        primary: false,
        padding: EdgeInsets.fromLTRB(20.w, top + 12.h, 20.w, bottom),
        children: [
          _ComposeToolbar(label: label, onClose: onClose, onSubmit: onSubmit),
          SizedBox(height: 16.h),
          _ComposeTitleField(
            controller: subjectController,
            hint: 'Тема',
            autofocus: autofocusSubject,
            style: titleStyle,
            onSubmitted: (_) => bodyFocus.requestFocus(),
          ),
          SizedBox(height: 8.h),
          DdtMarkdownDescriptionInput(
            controller: bodyController,
            focusNode: bodyFocus,
            label: null,
            hint: 'Текст письма',
            minLines: 8,
            plain: true,
          ),
          if (trailing != null) ...[SizedBox(height: 28.h), trailing!],
        ],
      ),
    );
  }
}

class _ComposeParameters extends StatelessWidget {
  const _ComposeParameters({
    required this.to,
    required this.cc,
    required this.taken,
    required this.attachments,
    required this.recipientHint,
    required this.onAddTo,
    required this.onAddCc,
    required this.onRemoveTo,
    required this.onRemoveCc,
    required this.onPickAttachments,
    required this.onRemoveAttachment,
  });

  final List<CalendarPerson> to;
  final List<CalendarPerson> cc;
  final Set<String> taken;
  final List<MailOutgoingAttachment> attachments;
  final String? recipientHint;
  final ValueChanged<CalendarPerson> onAddTo;
  final ValueChanged<CalendarPerson> onAddCc;
  final ValueChanged<String> onRemoveTo;
  final ValueChanged<String> onRemoveCc;
  final VoidCallback onPickAttachments;
  final ValueChanged<int> onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Получатели',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
        SizedBox(height: 12.h),
        _RecipientField(
          label: 'Кому',
          people: to,
          blocked: taken,
          initialQuery: to.isEmpty ? recipientHint ?? '' : '',
          onAdd: onAddTo,
          onRemove: onRemoveTo,
        ),
        SizedBox(height: 14.h),
        _RecipientField(
          label: 'Копия',
          people: cc,
          blocked: taken,
          onAdd: onAddCc,
          onRemove: onRemoveCc,
        ),
        SizedBox(height: 22.h),
        Text(
          'Вложения',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
        SizedBox(height: 10.h),
        _AttachButton(onPressed: onPickAttachments),
        if (attachments.isNotEmpty) ...[
          SizedBox(height: 10.h),
          for (var index = 0; index < attachments.length; index++)
            _AttachmentRow(
              file: attachments[index],
              onRemove: () => onRemoveAttachment(index),
            ),
        ],
      ],
    );
  }
}

class _RecipientField extends StatefulWidget {
  const _RecipientField({
    required this.label,
    required this.people,
    required this.blocked,
    required this.onAdd,
    required this.onRemove,
    this.initialQuery = '',
  });

  final String label;
  final List<CalendarPerson> people;
  final Set<String> blocked;
  final ValueChanged<CalendarPerson> onAdd;
  final ValueChanged<String> onRemove;
  final String initialQuery;

  @override
  State<_RecipientField> createState() => _RecipientFieldState();
}

class _RecipientFieldState extends State<_RecipientField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  bool _searching = false;
  List<CalendarPerson> _results = const [];

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery.trim();
    if (query.isEmpty) return;
    _controller.text = query;
    _search(query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    final generation = ++_generation;
    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _results = const [];
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await ewsApi.searchCalendarPeople(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _results = [
          for (final person in results)
            if (!widget.blocked.contains(person.email.toLowerCase())) person,
        ];
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _results = const [];
      });
    }
  }

  void _submitQuery(String value) {
    _debounce?.cancel();
    final needle = value.trim();
    if (needle.contains('@')) {
      widget.onAdd(
        CalendarPerson(email: needle.toLowerCase(), displayName: needle),
      );
      _clearQuery();
      return;
    }
    _search(needle);
  }

  void _add(CalendarPerson person) {
    widget.onAdd(person);
    _clearQuery();
  }

  void _clearQuery() {
    _debounce?.cancel();
    _generation++;
    _controller.clear();
    setState(() {
      _searching = false;
      _results = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSmallSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
        SizedBox(height: 6.h),
        _PeopleSearchField(
          controller: _controller,
          searching: _searching,
          results: _results,
          onChanged: _onChanged,
          onSubmitted: _submitQuery,
          onAdd: _add,
        ),
        if (widget.people.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final person in widget.people)
                _RecipientChip(
                  person: person,
                  onRemove: () => widget.onRemove(person.email),
                ),
            ],
          ),
        ],
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

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({required this.person, required this.onRemove});

  final CalendarPerson person;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final closeSlot = 22.w;
        final chipMax = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - closeSlot).clamp(
                0.0,
                constraints.maxWidth,
              )
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

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = DdtTheme.sidePanelTextSecondary(context);
    return Semantics(
      button: true,
      label: 'Прикрепить файл',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Row(
            children: [
              DdtIcon(DdtIcons.paperclip, size: 14.sp, color: color),
              SizedBox(width: 8.w),
              Text(
                'Прикрепить файл',
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.file, required this.onRemove});

  final MailOutgoingAttachment file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          DdtIcon(
            DdtIcons.file,
            size: 13.sp,
            color: DdtTheme.textMuted(context),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSize,
                    color: DdtTheme.textPrimary(context),
                  ),
                ),
                Text(
                  file.displaySize,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.microSize,
                    color: DdtTheme.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Убрать ${file.name}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: DdtIcon(
                  DdtIcons.close,
                  size: 11.sp,
                  color: DdtTheme.textMuted(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeToolbar extends StatelessWidget {
  const _ComposeToolbar({
    required this.label,
    required this.onClose,
    required this.onSubmit,
  });

  final String label;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Назад к почте',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: DdtIcon(
                DdtIcons.chevronLeft,
                size: 14 / DdtIcon.visualScale,
                color: DdtTheme.sidePanelTextSecondary(context),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
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
          text: 'Отправить',
          onPressed: onSubmit,
          borderRadius: DdtTheme.radius,
        ),
      ],
    );
  }
}

class _ComposeTitleField extends StatelessWidget {
  const _ComposeTitleField({
    required this.controller,
    required this.hint,
    required this.style,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextStyle style;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      style: style,
      cursorColor: accent,
      cursorWidth: 1.4,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        isCollapsed: true,
        isDense: true,
        filled: false,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: hint,
        hintStyle: style.copyWith(color: DdtTheme.textMuted(context)),
      ),
    );
  }
}

class _ComposeScroll extends StatelessWidget {
  const _ComposeScroll({required this.child});

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

String _contentType(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'html' || 'htm' => 'text/html',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip' => 'application/zip',
    'json' => 'application/json',
    _ => 'application/octet-stream',
  };
}
