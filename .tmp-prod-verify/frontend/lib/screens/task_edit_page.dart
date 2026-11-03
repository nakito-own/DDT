part of 'task_create_page.dart';

/// Задача, открытая на редактирование из карточки: результат возвращается
/// вызывающему, и сохранение делает он же.
class _TaskEditRequest {
  const _TaskEditRequest(this.task);

  final Task task;
}

/// Полноэкранное редактирование задачи.
Future<Task?> openTaskEditPage(BuildContext context, Task task) {
  final taskKey = task.key.isNotEmpty
      ? task.key
      : (task.id > 0 ? task.id.toString() : '');
  if (taskKey.isEmpty) return Future.value();

  final taskSpace = task.spaceKey;
  final spaceKey = taskSpace != null && taskSpace.isNotEmpty
      ? taskSpace
      : context.read<TasksBloc>().spaceKey;

  return context.push<Task>(
    RoutePaths.forTaskEdit(
      taskKey: taskKey,
      spaceId: task.spaceId,
      spaceKey: spaceKey,
    ),
    extra: _TaskEditRequest(task),
  );
}

class TaskEditPage extends StatefulWidget {
  const TaskEditPage({
    super.key,
    required this.taskKey,
    this.spaceKey,
    this.task,
    this.relatedTasks,
  });

  final String taskKey;
  final String? spaceKey;

  /// Уже известная задача. Маршрут обычно передаёт её через [GoRouterState.extra].
  final Task? task;

  /// Доска для выбора связей. Если null, берётся список из [TasksBloc].
  final List<Task>? relatedTasks;

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _titleController = TextEditingController();
  final _descriptionController = DdtMarkdownLiveController();
  final _descriptionFocus = FocusNode();
  final List<_LinkDraft> _links = [];

  var _hydrated = false;
  var _returnToCaller = false;
  var _loading = true;
  String? _error;
  Task? _source;

