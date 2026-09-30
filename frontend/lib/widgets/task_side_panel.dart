import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ddt_markdown_live_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../theme/ddt_icons.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../models/task_comment.dart';
import '../models/task_link.dart';
import '../models/task_priority.dart';
import '../models/task_ref.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import '../router/route_paths.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import '../utils/ddt_date_time_picker.dart';
import '../utils/task_formatters.dart';
import 'ddt_app_input.dart';
import 'ddt_filter_dropdown.dart';
import 'ddt_markdown_description_input.dart';
import 'ddt_side_panel.dart';
import 'task_comments_section.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

enum TaskSidePanelMode { view, create }

/// Tasks that may be linked as a parent/child, without duplicate keys — two
/// items sharing a value would make the relation dropdowns assert.
List<Task> _uniqueRelationCandidates(List<Task> tasks, {int? excludeId}) {
  final seen = <String>{};
  return [
    for (final task in tasks)
      if (task.id != excludeId &&
          task.id > 0 &&
          task.key.isNotEmpty &&
          seen.add(task.key))
        task,
  ];
}

const _relationPickNoneKey = '';

DdtFilterOption _relationPickOption(String key, String title) {
  return DdtFilterOption(key: key, label: '$key · $title');
}

List<DdtFilterOption> _parentPickOptions({
  required List<Task> candidates,
  required List<TaskRef> children,
  required TaskRef? parent,
}) {
  final options = <DdtFilterOption>[
    const DdtFilterOption(key: _relationPickNoneKey, label: 'Нет'),
  ];
  var parentListed = parent == null;
  for (final task in candidates) {
    if (children.any((child) => child.key == task.key)) continue;
    if (task.key == parent?.key) parentListed = true;
    options.add(_relationPickOption(task.key, task.title));
  }
  if (!parentListed && parent != null) {
    options.add(_relationPickOption(parent.key, parent.title));
  }
  return options;
}

List<DdtFilterOption> _childPickOptions({
  required List<Task> candidates,
  required List<TaskRef> children,
  required TaskRef? parent,
}) {
  return [
    for (final task in candidates)
      if (task.key != parent?.key &&
          !children.any((child) => child.key == task.key))
        _relationPickOption(task.key, task.title),
  ];
}

String _relationPickSummary(TaskRef? ref, {required String emptyLabel}) {
  if (ref == null) return emptyLabel;
  return '${ref.key} · ${ref.title}';
}

Future<Task?> showTaskSidePanel(
  BuildContext context, {
  required TaskSidePanelMode mode,
  Task? task,
  TaskStatus initialStatus = TaskStatus.todo,
  required List<TaskType> taskTypes,
  int? defaultAuthorId,
  List<Task>? relatedTasks,
}) {
  return showDdtSidePanel<Task>(
    context,
    child: TaskSidePanel(
      mode: mode,
      task: task,
      initialStatus: initialStatus,
      taskTypes: taskTypes,
      defaultAuthorId: defaultAuthorId,
      relatedTasks: relatedTasks ?? context.read<TasksBloc>().state.allTasks,
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
    this.relatedTasks = const [],
  });

  final TaskSidePanelMode mode;
  final Task? task;
  final TaskStatus initialStatus;
  final List<TaskType> taskTypes;
  final int? defaultAuthorId;
  final List<Task> relatedTasks;

  @override
  Widget build(BuildContext context) {
    if (mode == TaskSidePanelMode.create) {
      return TaskSidePanelCreateForm(
        initialStatus: initialStatus,
        taskTypes: taskTypes,
        defaultAuthorId: defaultAuthorId,
        relatedTasks: relatedTasks,
      );
    }

    return TaskSidePanelDetails(
      task: task!,
      taskTypes: taskTypes,
      relatedTasks: relatedTasks,
    );
  }
}

class TaskSidePanelDetails extends StatefulWidget {
  const TaskSidePanelDetails({
    super.key,
    required this.task,
    required this.taskTypes,
    this.relatedTasks = const [],
  });

  final Task task;
  final List<TaskType> taskTypes;
  final List<Task> relatedTasks;

  @override
  State<TaskSidePanelDetails> createState() => _TaskSidePanelDetailsState();
}

