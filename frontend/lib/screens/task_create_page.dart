import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_ref.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import '../models/user_profile.dart';
import '../router/route_paths.dart';
import '../services/directory_users.dart';
import '../theme/ddt_icons.dart';
import '../theme/ddt_scroll_behavior.dart';
import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';
import '../utils/ddt_date_time_picker.dart';
import '../utils/ddt_toast.dart';
import '../utils/task_formatters.dart';
import '../utils/task_status_dates.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_markdown_description_input.dart';
import '../widgets/ddt_markdown_live_controller.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_side_panel_divider.dart';
import '../widgets/ddt_user_chip.dart';

/// Полноэкранное создание задачи вместо боковой панели.
void openTaskCreatePage(
  BuildContext context, {
  TaskStatus status = TaskStatus.todo,
}) {
  final spaceKey = context.read<TasksBloc>().spaceKey;
  final path = spaceKey == null || spaceKey.isEmpty
      ? RoutePaths.tasksNew
      : RoutePaths.spaceTaskNew(spaceKey);
  final query = status == TaskStatus.todo ? '' : '?status=${status.value}';
  context.push('$path$query');
}

class TaskCreatePage extends StatefulWidget {
  const TaskCreatePage({super.key});

  @override
  State<TaskCreatePage> createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends State<TaskCreatePage> {
  final _titleController = TextEditingController();
  final _descriptionController = DdtMarkdownLiveController();
  final _descriptionFocus = FocusNode();

  var _hydrated = false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;

    final requested = TaskStatus.fromValue(
      GoRouterState.of(context).uri.queryParameters['status'] ??
          TaskStatus.todo.value,
    );
    final dates = statusTransitionDates(
      from: TaskStatus.todo,
      to: requested,
      timeStart: null,
      timeEnd: null,
    );
    _status = requested;
    _timeStart = dates.timeStart;
    _timeEnd = dates.timeEnd;

    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      _authorId = auth.user.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  int? get _sessionUserId {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.user.id : null;
  }

  List<Task> _relationCandidates(List<Task> tasks) {
    final seen = <String>{};
    return [
      for (final task in tasks)
        if (task.id > 0 && task.key.isNotEmpty && seen.add(task.key)) task,
    ];
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

  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final spaceKey = context.read<TasksBloc>().spaceKey;
    context.go(
      spaceKey == null || spaceKey.isEmpty
          ? RoutePaths.tasksList
          : RoutePaths.spaceListFor(spaceKey),
    );
  }

  void _submit({required bool personal}) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      DdtToast.show(
        message: 'Введите название задачи',
        type: ToastType.warning,
      );
      return;
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

    final now = DateTime.now();
    final draft = Task(
      id: 0,
      title: title,
      status: _status,
      typeId: type?.id,
      type: type,
      description: _descriptionController.text.trim(),
      authorId: assigned(_authorId),
      executorId: assigned(_executorId),
      responsibleId: assigned(_responsibleId),
      timeSet: _timeSet,
      timeStart:
          _timeStart ?? (_status == TaskStatus.inProgress ? now : null),
      timeEnd: _timeEnd ?? (_status == TaskStatus.done ? now : null),
      deadline: _deadline,
      priority: _priority,
      parent: _parent,
      parentId: _parent?.id,
      children: _children,
    );

    context.read<TasksBloc>().add(TaskCreateRequested(draft));
    DdtToast.show(message: 'Задача создаётся...', type: ToastType.info);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final personal = context.read<TasksBloc>().spaceKey == null;
    final state = context.watch<TasksBloc>().state;
    final candidates = _relationCandidates(state.allTasks);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final main = _CreateMainPane(
          titleController: _titleController,
          descriptionController: _descriptionController,
          descriptionFocus: _descriptionFocus,
          onClose: _close,
          onSubmit: () => _submit(personal: personal),
        );
        final parameters = _ParametersColumn(
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
        );

        if (!wide) {
          return _CreateMainPane(
            titleController: _titleController,
            descriptionController: _descriptionController,
            descriptionFocus: _descriptionFocus,
            onClose: _close,
            onSubmit: () => _submit(personal: personal),
            trailing: parameters,
          );
        }

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

/// Title field lives in the header stack and hangs past the gradient.
/// Description is plain text in the body, with no field chrome.
class _CreateMainPane extends StatefulWidget {
  const _CreateMainPane({
    required this.titleController,
    required this.descriptionController,
    required this.descriptionFocus,
    required this.onClose,
    required this.onSubmit,
    this.trailing,
  });

  final TextEditingController titleController;
  final DdtMarkdownLiveController descriptionController;
  final FocusNode descriptionFocus;
  final VoidCallback onClose;
  final VoidCallback onSubmit;
  final Widget? trailing;

  @override
  State<_CreateMainPane> createState() => _CreateMainPaneState();
}

class _CreateMainPaneState extends State<_CreateMainPane> {
  final _scroll = ScrollController();
  double _chromeHeight = 148;

  static const double _titlePastGradient = 12;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBy(double dy) {
    if (dy == 0 || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final next = (position.pixels + dy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) position.jumpTo(next.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final topInset = DdtShellMetrics.maybeOf(context)?.contentInsetTop ?? 0;
    final bottom = DdtShellMetrics.maybeOf(context)?.contentInsetBottom ?? 24.h;
    final titleStyle = DdtTheme.style(
      fontSize: DdtTypography.entityTitleSize,
      fontWeight: FontWeight.w700,
      color: DdtTheme.textPrimary(context),
    );

    return Stack(
      children: [
        ScrollConfiguration(
          behavior: const DdtScrollBehavior(),
          child: ListView(
            controller: _scroll,
            primary: false,
            padding: EdgeInsets.fromLTRB(20.w, _chromeHeight, 20.w, bottom),
            children: [
              DdtMarkdownDescriptionInput(
                controller: widget.descriptionController,
                focusNode: widget.descriptionFocus,
                label: null,
                hint: 'Описание',
                minLines: 6,
                plain: true,
              ),
              if (widget.trailing != null) ...[
                SizedBox(height: 24.h),
                widget.trailing!,
              ],
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ChromeHeightReporter(
            watch: widget.titleController,
            onHeight: (height) {
              if (!mounted || (height - _chromeHeight).abs() < 0.5) return;
              setState(() => _chromeHeight = height);
            },
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _scrollBy(event.scrollDelta.dy);
                }
              },
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: _titlePastGradient.h,
                    child: const IgnorePointer(child: _CreateHeaderFade()),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, topInset + 12.h, 20.w, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CreateToolbar(
                          label: 'НОВАЯ ЗАДАЧА',
                          backLabel: 'Назад к задачам',
                          onClose: widget.onClose,
                          onSubmit: widget.onSubmit,
                        ),
                        SizedBox(height: 8.h),
                        _SkeletonTextField(
                          controller: widget.titleController,
                          hint: 'Название',
                          autofocus: true,
                          style: titleStyle,
                          onSubmitted: (_) =>
                              widget.descriptionFocus.requestFocus(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateHeaderFade extends StatelessWidget {
  const _CreateHeaderFade();

  @override
  Widget build(BuildContext context) {
    final color = DdtTheme.scaffoldBackground(context);
    final solid = color.withValues(alpha: 1);
    final clear = color.withValues(alpha: 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        const tail = 28.0;
        final solidStop = height <= 0
            ? 0.7
            : ((height - tail) / height).clamp(0.0, 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [solid, solid, clear],
              stops: [0, solidStop, 1],
            ),
          ),
        );
      },
    );
  }
}

class _ChromeHeightReporter extends StatefulWidget {
  const _ChromeHeightReporter({
    required this.onHeight,
    required this.child,
    this.watch,
  });

  final ValueChanged<double> onHeight;
  final Widget child;
  final Listenable? watch;

  @override
  State<_ChromeHeightReporter> createState() => _ChromeHeightReporterState();
}

class _ChromeHeightReporterState extends State<_ChromeHeightReporter> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.watch?.addListener(_report);
    _report();
  }

  @override
  void didUpdateWidget(covariant _ChromeHeightReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watch != widget.watch) {
      oldWidget.watch?.removeListener(_report);
      widget.watch?.addListener(_report);
    }
    _report();
  }

  @override
  void dispose() {
    widget.watch?.removeListener(_report);
    super.dispose();
  }

  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      widget.onHeight(box.size.height);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class _ParametersColumn extends StatelessWidget {
  const _ParametersColumn({
    required this.personal,
    required this.taskTypes,
    required this.candidates,
    required this.status,
    required this.typeId,
    required this.priority,
    required this.authorId,
    required this.executorId,
    required this.responsibleId,
    required this.timeSet,
    required this.timeStart,
    required this.timeEnd,
    required this.deadline,
    required this.parent,
    required this.children,
    required this.onStatus,
    required this.onType,
    required this.onPriority,
    required this.onAuthor,
    required this.onExecutor,
    required this.onResponsible,
    required this.onTimeSet,
    required this.onTimeStart,
    required this.onTimeEnd,
    required this.onDeadline,
    required this.onParent,
    required this.onToggleChild,
  });

  final bool personal;
  final List<TaskType> taskTypes;
  final List<Task> candidates;
  final TaskStatus status;
  final int? typeId;
  final TaskPriority? priority;
  final int? authorId;
  final int? executorId;
  final int? responsibleId;
  final DateTime timeSet;
  final DateTime? timeStart;
  final DateTime? timeEnd;
  final DateTime? deadline;
  final TaskRef? parent;
  final List<TaskRef> children;
  final ValueChanged<TaskStatus> onStatus;
  final ValueChanged<int?> onType;
  final ValueChanged<TaskPriority?> onPriority;
  final ValueChanged<int?> onAuthor;
  final ValueChanged<int?> onExecutor;
  final ValueChanged<int?> onResponsible;
  final ValueChanged<DateTime> onTimeSet;
  final ValueChanged<DateTime?> onTimeStart;
  final ValueChanged<DateTime?> onTimeEnd;
  final ValueChanged<DateTime?> onDeadline;
  final ValueChanged<String> onParent;
  final ValueChanged<String> onToggleChild;

  @override
  Widget build(BuildContext context) {
    final parentSummary = parent == null
        ? 'Нет'
        : '${parent!.key} · ${parent!.title}';
    final childSummary = children.isEmpty
        ? 'Нет'
        : children.length == 1
        ? '${children.first.key} · ${children.first.title}'
        : 'Выбрано: ${children.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Параметры',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
        SizedBox(height: 12.h),
        _DropdownRow(
          label: 'Статус',
          summary: status.label,
          active: true,
          selected: {status.value},
          options: [
            for (final item in TaskStatus.values)
              DdtFilterOption(key: item.value, label: item.label),
          ],
          onSelected: (key) => onStatus(TaskStatus.fromValue(key)),
        ),
        _DropdownRow(
          label: 'Тип',
          summary: _typeName(taskTypes, typeId) ?? 'Не указан',
          active: typeId != null,
          selected: {typeId?.toString() ?? ''},
          options: [
            const DdtFilterOption(key: '', label: 'Не указан'),
            for (final type in taskTypes)
              DdtFilterOption(key: '${type.id}', label: type.name),
          ],
          onSelected: (key) => onType(key.isEmpty ? null : int.tryParse(key)),
        ),
        _DropdownRow(
          label: 'Приоритет',
          summary: priority?.label ?? 'Не указан',
          active: priority != null,
          selected: {priority?.value ?? ''},
          options: [
            const DdtFilterOption(key: '', label: 'Не указан'),
            for (final item in TaskPriority.values)
              DdtFilterOption(key: item.value, label: item.label),
          ],
          onSelected: (key) => onPriority(
            key.isEmpty ? null : TaskPriority.fromValue(key),
          ),
        ),
        if (!personal) ...[
          _PersonDropdownRow(
            label: 'Автор',
            userId: authorId,
            onChanged: onAuthor,
          ),
          _PersonDropdownRow(
            label: 'Исполнитель',
            userId: executorId,
            onChanged: onExecutor,
          ),
          _PersonDropdownRow(
            label: 'Ответственный',
            userId: responsibleId,
            onChanged: onResponsible,
          ),
        ],
        _DateDropdownRow(
          label: 'Создана',
          value: timeSet,
          onChanged: (value) {
            if (value != null) onTimeSet(value);
          },
        ),
        _DateDropdownRow(
          label: 'Начало',
          value: timeStart,
          nullable: true,
          onChanged: onTimeStart,
        ),
        _DateDropdownRow(
          label: 'Окончание',
          value: timeEnd,
          nullable: true,
          onChanged: onTimeEnd,
        ),
        _DropdownRow(
          label: 'Родитель',
          summary: parentSummary,
          active: parent != null,
          selected: {parent?.key ?? ''},
          options: [
            const DdtFilterOption(key: '', label: 'Нет'),
            for (final task in candidates)
              if (!children.any((child) => child.key == task.key))
                DdtFilterOption(
                  key: task.key,
                  label: '${task.key} · ${task.title}',
                ),
          ],
          onSelected: onParent,
        ),
        _DropdownRow(
          label: 'Дочерние',
          summary: childSummary,
          active: children.isNotEmpty,
          multi: true,
          alignTop: children.isNotEmpty,
          selected: {for (final child in children) child.key},
          options: [
            for (final task in candidates)
              if (task.key != parent?.key)
                DdtFilterOption(
                  key: task.key,
                  label: '${task.key} · ${task.title}',
                ),
          ],
          emptyLabel: 'Нет доступных задач',
          onSelected: onToggleChild,
          trailing: children.isEmpty
              ? null
              : Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      for (final child in children)
                        _ChildChip(
                          label: child.key,
                          onRemove: () => onToggleChild(child.key),
                        ),
                    ],
                  ),
                ),
        ),
        _DateDropdownRow(
          label: 'Дедлайн',
          value: deadline,
          nullable: true,
          onChanged: onDeadline,
        ),
      ],
    );
  }
}

String? _typeName(List<TaskType> types, int? id) {
  if (id == null) return null;
  for (final type in types) {
    if (type.id == id) return type.name;
  }
  return null;
}

class _CreateToolbar extends StatelessWidget {
  const _CreateToolbar({
    required this.label,
    required this.backLabel,
    required this.onClose,
    required this.onSubmit,
  });

  final String label;
  final String backLabel;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MarkButton(
          icon: DdtIcons.chevronLeft,
          label: backLabel,
          onPressed: onClose,
          alignStart: true,
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
              color: DdtTheme.sidePanelTextMuted(context).withValues(alpha: 0.55),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Button(
          text: 'Создать',
          onPressed: onSubmit,
          borderRadius: DdtTheme.radius,
        ),
      ],
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.alignStart = false,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Drops the left inset so the glyph lines up with the title and the body.
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.fromLTRB(alignStart ? 0 : 4.w, 4.h, 4.w, 4.h),
            child: DdtIcon(
              icon,
              size: 14 / DdtIcon.visualScale,
              color: DdtTheme.sidePanelTextSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonTextField extends StatelessWidget {
  const _SkeletonTextField({
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

    final transparent = const InputDecorationTheme(
      filled: false,
      isCollapsed: true,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: 0, minHeight: 0),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        inputDecorationTheme: transparent,
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: 1,
        maxLines: 4,
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
          fillColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          hintText: hint,
          hintStyle: style.copyWith(color: DdtTheme.textMuted(context)),
        ),
      ),
    );
  }
}

class _CreateScroll extends StatelessWidget {
  const _CreateScroll({required this.child});

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

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.summary,
    required this.active,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.multi = false,
    this.emptyLabel = 'Нет значений',
    this.trailing,
    this.alignTop = false,
  });

