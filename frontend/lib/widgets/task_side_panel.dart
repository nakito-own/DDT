import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/task.dart';
import '../models/task_comment.dart';
import '../models/task_link.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import 'ddt_side_panel.dart';

enum TaskSidePanelMode { view, create }

Future<Task?> showTaskSidePanel(
  BuildContext context, {
  required TaskSidePanelMode mode,
  Task? task,
  TaskStatus initialStatus = TaskStatus.todo,
  required List<TaskType> taskTypes,
  int? defaultAuthorId,
}) {
  return showDdtSidePanel<Task>(
    context,
    child: TaskSidePanel(
      mode: mode,
      task: task,
      initialStatus: initialStatus,
      taskTypes: taskTypes,
      defaultAuthorId: defaultAuthorId,
    ),
  );
}

class TaskSidePanel extends StatelessWidget {
  const TaskSidePanel({
    super.key,
    required this.mode,
    this.task,
    this.initialStatus = TaskStatus.todo,
    required this.taskTypes,
    this.defaultAuthorId,
  });

  final TaskSidePanelMode mode;
  final Task? task;
  final TaskStatus initialStatus;
  final List<TaskType> taskTypes;
  final int? defaultAuthorId;

  @override
  Widget build(BuildContext context) {
    if (mode == TaskSidePanelMode.create) {
      return TaskSidePanelCreateForm(
        initialStatus: initialStatus,
        taskTypes: taskTypes,
        defaultAuthorId: defaultAuthorId,
      );
    }

    return TaskSidePanelDetails(
      task: task!,
      taskTypes: taskTypes,
    );
  }
}

class TaskSidePanelDetails extends StatefulWidget {
  const TaskSidePanelDetails({
    super.key,
    required this.task,
    required this.taskTypes,
  });

  final Task task;
  final List<TaskType> taskTypes;

  @override
  State<TaskSidePanelDetails> createState() => _TaskSidePanelDetailsState();
}