class _TaskSidePanelDetailsState extends State<TaskSidePanelDetails> {
  late final TextEditingController _titleController;
  late final DdtMarkdownLiveController _descriptionController;
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
  late TaskRef? _parent;
  late List<TaskRef> _children;
  final List<_LinkDraft> _links = [];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _currentTask = task;

    _titleController = TextEditingController(text: task.title);
    _descriptionController = DdtMarkdownLiveController(text: task.description);
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
    _parent = task.parent;
    _children = List<TaskRef>.of(task.children);

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

  List<Task> get _relationCandidates =>
      _uniqueRelationCandidates(widget.relatedTasks, excludeId: widget.task.id);

  TaskRef _toRef(Task task) {
    return TaskRef(
      id: task.id,
      key: task.key,
      title: task.title,
      status: task.status,
    );
  }

  void _setParentKey(String? key) {
    setState(() {
      if (key == null || key.isEmpty) {
        _parent = null;
        return;
      }
      for (final task in _relationCandidates) {
        if (task.key == key) {
          _parent = _toRef(task);
          _children.removeWhere((child) => child.key == key);
          return;
        }
      }
    });
  }

  void _addChildKey(String? key) {
    if (key == null || key.isEmpty) return;
    if (_children.any((child) => child.key == key)) return;
    if (_parent?.key == key) return;
    for (final task in _relationCandidates) {
      if (task.key == key) {
        setState(() => _children = [..._children, _toRef(task)]);
        return;
      }
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      DdtToast.show(
        message: 'Введите название задачи',
        type: ToastType.warning,
      );
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
      key: widget.task.key,
      title: title,
      status: _status,
      typeId: type?.id,
      type: type,
      description: _descriptionController.text.trim(),
      authorId: _parseUserId(_authorController.text),
      executorId: _parseUserId(_executorController.text),
      responsibleId: _parseUserId(_responsibleController.text),
      ownerId: widget.task.ownerId,
      spaceId: widget.task.spaceId,
      spaceKey: widget.task.spaceKey,
      parentId: _parent?.id,
      parent: _parent,
      children: _children,
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
            final location = RoutePaths.task(widget.task.apiRef);
            Navigator.of(context).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              router.go(location);
            });
          },
          icon: DdtIcon(DdtIcons.link, size: 18.sp),
          visualDensity: VisualDensity.compact,
        ),
      ],
      footer: Row(
        children: [
          Expanded(
            child: Button(
              text: 'Отмена',
              type: ButtonType.outlined,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Button(text: 'Сохранить', onPressed: _submit),
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
            ),
            DdtTheme.verticalGap(),
            DdtMarkdownDescriptionInput(controller: _descriptionController),
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
                      placeholderWhenNull: true,
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
                      placeholderWhenNull: true,
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
                  _TaskFormTableRow(
                    label: 'Родитель',
                    child: _FormTableSearchableDropdown(
                      label: _relationPickSummary(_parent, emptyLabel: 'Нет'),
                      placeholder: _parent == null,
                      options: _parentPickOptions(
                        candidates: _relationCandidates,
                        children: _children,
                        parent: _parent,
                      ),
                      selected: {_parent?.key ?? _relationPickNoneKey},
                      onSelected: (key) => _setParentKey(
                        key.isEmpty ? null : key,
                      ),
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Дочерние',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FormTableSearchableDropdown(
                          label: 'Добавить задачу',
                          placeholder: true,
                          options: _childPickOptions(
                            candidates: _relationCandidates,
                            children: _children,
                            parent: _parent,
                          ),
                          selected: const {},
                          emptyLabel: 'Нет доступных задач',
                          onSelected: _addChildKey,
                        ),
                        if (_children.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              for (final child in _children)
                                _TaskChildRelationChip(
                                  child: child,
                                  onRemove: () {
                                    setState(
                                      () => _children.removeWhere(
                                        (item) => item.key == child.key,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ],
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
                  icon: DdtIcons.add,
                  onPressed: _addLinkDraft,
                ),
              ],
            ),
            if (_links.isEmpty)
              Text(
                'Ссылки не добавлены',
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
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
    this.relatedTasks = const [],
  });

  final TaskStatus initialStatus;
  final List<TaskType> taskTypes;
  final int? defaultAuthorId;
  final List<Task> relatedTasks;

  @override
  State<TaskSidePanelCreateForm> createState() =>
      _TaskSidePanelCreateFormState();
}

class _TaskSidePanelCreateFormState extends State<TaskSidePanelCreateForm> {
  final _titleController = TextEditingController();
  final _descriptionController = DdtMarkdownLiveController();
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
  TaskRef? _parent;
  List<TaskRef> _children = [];
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

  List<Task> get _relationCandidates =>
      _uniqueRelationCandidates(widget.relatedTasks);

  TaskRef _toRef(Task task) {
    return TaskRef(
      id: task.id,
      key: task.key,
      title: task.title,
      status: task.status,
    );
  }

  void _setParentKey(String? key) {
    setState(() {
      if (key == null || key.isEmpty) {
        _parent = null;
        return;
      }
      for (final task in _relationCandidates) {
        if (task.key == key) {
          _parent = _toRef(task);
          _children.removeWhere((child) => child.key == key);
          return;
        }
      }
    });
  }

  void _addChildKey(String? key) {
    if (key == null || key.isEmpty) return;
    if (_children.any((child) => child.key == key)) return;
    if (_parent?.key == key) return;
    for (final task in _relationCandidates) {
      if (task.key == key) {
        setState(() => _children = [..._children, _toRef(task)]);
        return;
      }
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      DdtToast.show(
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
      parent: _parent,
      children: _children,
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
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Button(text: 'Создать', onPressed: _submit),
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
            ),
            DdtTheme.verticalGap(),
            DdtMarkdownDescriptionInput(controller: _descriptionController),
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
                      placeholderWhenNull: true,
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
                      placeholderWhenNull: true,
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
                  _TaskFormTableRow(
                    label: 'Родитель',
                    child: _FormTableSearchableDropdown(
                      label: _relationPickSummary(_parent, emptyLabel: 'Нет'),
                      placeholder: _parent == null,
                      options: _parentPickOptions(
                        candidates: _relationCandidates,
                        children: _children,
                        parent: _parent,
                      ),
                      selected: {_parent?.key ?? _relationPickNoneKey},
                      onSelected: (key) => _setParentKey(
                        key.isEmpty ? null : key,
                      ),
                    ),
                  ),
                  _TaskFormTableRow(
                    label: 'Дочерние',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FormTableSearchableDropdown(
                          label: 'Добавить задачу',
                          placeholder: true,
                          options: _childPickOptions(
                            candidates: _relationCandidates,
                            children: _children,
                            parent: _parent,
                          ),
                          selected: const {},
                          emptyLabel: 'Нет доступных задач',
                          onSelected: _addChildKey,
                        ),
                        if (_children.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: [
                              for (final child in _children)
                                _TaskChildRelationChip(
                                  child: child,
                                  onRemove: () {
                                    setState(
                                      () => _children.removeWhere(
                                        (item) => item.key == child.key,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ],
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
                  icon: DdtIcons.add,
                  onPressed: _addLinkDraft,
                ),
              ],
            ),
            if (_links.isEmpty)
              Text(
                'Ссылки не добавлены',
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
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
                    fontSize: DdtTypography.labelSize,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.sidePanelTextPrimary(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Удалить ссылку',
                onPressed: onRemove,
                icon: DdtIcon(DdtIcons.trash, size: 14.sp),
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
          ),
          SizedBox(height: 8.h),
          DdtAppInput(
            label: 'Название',
            hint: 'Необязательно',
            controller: draft.titleController,
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
  static const double controlHeight = DdtTheme.compactInputControlHeight;

  static TextStyle textStyle(BuildContext context) => DdtTheme.style(
    fontSize: DdtTypography.bodySize,
    color: DdtTheme.sidePanelTextSecondary(context),
  );

  static TextStyle placeholderStyle(BuildContext context) => textStyle(
    context,
  ).copyWith(color: DdtTheme.inputHintStyle(context).color);

  static InputDecoration decoration(
    BuildContext context, {
    String? hintText,
    Widget? suffixIcon,
  }) {
    return DdtTheme.inputDecoration(
      context,
      hintText: hintText,
      suffixIcon: suffixIcon,
      compact: true,
    );
  }

  static Widget shell({
    required BuildContext context,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      height: controlHeight.h,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: DdtTheme.inputControlBorderRadius,
          child: InputDecorator(
            decoration: decoration(context),
            isEmpty: false,
            expands: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        ),
      ),
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
      fontSize: DdtTypography.labelSize,
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
  final FaIconData icon;
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
      icon: DdtIcon(icon, size: 14.sp),
      label: Text(
        label,
        style: DdtTheme.style(
          fontSize: DdtTypography.labelSmallSize,
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
    return SizedBox(
      height: _FormTableControl.controlHeight.h,
      child: DdtAppInput(
        hint: hint,
        controller: controller,
        variant: DdtInputVariant.compact,
        type: InputType.number,
        inputFormatters: inputFormatters,
        textColor: DdtTheme.sidePanelTextSecondary(context),
      ),
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
    final hasValue = value != null;
    return _FormTableControl.shell(
      context: context,
      onTap: () => _pick(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasValue ? formatTaskDateTime(value!) : 'Не указано',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hasValue
                  ? _FormTableControl.textStyle(context)
                  : _FormTableControl.placeholderStyle(context),
            ),
          ),
          if (nullable && hasValue)
            IconButton(
              tooltip: 'Очистить',
              onPressed: () => onChanged(null),
              icon: DdtIcon(
                DdtIcons.closeCircle,
                size: 18.sp,
                color: DdtTheme.sidePanelTextMuted(context),
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.h),
            ),
        ],
      ),
    );
  }
}

class _DropdownControl<T> extends StatelessWidget {
  const _DropdownControl({
    required this.value,
    required this.items,
    required this.onChanged,
    this.placeholderWhenNull = false,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool placeholderWhenNull;

  @override
  Widget build(BuildContext context) {
    // A DropdownButtonFormField keeps its own value once the user interacts
    // with it, which breaks controls whose selection is owned by the parent
    // (and asserts when the selected item leaves [items]).
    final isSelectable =
        items.where((item) => item.value == value).length == 1;
    final showPlaceholder = placeholderWhenNull && value == null;

    return _FormTableControl.shell(
      context: context,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: isSelectable ? value : null,
          isExpanded: true,
          isDense: true,
          borderRadius: DdtTheme.inputControlBorderRadius,
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? DdtTheme.darkSurface
              : DdtTheme.lightSurface,
          style: showPlaceholder
              ? _FormTableControl.placeholderStyle(context)
              : _FormTableControl.textStyle(context),
          icon: DdtIcon(
            DdtIcons.chevronDown,
            size: 16.sp,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _FormTableSearchableDropdown extends StatelessWidget {
  const _FormTableSearchableDropdown({
    required this.label,
    required this.placeholder,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.emptyLabel = 'Нет значений',
  });

  final String label;
  final bool placeholder;
  final List<DdtFilterOption> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (anchorContext) {
        return _FormTableControl.shell(
          context: context,
          onTap: () => showDdtSearchableFilterMenu(
            context: context,
            anchorContext: anchorContext,
            options: options,
            selected: selected,
            onSelected: onSelected,
            emptyLabel: emptyLabel,
            matchAnchorWidth: true,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: placeholder
                      ? _FormTableControl.placeholderStyle(context)
                      : _FormTableControl.textStyle(context),
                ),
              ),
              DdtIcon(
                DdtIcons.chevronDown,
                size: 16.sp,
                color: DdtTheme.sidePanelTextMuted(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskChildRelationChip extends StatelessWidget {
  const _TaskChildRelationChip({
    required this.child,
    required this.onRemove,
  });

  final TaskRef child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: DdtTheme.glassBorderColor(brightness).withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10.w, 5.h, 4.w, 5.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              child.key,
              style: DdtTheme.style(
                fontSize: DdtTypography.captionSize,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 168.w),
              child: Text(
                child.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.captionSize,
                  color: DdtTheme.sidePanelTextMuted(context),
                ),
              ),
            ),
            SizedBox(width: 2.w),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: DdtIcon(
                    DdtIcons.close,
                    size: 12.sp,
                    color: DdtTheme.sidePanelTextMuted(context),
                  ),
                ),
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
        fontSize: DdtTypography.bodySize,
        fontWeight: FontWeight.w700,
        color: DdtTheme.sidePanelTextPrimary(context),
      ),
    );
  }
}