  var _status = TaskStatus.todo;
  int? _typeId;
  TaskPriority? _priority;
  int? _authorId;
  int? _executorId;
  int? _responsibleId;
  DateTime _timeSet = DateTime.now();
  DateTime? _timeStart;
  DateTime? _timeEnd;
  DateTime? _deadline;
  TaskRef? _parent;
  List<TaskRef> _children = [];

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task == null) return;
    _returnToCaller = true;
    _apply(task);
    _loading = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    if (_source != null) return;

    final extra = _routeExtra();
    if (extra is _TaskEditRequest) {
      _returnToCaller = true;
      _apply(extra.task);
      _loading = false;
      return;
    }
    if (extra is Task) {
      _apply(extra);
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    for (final draft in _links) {
      draft.dispose();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Object? _routeExtra() {
    if (GoRouter.maybeOf(context) == null) return null;
    return GoRouterState.of(context).extra;
  }

  void _apply(Task task) {
    _source = task;
    _titleController.text = task.title;
    _descriptionController.text = task.description;
    _status = task.status;
    _typeId = task.typeId;
    _priority = task.priority;
    _authorId = task.authorId;
    _executorId = task.executorId;
    _responsibleId = task.responsibleId;
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

  Future<void> _load() async {
    try {
      final task = await TasksApi(
        spaceKey: widget.spaceKey,
      ).fetchTask(widget.taskKey);
      if (!mounted) return;
      setState(() {
        _apply(task);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int? get _sessionUserId {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.user.id : null;
  }

  List<Task> _relationCandidates(List<Task> tasks) {
    final sourceId = _source?.id;
    final seen = <String>{};
    final list = <Task>[
      for (final task in tasks)
        if (task.id != sourceId &&
            task.id > 0 &&
            task.key.isNotEmpty &&
            seen.add(task.key))
          task,
    ];
    final parent = _parent;
    if (parent != null && parent.key.isNotEmpty && seen.add(parent.key)) {
      list.add(
        Task(
          id: parent.id,
          key: parent.key,
          title: parent.title,
          status: parent.status,
          timeSet: _timeSet,
        ),
      );
    }
    return list;
  }

  TaskRef _toRef(Task task) {
    return TaskRef(
      id: task.id,
      key: task.key,
      title: task.title,
      status: task.status,
    );
  }

  void _setStatus(TaskStatus next) {
    setState(() {
      final dates = statusTransitionDates(
        from: _status,
        to: next,
        timeStart: _timeStart,
        timeEnd: _timeEnd,
      );
      _status = next;
      _timeStart = dates.timeStart;
      _timeEnd = dates.timeEnd;
    });
  }

  void _setParentKey(String key, List<Task> candidates) {
    setState(() {
      if (key.isEmpty) {
        _parent = null;
        return;
      }
      for (final task in candidates) {
        if (task.key != key) continue;
        _parent = _toRef(task);
        _children = [
          for (final child in _children)
            if (child.key != key) child,
        ];
        return;
      }
    });
  }

  void _toggleChildKey(String key, List<Task> candidates) {
    setState(() {
      if (_children.any((child) => child.key == key)) {
        _children = [
          for (final child in _children)
            if (child.key != key) child,
        ];
        return;
      }
      if (_parent?.key == key) return;
      for (final task in candidates) {
        if (task.key == key) {
          _children = [..._children, _toRef(task)];
          return;
        }
      }
    });
  }

  void _addLink() {
    setState(() => _links.add(_LinkDraft()));
  }

  void _removeLink(_LinkDraft draft) {
    setState(() {
      draft.dispose();
      _links.remove(draft);
    });
  }

  void _close([Task? result]) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(result);
      return;
    }
    final spaceKey = widget.spaceKey ?? context.read<TasksBloc>().spaceKey;
    context.go(
      spaceKey == null || spaceKey.isEmpty
          ? RoutePaths.tasksList
          : RoutePaths.spaceListFor(spaceKey),
    );
  }

  Task? _buildUpdated({required bool personal}) {
    final source = _source;
    if (source == null) return null;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      DdtToast.show(
        message: 'Введите название задачи',
        type: ToastType.warning,
      );
      return null;
    }

    final types = context.read<TasksBloc>().state.taskTypes;
    TaskType? type;
    for (final item in types) {
      if (item.id == _typeId) {
        type = item;
        break;
      }
    }

    int? assigned(int? selected) => personal ? _sessionUserId : selected;

    final drafts = _links
        .where((item) => item.urlController.text.trim().isNotEmpty)
        .toList();
    final links = drafts.isEmpty
        ? (source.links == null ? null : <TaskLink>[])
        : [
            for (var i = 0; i < drafts.length; i++)
              TaskLink(
                id: i + 1,
                url: drafts[i].urlController.text.trim(),
                title: drafts[i].titleController.text.trim().isEmpty
                    ? null
                    : drafts[i].titleController.text.trim(),
              ),
          ];

    return Task(
      id: source.id,
      key: source.key,
      title: title,
      status: _status,
      typeId: _typeId,
      type: type,
      description: _descriptionController.text.trim(),
      authorId: assigned(_authorId),
      executorId: assigned(_executorId),
      responsibleId: assigned(_responsibleId),
      ownerId: source.ownerId,
      spaceId: source.spaceId,
      spaceKey: source.spaceKey,
      parentId: _parent?.id,
      parent: _parent,
      children: _children,
      timeSet: _timeSet,
      timeStart: _timeStart,
      timeEnd: _timeEnd,
      deadline: _deadline,
      priority: _priority,
      deleted: source.deleted,
      archive: source.archive,
      links: links,
      comments: source.comments,
      createdAt: source.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  void _submit({required bool personal}) {
    final source = _source;
    final updated = _buildUpdated(personal: personal);
    if (source == null || updated == null) return;

    if (!_returnToCaller) {
      context.read<TasksBloc>().add(
        TaskUpdateRequested(original: source, updated: updated),
      );
    }
    _close(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _source == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Задача не найдена', textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            Button(
              text: 'Повторить',
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              borderRadius: DdtTheme.radius,
            ),
          ],
        ),
      );
    }

    final personal = context.read<TasksBloc>().spaceKey == null;
    final state = context.watch<TasksBloc>().state;
    final candidates = _relationCandidates(widget.relatedTasks ?? state.allTasks);
    final source = _source!;
    final toolbarLabel = source.key.isNotEmpty ? source.key : 'ЗАДАЧА';

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final parameters = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ParametersColumn(
              personal: personal,
              taskTypes: state.taskTypes,
              candidates: candidates,
              status: _status,
              typeId: _typeId,
              priority: _priority,
              authorId: _authorId,
              executorId: _executorId,
              responsibleId: _responsibleId,
              timeSet: _timeSet,
              timeStart: _timeStart,
              timeEnd: _timeEnd,
              deadline: _deadline,
              parent: _parent,
              children: _children,
              onStatus: _setStatus,
              onType: (id) => setState(() => _typeId = id),
              onPriority: (value) => setState(() => _priority = value),
              onAuthor: (id) => setState(() => _authorId = id),
              onExecutor: (id) => setState(() => _executorId = id),
              onResponsible: (id) => setState(() => _responsibleId = id),
              onTimeSet: (value) => setState(() => _timeSet = value),
              onTimeStart: (value) => setState(() => _timeStart = value),
              onTimeEnd: (value) => setState(() => _timeEnd = value),
              onDeadline: (value) => setState(() => _deadline = value),
              onParent: (key) => _setParentKey(key, candidates),
              onToggleChild: (key) => _toggleChildKey(key, candidates),
            ),
            _LinksEditor(
              links: _links,
              onAdd: _addLink,
              onRemove: _removeLink,
            ),
          ],
        );
        final main = _CreateMainPane(
          titleController: _titleController,
          descriptionController: _descriptionController,
          descriptionFocus: _descriptionFocus,
          onClose: () => _close(),
          onSubmit: () => _submit(personal: personal),
          toolbarLabel: toolbarLabel,
          backLabel: 'Назад к задаче',
          submitLabel: 'Сохранить',
          autofocusTitle: false,
          trailing: wide ? null : parameters,
        );

        if (!wide) return main;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: main),
            const DdtSidePanelDivider(),
            SizedBox(width: 320.w, child: _CreateScroll(child: parameters)),
          ],
        );
      },
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

class _LinksEditor extends StatelessWidget {
  const _LinksEditor({
    required this.links,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_LinkDraft> links;
  final VoidCallback onAdd;
  final ValueChanged<_LinkDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ссылки',
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
                  fontWeight: FontWeight.w600,
                  color: DdtTheme.sidePanelTextMuted(context),
                ),
              ),
            ),
            TextButton(onPressed: onAdd, child: const Text('Добавить')),
          ],
        ),
        if (links.isEmpty)
          Text(
            'Ссылки не добавлены',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              color: DdtTheme.sidePanelTextMuted(context),
            ),
          )
        else
          for (final draft in links) ...[
            SizedBox(height: 8.h),
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => onRemove(draft),
                child: const Text('Удалить'),
              ),
            ),
          ],
      ],
    );
  }
}