  final String label;
  final String summary;
  final bool active;
  final List<DdtFilterOption> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final bool multi;
  final String emptyLabel;
  final Widget? trailing;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: alignTop
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 108.w,
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 8.h : 0),
              child: Text(label, style: _paramLabelStyle(context)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DdtSearchableFilterDropdown(
                  summary: summary,
                  active: active,
                  options: options,
                  selected: selected,
                  onSelected: onSelected,
                  multi: multi,
                  emptyLabel: emptyLabel,
                ),
                ?trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateDropdownRow extends StatelessWidget {
  const _DateDropdownRow({
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
    final picked = await showDdtDateTimePicker(
      context: context,
      initialDateTime: value ?? DateTime.now(),
    );
    if (picked == null) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          SizedBox(
            width: 108.w,
            child: Text(label, style: _paramLabelStyle(context)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: DdtFilterDropdownAnchor(
              label: hasValue
                  ? formatTaskDateTime(value!.toLocal())
                  : 'Не указано',
              active: hasValue,
              onTap: () => _pick(context),
            ),
          ),
          if (nullable && hasValue) ...[
            SizedBox(width: 4.w),
            _MarkButton(
              icon: DdtIcons.closeCircle,
              label: 'Очистить',
              onPressed: () => onChanged(null),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonDropdownRow extends StatelessWidget {
  const _PersonDropdownRow({
    required this.label,
    required this.userId,
    required this.onChanged,
  });

  final String label;
  final int? userId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: loadDirectoryUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <UserProfile>[];
        final selected = directoryUserById(users, userId);
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            users.isEmpty;
        final name = selected?.label ?? (loading ? 'Загрузка…' : 'Не указан');

        return _DropdownRow(
          label: label,
          summary: userId == null ? 'Не указан' : name,
          active: userId != null,
          selected: {userId?.toString() ?? ''},
          emptyLabel: loading ? 'Загрузка…' : 'Нет пользователей',
          options: [
            const DdtFilterOption(key: '', label: 'Не указан'),
            for (final user in users)
              DdtFilterOption(
                key: '${user.id}',
                label: user.label,
                searchText: '${user.label} ${user.email}',
                content: (context) =>
                    DdtUserChip(name: user.label, userId: user.id),
              ),
          ],
          onSelected: (key) =>
              onChanged(key.isEmpty ? null : int.tryParse(key)),
        );
      },
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DdtTheme.badgeBorderRadius,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.72),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.11)
              : DdtTheme.borderSubtle(context),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.w, 3.h, 4.w, 3.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4.w),
            _MarkButton(
              icon: DdtIcons.closeCircle,
              label: 'Убрать $label',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _paramLabelStyle(BuildContext context) {
  return DdtTheme.style(
    fontSize: DdtTypography.labelSmallSize,
    fontWeight: FontWeight.w600,
    color: DdtTheme.sidePanelTextMuted(context),
  );
}