class _TaskSidePanelDetailsState extends State<TaskSidePanelDetails> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _authorController;
  late final TextEditingController _executorController;
  late final TextEditingController _responsibleController;
  late final TextEditingController _commentController;

  late TaskStatus _status;
  late int? _typeId;
  late TaskPriority? _priority;
  late DateTime _timeSet;
  late DateTime? _timeStart;
  late DateTime? _timeEnd;
  late DateTime? _deadline;
  late final List<TaskComment> _existingComments;
  final List<_LinkDraft> _links = [];

  @override
  void initState() {
    super.initState();
    final task = widget.task;

    _titleController = TextEditingController(text: task.title);
    _descriptionController = TextEditingController(text: task.description);
    _authorController = TextEditingController(
      text: task.authorId?.toString() ?? '',
    );
    _executorController = TextEditingController(
      text: task.executorId?.toString() ?? '',
    );
    _responsibleController = TextEditingController(
      text: task.responsibleId?.toString() ?? '',
    );
    _commentController = TextEditingController();

    _status = task.status;
    _typeId = task.typeId;
    _priority = task.priority;
    _timeSet = task.timeSet;
    _timeStart = task.timeStart;
    _timeEnd = task.timeEnd;
    _deadline = task.deadline;
    _existingComments = List<TaskComment>.from(task.comments);

    for (final link in task.links ?? const <TaskLink>[]) {
      final draft = _LinkDraft();
      draft.urlController.text = link.url;
      draft.titleController.text = link.title ?? '';
      _links.add(draft);
    }
  }

  @override
  void dispose() {
    for (final draft in _links) {
      draft.dispose();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _authorController.dispose();
    _executorController.dispose();
    _responsibleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  int? _parseUserId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  TaskType? _typeById(int? typeId) {
    if (typeId == null) return null;
    for (final type in widget.taskTypes) {
      if (type.id == typeId) return type;
    }
    return null;
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      Toast.show(
        message: 'Введите название задачи',
        type: ToastType.warning,
      );
      return;
    }

    final type = _typeById(_typeId);
    final links = _links
        .where((item) => item.urlController.text.trim().isNotEmpty)
        .toList();

    final commentText = _commentController.text.trim();
    final comments = List<TaskComment>.from(_existingComments);
    if (commentText.isNotEmpty) {
      comments.add(
        TaskComment(
          id: comments.length + 1,
          text: commentText,
          authorId: _parseUserId(_authorController.text),
          createdAt: DateTime.now(),
        ),
      );
    }

    final taskLinks = links.isEmpty
        ? null
        : links
            .asMap()
            .entries
            .map(
              (entry) => TaskLink(
                id: entry.key + 1,
                url: entry.value.urlController.text.trim(),
                title: entry.value.titleController.text.trim().isEmpty
                    ? null
                    : entry.value.titleController.text.trim(),
              ),
            )
            .toList();

    final task = Task(
      id: widget.task.id,
      title: title,
      status: _status,
      typeId: type?.id,
      type: type,
      description: _descriptionController.text.trim(),
      authorId: _parseUserId(_authorController.text),
      executorId: _parseUserId(_executorController.text),
      responsibleId: _parseUserId(_responsibleController.text),
      timeSet: _timeSet,
      timeStart: _timeStart,
      timeEnd: _timeEnd,
      deadline: _deadline,
      priority: _priority,
      links: taskLinks,
      comments: comments,
      createdAt: widget.task.createdAt,
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(task);
  }

  void _addLinkDraft() {
    setState(() => _links.add(_LinkDraft()));
  }

  void _removeLinkDraft(_LinkDraft draft) {
    setState(() {
      draft.dispose();
      _links.remove(draft);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DdtSidePanelShell(
      title: 'Задача',
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
              text: 'Сохранить',
              borderRadius: DdtTheme.radius,
              onPressed: _submit,
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 16.h, bottom: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              label: 'Название',
              hint: 'Введите название задачи',
              controller: _titleController,
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            AppInput(
              label: 'Описание',
              hint: 'Описание задачи',
              controller: _descriptionController,
              type: InputType.multiline,
              maxLines: 4,
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            _DropdownField<TaskStatus>(
              label: 'Статус',
              value: _status,
              items: [
                for (final status in TaskStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            DdtTheme.verticalGap(),
            _DropdownField<int?>(
              label: 'Тип',
              value: _typeId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Не указан'),
                ),
                for (final type in widget.taskTypes)
                  DropdownMenuItem(
                    value: type.id,
                    child: Text(type.name),
                  ),
              ],
              onChanged: (value) => setState(() => _typeId = value),
            ),
            DdtTheme.verticalGap(),
            _DropdownField<TaskPriority?>(
              label: 'Приоритет',
              value: _priority,
              items: [
                const DropdownMenuItem<TaskPriority?>(
                  value: null,
                  child: Text('Не указан'),
                ),
                for (final priority in TaskPriority.values)
                  DropdownMenuItem(
                    value: priority,
                    child: Text(priority.label),
                  ),
              ],
              onChanged: (value) => setState(() => _priority = value),
            ),
            DdtTheme.verticalGap(),
            _SectionTitle(title: 'Участники'),
            SizedBox(height: 8.h),
            AppInput(
              label: 'Автор (ID)',
              hint: 'Необязательно',
              controller: _authorController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              borderRadius: DdtTheme.radius,
            ),
            SizedBox(height: 12.h),
            AppInput(
              label: 'Исполнитель (ID)',
              hint: 'Необязательно',
              controller: _executorController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              borderRadius: DdtTheme.radius,
            ),
            SizedBox(height: 12.h),
            AppInput(
              label: 'Ответственный (ID)',
              hint: 'Необязательно',
              controller: _responsibleController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            _SectionTitle(title: 'Время'),
            SizedBox(height: 8.h),
            _DateTimeField(
              label: 'Время создания',
              value: _timeSet,
              onChanged: (value) {
                if (value != null) setState(() => _timeSet = value);
              },
            ),
            SizedBox(height: 12.h),
            _DateTimeField(
              label: 'Время начала',
              value: _timeStart,
              nullable: true,
              onChanged: (value) => setState(() => _timeStart = value),
            ),
            SizedBox(height: 12.h),
            _DateTimeField(
              label: 'Время окончания',
              value: _timeEnd,
              nullable: true,
              onChanged: (value) => setState(() => _timeEnd = value),
            ),
            SizedBox(height: 12.h),
            _DateTimeField(
              label: 'Дедлайн',
              value: _deadline,
              nullable: true,
              onChanged: (value) => setState(() => _deadline = value),
            ),
            DdtTheme.verticalGap(),
            Row(
              children: [
                Expanded(child: _SectionTitle(title: 'Ссылки')),
                TextButton.icon(
                  onPressed: _addLinkDraft,
                  icon: Icon(CupertinoIcons.add, size: 18.sp),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            if (_links.isEmpty)
              Text(
                'Ссылки не добавлены',
                style: DdtTheme.style(
                  fontSize: 13.sp,
                  color: DdtTheme.sidePanelTextMuted(context),
                ),
              )
            else
              for (final draft in _links) ...[
                SizedBox(height: 8.h),
                _LinkDraftEditor(
                  draft: draft,
                  onRemove: () => _removeLinkDraft(draft),
                ),
              ],
            if (_existingComments.isNotEmpty) ...[
              DdtTheme.verticalGap(),
              _SectionTitle(title: 'Комментарии'),
              SizedBox(height: 8.h),
              for (final comment in _existingComments)
                _CommentTile(comment: comment),
            ],
            DdtTheme.verticalGap(),
            _SectionTitle(title: 'Новый комментарий'),
            SizedBox(height: 8.h),
            AppInput(
              label: 'Комментарий',
              hint: 'Необязательно',
              controller: _commentController,
              type: InputType.multiline,
              maxLines: 3,
              borderRadius: DdtTheme.radius,
            ),
          ],
        ),
      ),
    );
  }
}

class TaskSidePanelCreateForm extends StatefulWidget {
  const TaskSidePanelCreateForm({
    super.key,
    required this.initialStatus,
    required this.taskTypes,
    this.defaultAuthorId,
  });

  final TaskStatus initialStatus;
  final List<TaskType> taskTypes;
  final int? defaultAuthorId;

  @override
  State<TaskSidePanelCreateForm> createState() => _TaskSidePanelCreateFormState();
}

class _TaskSidePanelCreateFormState extends State<TaskSidePanelCreateForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final TextEditingController _authorController;
  final _executorController = TextEditingController();
  final _responsibleController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authorController = TextEditingController(
      text: widget.defaultAuthorId?.toString() ?? '',
    );
  }

  late TaskStatus _status = widget.initialStatus;
  late int? _typeId = widget.taskTypes.isNotEmpty ? widget.taskTypes.first.id : null;
  TaskPriority? _priority;
  DateTime _timeSet = DateTime.now();
  DateTime? _timeStart;
  DateTime? _timeEnd;
  DateTime? _deadline;
  final List<_LinkDraft> _links = [];

  @override
  void dispose() {
    for (final draft in _links) {
      draft.dispose();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _authorController.dispose();
    _executorController.dispose();
    _responsibleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  int? _parseUserId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  TaskType? _typeById(int? typeId) {
    if (typeId == null) return null;
    for (final type in widget.taskTypes) {
      if (type.id == typeId) return type;
    }
    return null;
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      Toast.show(
        message: 'Введите название задачи',
        type: ToastType.warning,
      );
      return;
    }

    final type = _typeById(_typeId);
    final links = _links
        .where((item) => item.urlController.text.trim().isNotEmpty)
        .toList();

    final commentText = _commentController.text.trim();
    final comments = commentText.isEmpty
        ? <TaskComment>[]
        : [
            TaskComment(
              id: 0,
              text: commentText,
              authorId: _parseUserId(_authorController.text),
              createdAt: DateTime.now(),
            ),
          ];

    final taskLinks = links.isEmpty
        ? null
        : links
            .asMap()
            .entries
            .map(
              (entry) => TaskLink(
                id: entry.key + 1,
                url: entry.value.urlController.text.trim(),
                title: entry.value.titleController.text.trim().isEmpty
                    ? null
                    : entry.value.titleController.text.trim(),
              ),
            )
            .toList();

    final task = Task(
      id: 0,
      title: title,
      status: _status,
      typeId: type?.id,
      type: type,
      description: _descriptionController.text.trim(),
      authorId: _parseUserId(_authorController.text),
      executorId: _parseUserId(_executorController.text),
      responsibleId: _parseUserId(_responsibleController.text),
      timeSet: _timeSet,
      timeStart: _timeStart,
      timeEnd: _timeEnd,
      deadline: _deadline,
      priority: _priority,
      links: taskLinks,
      comments: comments,
    );

    Navigator.of(context).pop(task);
  }

  void _addLinkDraft() {
    setState(() => _links.add(_LinkDraft()));
  }

  void _removeLinkDraft(_LinkDraft draft) {
    setState(() {
      draft.dispose();
      _links.remove(draft);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DdtSidePanelShell(
      title: 'Новая задача',
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
              text: 'Создать',
              borderRadius: DdtTheme.radius,
              onPressed: _submit,
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 16.h, bottom: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(
              label: 'Название',
              hint: 'Введите название задачи',
              controller: _titleController,
              autofocus: true,
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            AppInput(
              label: 'Описание',
              hint: 'Описание задачи',
              controller: _descriptionController,
              type: InputType.multiline,
              maxLines: 4,
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            _DropdownField<TaskStatus>(
              label: 'Статус',
              value: _status,
              items: [
                for (final status in TaskStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            DdtTheme.verticalGap(),
            _DropdownField<int?>(
              label: 'Тип',
              value: _typeId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Не указан'),
                ),
                for (final type in widget.taskTypes)
                  DropdownMenuItem(
                    value: type.id,
                    child: Text(type.name),
                  ),
              ],
              onChanged: (value) => setState(() => _typeId = value),
            ),
            DdtTheme.verticalGap(),
            _DropdownField<TaskPriority?>(
              label: 'Приоритет',
              value: _priority,
              items: [
                const DropdownMenuItem<TaskPriority?>(
                  value: null,
                  child: Text('Не указан'),
                ),
                for (final priority in TaskPriority.values)
                  DropdownMenuItem(
                    value: priority,
                    child: Text(priority.label),
                  ),
              ],
              onChanged: (value) => setState(() => _priority = value),
            ),
            DdtTheme.verticalGap(),
            _SectionTitle(title: 'Участники'),
            SizedBox(height: 8.h),
            AppInput(
              label: 'Автор (ID)',
              hint: 'Необязательно',
              controller: _authorController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              borderRadius: DdtTheme.radius,
            ),
            SizedBox(height: 12.h),
            AppInput(
              label: 'Исполнитель (ID)',
              hint: 'Необязательно',
              controller: _executorController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              borderRadius: DdtTheme.radius,
            ),
            SizedBox(height: 12.h),
            AppInput(
              label: 'Ответственный (ID)',
              hint: 'Необязательно',
              controller: _responsibleController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            _SectionTitle(title: 'Время'),
            SizedBox(height: 8.h),
            _DateTimeField(
              label: 'Время создания',
              value: _timeSet,
              onChanged: (value) {
                if (value != null) setState(() => _timeSet = value);
              },
            ),
            SizedBox(height: 12.h),
            _DateTimeField(
              label: 'Время начала',
              value: _timeStart,
              nullable: true,
              onChanged: (value) => setState(() => _timeStart = value),
            ),
            SizedBox(height: 12.h),
            _DateTimeField(
              label: 'Время окончания',
              value: _timeEnd,
              nullable: true,
              onChanged: (value) => setState(() => _timeEnd = value),
            ),
            SizedBox(height: 12.h),
            _DateTimeField(
              label: 'Дедлайн',
              value: _deadline,
              nullable: true,
              onChanged: (value) => setState(() => _deadline = value),
            ),
            DdtTheme.verticalGap(),
            Row(
              children: [
                Expanded(child: _SectionTitle(title: 'Ссылки')),
                TextButton.icon(
                  onPressed: _addLinkDraft,
                  icon: Icon(CupertinoIcons.add, size: 18.sp),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            if (_links.isEmpty)
              Text(
                'Ссылки не добавлены',
                style: DdtTheme.style(
                  fontSize: 13.sp,
                  color: DdtTheme.sidePanelTextMuted(context),
                ),
              )
            else
              for (final draft in _links) ...[
                SizedBox(height: 8.h),
                _LinkDraftEditor(
                  draft: draft,
                  onRemove: () => _removeLinkDraft(draft),
                ),
              ],
            DdtTheme.verticalGap(),
            _SectionTitle(title: 'Комментарий'),
            SizedBox(height: 8.h),
            AppInput(
              label: 'Первый комментарий',
              hint: 'Необязательно',
              controller: _commentController,
              type: InputType.multiline,
              maxLines: 3,
              borderRadius: DdtTheme.radius,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkDraft {
  _LinkDraft()
      : urlController = TextEditingController(),
        titleController = TextEditingController();

  final TextEditingController urlController;
  final TextEditingController titleController;

  void dispose() {
    urlController.dispose();
    titleController.dispose();
  }
}

class _LinkDraftEditor extends StatelessWidget {
  const _LinkDraftEditor({
    required this.draft,
    required this.onRemove,
  });

  final _LinkDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      type: CardType.outlined,
      borderRadius: DdtTheme.radius,
      padding: EdgeInsets.all(12.w),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ссылка',
                  style: DdtTheme.style(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.sidePanelTextPrimary(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Удалить ссылку',
                onPressed: onRemove,
                icon: Icon(CupertinoIcons.trash, size: 18.sp),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          AppInput(
            label: 'URL',
            hint: 'https://...',
            controller: draft.urlController,
            borderRadius: DdtTheme.radius,
          ),
          SizedBox(height: 8.h),
          AppInput(
            label: 'Название',
            hint: 'Необязательно',
            controller: draft.titleController,
            borderRadius: DdtTheme.radius,
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.nullable = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool nullable;

  Future<void> _pick(BuildContext context) async {
    final initial = value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return;

    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: DdtTheme.style(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextPrimary(context),
          ),
        ),
        SizedBox(height: 6.h),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: DdtTheme.roundedShape,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            alignment: Alignment.centerLeft,
          ),
          onPressed: () => _pick(context),
          child: Text(
            value != null ? formatTaskDateTime(value!) : 'Не указано',
            style: DdtTheme.style(
              fontSize: 13.sp,
              color: DdtTheme.sidePanelTextSecondary(context),
            ),
          ),
        ),
        if (nullable && value != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => onChanged(null),
              child: const Text('Очистить'),
            ),
          ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: DdtTheme.style(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextPrimary(context),
          ),
        ),
        SizedBox(height: 6.h),
        DropdownButtonFormField<T>(
          value: value,
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2C)
              : null,
          style: DdtTheme.style(
            fontSize: 14.sp,
            color: DdtTheme.sidePanelTextSecondary(context),
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: DdtTheme.radius),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final TaskComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: AppCard(
        type: CardType.outlined,
        borderRadius: DdtTheme.radius,
        padding: EdgeInsets.all(12.w),
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.person_crop_circle,
                  size: 16.sp,
                  color: DdtTheme.sidePanelTextMuted(context),
                ),
                SizedBox(width: 6.w),
                Text(
                  formatUserRef(comment.authorId, fallback: 'Аноним'),
                  style: DdtTheme.style(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.sidePanelTextSecondary(context),
                  ),
                ),
                if (comment.createdAt != null) ...[
                  const Spacer(),
                  Text(
                    formatTaskDateTime(comment.createdAt!),
                    style: DdtTheme.style(
                      fontSize: 11.sp,
                      color: DdtTheme.sidePanelTextMuted(context),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              comment.text,
              style: DdtTheme.style(
                fontSize: 13.sp,
                height: 1.4,
                color: DdtTheme.sidePanelTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: DdtTheme.style(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: DdtTheme.sidePanelTextPrimary(context),
      ),
    );
  }
}
