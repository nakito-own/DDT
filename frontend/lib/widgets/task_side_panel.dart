import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../models/task.dart';
import '../models/task_comment.dart';
import '../models/task_link.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import '../router/route_paths.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_date_time_picker.dart';
import '../utils/task_formatters.dart';
import 'ddt_app_input.dart';
import 'ddt_side_panel.dart';
import 'task_comments_section.dart';

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

    return TaskSidePanelDetails(task: task!, taskTypes: taskTypes);
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
  late Task _currentTask;

  late TaskStatus _status;
  late int? _typeId;
  late TaskPriority? _priority;
  late DateTime _timeSet;
  late DateTime? _timeStart;
  late DateTime? _timeEnd;
  late DateTime? _deadline;
  final List<_LinkDraft> _links = [];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _currentTask = task;

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

    _status = task.status;
    _typeId = task.typeId;
    _priority = task.priority;
    _timeSet = task.timeSet;
    _timeStart = task.timeStart;
    _timeEnd = task.timeEnd;
    _deadline = task.deadline;

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
      Toast.show(message: 'Введите название задачи', type: ToastType.warning);
      return;
    }

    final type = _typeById(_typeId);
    final links = _links
        .where((item) => item.urlController.text.trim().isNotEmpty)
        .toList();

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
      comments: _currentTask.comments,
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
      actions: [
        IconButton(
          tooltip: 'Открыть задачу',
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            final spaceId = widget.task.spaceId;
            router.go(
              spaceId == null
                  ? RoutePaths.task(widget.task.id)
                  : RoutePaths.spaceTask(spaceId, widget.task.id),
            );
          },
          icon: Icon(CupertinoIcons.link, size: 18.sp),
          visualDensity: VisualDensity.compact,
        ),
      ],
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
            DdtAppInput(
              label: 'Название',
              hint: 'Введите название задачи',
              controller: _titleController,
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            DdtAppInput(
              label: 'Описание',
              hint: 'Описание задачи',
              controller: _descriptionController,
              type: InputType.multiline,
              maxLines: 4,
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            _TaskFormTableSections(
              sections: [
                [
                  _TaskFormTableRow(
                    label: 'Статус',
                    child: _DropdownControl<TaskStatus>(
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
                  ),
                  _TaskFormTableRow(
                    label: 'Тип',
                    child: _DropdownControl<int?>(
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
                  ),
                  _TaskFormTableRow(
                    label: 'Приоритет',
                    child: _DropdownControl<TaskPriority?>(
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
                  ),
                ],
                [
                  _TaskFormTableRow(
                    label: 'Автор',
                    child: _FormTableTextInput(
                      hint: 'ID, необязательно',
                      controller: _authorController,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Исполнитель',
                    child: _FormTableTextInput(
                      hint: 'ID, необязательно',
                      controller: _executorController,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Ответственный',
                    child: _FormTableTextInput(
                      hint: 'ID, необязательно',
                      controller: _responsibleController,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
                [
                  _TaskFormTableRow(
                    label: 'Создание',
                    child: _FormTableDateTimeControl(
                      value: _timeSet,
                      onChanged: (value) {
                        if (value != null) setState(() => _timeSet = value);
                      },
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Начало',
                    child: _FormTableDateTimeControl(
                      value: _timeStart,
                      nullable: true,
                      onChanged: (value) => setState(() => _timeStart = value),
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Окончание',
                    child: _FormTableDateTimeControl(
                      value: _timeEnd,
                      nullable: true,
                      onChanged: (value) => setState(() => _timeEnd = value),
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Дедлайн',
                    child: _FormTableDateTimeControl(
                      value: _deadline,
                      nullable: true,
                      onChanged: (value) => setState(() => _deadline = value),
                    ),
                  ),
                ],
              ],
              trailingDivider: true,
            ),
            DdtTheme.verticalGap(),
            Row(
              children: [
                Expanded(child: _SectionTitle(title: 'Ссылки')),
                _CompactIconTextButton(
                  label: 'Добавить',
                  icon: CupertinoIcons.add,
                  onPressed: _addLinkDraft,
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
            TaskCommentsSection(
              task: _currentTask,
              compact: true,
              onTaskChanged: (task) {
                setState(() => _currentTask = task);
              },
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
  State<TaskSidePanelCreateForm> createState() =>
      _TaskSidePanelCreateFormState();
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
  late int? _typeId = widget.taskTypes.isNotEmpty
      ? widget.taskTypes.first.id
      : null;
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
      Toast.show(message: 'Введите название задачи', type: ToastType.warning);
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
            DdtAppInput(
              label: 'Название',
              hint: 'Введите название задачи',
              controller: _titleController,
              autofocus: true,
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            DdtAppInput(
              label: 'Описание',
              hint: 'Описание задачи',
              controller: _descriptionController,
              type: InputType.multiline,
              maxLines: 4,
              borderRadius: DdtTheme.radius,
            ),
            DdtTheme.verticalGap(),
            _TaskFormTableSections(
              sections: [
                [
                  _TaskFormTableRow(
                    label: 'Статус',
                    child: _DropdownControl<TaskStatus>(
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
                  ),
                  _TaskFormTableRow(
                    label: 'Тип',
                    child: _DropdownControl<int?>(
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
                  ),
                  _TaskFormTableRow(
                    label: 'Приоритет',
                    child: _DropdownControl<TaskPriority?>(
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
                  ),
                ],
                [
                  _TaskFormTableRow(
                    label: 'Автор',
                    child: _FormTableTextInput(
                      hint: 'ID, необязательно',
                      controller: _authorController,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Исполнитель',
                    child: _FormTableTextInput(
                      hint: 'ID, необязательно',
                      controller: _executorController,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Ответственный',
                    child: _FormTableTextInput(
                      hint: 'ID, необязательно',
                      controller: _responsibleController,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
                [
                  _TaskFormTableRow(
                    label: 'Создание',
                    child: _FormTableDateTimeControl(
                      value: _timeSet,
                      onChanged: (value) {
                        if (value != null) setState(() => _timeSet = value);
                      },
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Начало',
                    child: _FormTableDateTimeControl(
                      value: _timeStart,
                      nullable: true,
                      onChanged: (value) => setState(() => _timeStart = value),
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Окончание',
                    child: _FormTableDateTimeControl(
                      value: _timeEnd,
                      nullable: true,
                      onChanged: (value) => setState(() => _timeEnd = value),
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Дедлайн',
                    child: _FormTableDateTimeControl(
                      value: _deadline,
                      nullable: true,
                      onChanged: (value) => setState(() => _deadline = value),
                    ),
                  ),
                ],
              ],
              trailingDivider: true,
            ),
            DdtTheme.verticalGap(),
            Row(
              children: [
                Expanded(child: _SectionTitle(title: 'Ссылки')),
                _CompactIconTextButton(
                  label: 'Добавить',
                  icon: CupertinoIcons.add,
                  onPressed: _addLinkDraft,
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
            DdtAppInput(
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
  const _LinkDraftEditor({required this.draft, required this.onRemove});

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
                icon: Icon(CupertinoIcons.trash, size: 14.sp),
                iconSize: 14.sp,
                padding: EdgeInsets.all(4.w),
                constraints: BoxConstraints(minWidth: 24.w, minHeight: 24.h),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          DdtAppInput(
            label: 'URL',
            hint: 'https://...',
            controller: draft.urlController,
            borderRadius: DdtTheme.radius,
          ),
          SizedBox(height: 8.h),
          DdtAppInput(
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

class _FormTableControl {
  _FormTableControl._();

  static const double rowSpacing = 12;
  static const double labelGap = 12;
  static const double labelColumnWidth = 128;

  static EdgeInsetsGeometry padding() =>
      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h);

  static TextStyle textStyle(BuildContext context) => DdtTheme.style(
    fontSize: 14.sp,
    color: DdtTheme.sidePanelTextSecondary(context),
  );

  static InputDecoration decoration(
    BuildContext context, {
    String? hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: DdtTheme.inputHintStyle(context),
      contentPadding: padding(),
      isDense: true,
      suffixIcon: suffixIcon,
    );
  }
}

class _TaskFormTableRow {
  const _TaskFormTableRow({required this.label, required this.child});

  final String label;
  final Widget child;
}

class _TaskFormSectionDivider extends StatelessWidget {
  const _TaskFormSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _FormTableControl.rowSpacing.h),
      child: Divider(
        height: 1,
        thickness: 1,
        color: DdtTheme.sidePanelDivider(context),
      ),
    );
  }
}

class _TaskFormTableSections extends StatelessWidget {
  const _TaskFormTableSections({
    required this.sections,
    this.trailingDivider = false,
  });

  final List<List<_TaskFormTableRow>> sections;
  final bool trailingDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const _TaskFormSectionDivider(),
          _TaskFormTable(rows: sections[i]),
        ],
        if (trailingDivider) const _TaskFormSectionDivider(),
      ],
    );
  }
}

class _TaskFormTable extends StatelessWidget {
  const _TaskFormTable({required this.rows});

  final List<_TaskFormTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final labelStyle = DdtTheme.style(
      fontSize: 13.sp,
      fontWeight: FontWeight.w600,
      color: DdtTheme.sidePanelTextPrimary(context),
    );

    return Table(
      columnWidths: {
        0: FixedColumnWidth(_FormTableControl.labelColumnWidth.w),
        1: const FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (var i = 0; i < rows.length; i++)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  right: _FormTableControl.labelGap.w,
                  bottom: i < rows.length - 1
                      ? _FormTableControl.rowSpacing.h
                      : 0,
                ),
                child: Text(rows[i].label, style: labelStyle),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: i < rows.length - 1
                      ? _FormTableControl.rowSpacing.h
                      : 0,
                ),
                child: rows[i].child,
              ),
            ],
          ),
      ],
    );
  }
}

class _CompactIconTextButton extends StatelessWidget {
  const _CompactIconTextButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 14.sp),
      label: Text(
        label,
        style: DdtTheme.style(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _FormTableTextInput extends StatelessWidget {
  const _FormTableTextInput({
    required this.hint,
    required this.controller,
    this.inputFormatters,
  });

  final String hint;
  final TextEditingController controller;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      inputFormatters: inputFormatters,
      keyboardType: TextInputType.number,
      style: _FormTableControl.textStyle(context),
      decoration: _FormTableControl.decoration(context, hintText: hint),
    );
  }
}

class _FormTableDateTimeControl extends StatelessWidget {
  const _FormTableDateTimeControl({
    required this.value,
    required this.onChanged,
    this.nullable = false,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool nullable;

  Future<void> _pick(BuildContext context) async {
    final initial = value ?? DateTime.now();
    final picked = await showDdtDateTimePicker(
      context: context,
      initialDateTime: initial,
    );
    if (picked == null || !context.mounted) return;

    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: DdtTheme.radius,
      child: InputDecorator(
        decoration: _FormTableControl.decoration(
          context,
          suffixIcon: nullable && value != null
              ? IconButton(
                  tooltip: 'Очистить',
                  onPressed: () => onChanged(null),
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 18.sp,
                    color: DdtTheme.sidePanelTextMuted(context),
                  ),
                  visualDensity: VisualDensity.compact,
                )
              : null,
        ),
        isEmpty: false,
        child: Text(
          value != null ? formatTaskDateTime(value!) : 'Не указано',
          style: _FormTableControl.textStyle(context),
        ),
      ),
    );
  }
}

class _DropdownControl<T> extends StatelessWidget {
  const _DropdownControl({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      borderRadius: DdtTheme.inputControlBorderRadius,
      dropdownColor: Theme.of(context).brightness == Brightness.dark
          ? DdtTheme.darkSurface
          : DdtTheme.lightSurface,
      style: _FormTableControl.textStyle(context),
      decoration: _FormTableControl.decoration(context),
      items: items,
      onChanged: onChanged,
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
