import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import '../utils/ddt_toast.dart';
import '../widgets/task_card.dart';
import '../widgets/task_side_panel.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';

const _kKanbanSlotDuration = Duration(milliseconds: 280);
const _kKanbanSlotCurve = Curves.easeOutCubic;

class KanbanBoardPage extends StatefulWidget {
  const KanbanBoardPage({super.key});

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  // Локальная мутируемая копия колонок для drag-drop анимаций.
  // BlocListener синхронизирует её с TasksBloc.state.columns.
  late Map<TaskStatus, List<Task>> _localColumns;
  late List<TaskType> _taskTypes;

  final Map<String, GlobalKey> _taskCardKeys = {};
  final Map<int, Size> _taskCardSizes = {};
  final Map<TaskStatus, GlobalKey<_KanbanTaskListState>> _taskListKeys = {
    for (final status in TaskStatus.values) status: GlobalKey(),
  };
  int? _draggingTaskId;
  TaskStatus? _draggingFromStatus;
  int? _draggingFromIndex;
  TaskStatus? _dropStatus;
  int? _dropIndex;
  _PendingTaskDrop? _pendingDrop;

  @override
  void initState() {
    super.initState();
    final state = context.read<TasksBloc>().state;
    _localColumns = {
      for (final e in state.columns.entries) e.key: List.of(e.value),
    };
    _taskTypes = List.of(state.taskTypes);
  }

  void _syncFromBlocState(TasksState state) {
    _localColumns = {
      for (final e in state.columns.entries) e.key: List.of(e.value),
    };
    _taskTypes = List.of(state.taskTypes);
  }

  List<Task> _columnTasks(TaskStatus status) =>
      _localColumns[status] ?? const [];

  GlobalKey _taskCardKey(TaskStatus status, int taskId) =>
      _taskCardKeys.putIfAbsent('${status.name}_$taskId', () => GlobalKey());

  void _registerTaskCardSize(int taskId, Size size) {
    _taskCardSizes[taskId] = size;
  }

  Task _updatedTaskForColumn(Task task, TaskStatus to) {
    var updated = task.copyWith(status: to);
    if (to == TaskStatus.inProgress && updated.timeStart == null) {
      updated = updated.copyWith(timeStart: DateTime.now());
    }
    if (to == TaskStatus.done && updated.timeEnd == null) {
      updated = updated.copyWith(timeEnd: DateTime.now());
    }
    return updated;
  }

  void _applyMove(Task task, TaskStatus from, TaskStatus to, int toIndex) {
    final fromColumn = _localColumns[from];
    final toColumn = _localColumns[to];
    if (fromColumn == null || toColumn == null) return;

    fromColumn.removeWhere((item) => item.id == task.id);
    if (!identical(fromColumn, toColumn)) {
      toColumn.removeWhere((item) => item.id == task.id);
    }
    final index = toIndex.clamp(0, toColumn.length);
    toColumn.insert(index, _updatedTaskForColumn(task, to));
  }

  void _registerTaskDrop(Task task, TaskStatus to, int toIndex) {
    _pendingDrop = _PendingTaskDrop(task: task, to: to, toIndex: toIndex);
  }

  void _onTaskDragStarted(TaskStatus status, int taskId) {
    final column = _columnTasks(status);
    final index = column.indexWhere((item) => item.id == taskId);

    setState(() {
      _draggingTaskId = taskId;
      _draggingFromStatus = status;
      _draggingFromIndex = index < 0 ? column.length : index;
      _dropStatus = status;
      _dropIndex = index < 0 ? column.length : index;
    });
  }

  void _setDropPreview(TaskStatus status, int index) {
    if (_dropStatus == status && _dropIndex == index) return;
    setState(() {
      _dropStatus = status;
      _dropIndex = index;
    });
  }

  void _clearDragPreview() {
    _draggingTaskId = null;
    _draggingFromStatus = null;
    _draggingFromIndex = null;
    _dropStatus = null;
    _dropIndex = null;
  }

  int _insertIndexFor(TaskStatus status, Offset globalPosition) {
    final tasks = _columnTasks(
      status,
    ).where((task) => task.id != _draggingTaskId).toList();
    if (tasks.isEmpty) return 0;

    for (var i = 0; i < tasks.length; i++) {
      final cardContext = _taskCardKey(status, tasks[i].id).currentContext;
      if (cardContext == null || !cardContext.mounted) continue;
      final box = cardContext.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (globalPosition.dy < top + box.size.height / 2) {
        return i;
      }
    }
    return tasks.length;
  }

  void _showMoveToast(Task task, TaskStatus to) {
    DdtToast.show(
      message: '«${task.title}» → ${to.label}',
      type: ToastType.info,
      title: 'Задача перемещена',
    );
  }

  Future<void> _finishTaskDrag(Task task, DraggableDetails details) async {
    final pending = _pendingDrop;
    _pendingDrop = null;

    final from = _draggingFromStatus ?? task.status;
    final fromIndex = _draggingFromIndex;
    final accepted = details.wasAccepted || pending != null;
    final to = pending?.to ?? (accepted ? _dropStatus : null);
    final toIndex = pending?.toIndex ?? (accepted ? _dropIndex : null);

    try {
      if (to == null || toIndex == null) {
        setState(() {
          _syncFromBlocState(context.read<TasksBloc>().state);
          _clearDragPreview();
        });
        return;
      }

      final unchanged = from == to && (fromIndex == null || fromIndex == toIndex);
      if (unchanged) {
        setState(() {
          _syncFromBlocState(context.read<TasksBloc>().state);
          _clearDragPreview();
        });
        return;
      }

      setState(() {
        _applyMove(task, from, to, toIndex);
        _clearDragPreview();
      });

      context.read<TasksBloc>().add(
        TaskMoveRequested(task: task, from: from, to: to, toIndex: toIndex),
      );
      if (from != to) {
        _showMoveToast(task, to);
      }
    } finally {
      if (mounted && _draggingTaskId != null) {
        setState(_clearDragPreview);
      }
    }
  }

  Future<void> _addTask(TaskStatus status) async {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : null;
    final created = await showTaskSidePanel(
      context,
      mode: TaskSidePanelMode.create,
      initialStatus: status,
      taskTypes: _taskTypes,
      defaultAuthorId: currentUserId,
    );

    if (created == null || !mounted) return;

    final now = DateTime.now();
    final draft = Task(
      id: 0,
      title: created.title,
      status: created.status,
      typeId: created.typeId,
      type: created.type,
      description: created.description,
      authorId: currentUserId ?? created.authorId,
      executorId: created.executorId,
      responsibleId: created.responsibleId,
      timeSet: created.timeSet,
      timeStart:
          created.timeStart ??
          (created.status == TaskStatus.inProgress ? now : null),
      timeEnd:
          created.timeEnd ?? (created.status == TaskStatus.done ? now : null),
      deadline: created.deadline,
      priority: created.priority,
      links: created.links,
      comments: created.comments,
    );

    context.read<TasksBloc>().add(TaskCreateRequested(draft));
    // BlocListener синхронизирует _localColumns после ответа сервера.
    DdtToast.show(message: 'Задача создаётся...', type: ToastType.info);
  }

  Future<void> _deleteTask(Task task, TaskStatus status) async {
    final column = _columnTasks(status);
    final index = column.indexWhere((item) => item.id == task.id);
    if (index < 0) return;

    // Оптимистично убираем из локальных колонок для быстрой реакции.
    setState(() {
      _localColumns[status]?.removeAt(index);
    });

    context.read<TasksBloc>().add(
      TaskDeleteRequested(task: task, status: status),
    );
    // BlocListener синхронизирует при успехе или откатит при ошибке.
    DdtToast.show(message: '«${task.title}» удалена', type: ToastType.success);
  }

  Future<void> _openTaskDetails(Task task) async {
    final updated = await showTaskSidePanel(
      context,
      mode: TaskSidePanelMode.view,
      task: task,
      taskTypes: _taskTypes,
    );

    if (updated == null || !mounted) return;

    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: task, updated: updated),
    );
  }

  Widget _kanbanColumn(TaskStatus status) {
    return _KanbanColumn(
      key: ValueKey(status),
      status: status,
      tasks: _columnTasks(status),
      taskListKey: _taskListKeys[status]!,
      draggingTaskId: _draggingTaskId,
      dropIndex: _dropStatus == status ? _dropIndex : null,
      placeholderHeight: _draggingTaskId == null
          ? 0
          : (_taskCardSizes[_draggingTaskId]?.height ?? 96),
      taskCardKey: _taskCardKey,
      onRegisterCardSize: _registerTaskCardSize,
      onRegisterDrop: _registerTaskDrop,
      onDropPreview: _setDropPreview,
      onResolveInsertIndex: _insertIndexFor,
      onDragStarted: _onTaskDragStarted,
      onDragEnd: _finishTaskDrag,
      onAddTask: _addTask,
      onDeleteTask: _deleteTask,
      onOpenTask: _openTaskDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TasksBloc, TasksState>(
      listenWhen: (previous, current) =>
          previous.columns != current.columns ||
          previous.taskTypes != current.taskTypes,
      listener: (context, state) {
        if (_draggingTaskId != null) return;
        setState(() => _syncFromBlocState(state));
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var index = 0;
                  index < TaskStatus.values.length;
                  index++
                ) ...[
                  if (index > 0) DdtTheme.horizontalGap(),
                  Expanded(child: _kanbanColumn(TaskStatus.values[index])),
                ],
              ],
            );
          }

          return SizedBox(
            height: constraints.maxHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: TaskStatus.values.length,
              separatorBuilder: (context, index) => DdtTheme.horizontalGap(),
              itemBuilder: (context, index) {
                final status = TaskStatus.values[index];

                return SizedBox(
                  width: 320.w,
                  child: _kanbanColumn(status),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    super.key,
    required this.status,
    required this.tasks,
    required this.taskListKey,
    required this.draggingTaskId,
    required this.dropIndex,
    required this.placeholderHeight,
    required this.taskCardKey,
    required this.onRegisterCardSize,
    required this.onRegisterDrop,
    required this.onDropPreview,
    required this.onResolveInsertIndex,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onAddTask,
    required this.onDeleteTask,
    required this.onOpenTask,
  });

  final TaskStatus status;
  final List<Task> tasks;
  final GlobalKey<_KanbanTaskListState> taskListKey;
  final int? draggingTaskId;
  final int? dropIndex;
  final double placeholderHeight;
  final GlobalKey Function(TaskStatus status, int taskId) taskCardKey;
  final void Function(int taskId, Size size) onRegisterCardSize;
  final void Function(Task task, TaskStatus to, int toIndex) onRegisterDrop;
  final void Function(TaskStatus status, int index) onDropPreview;
  final int Function(TaskStatus status, Offset globalPosition)
  onResolveInsertIndex;
  final void Function(TaskStatus status, int taskId) onDragStarted;
  final Future<void> Function(Task task, DraggableDetails details) onDragEnd;
  final void Function(TaskStatus status) onAddTask;
  final Future<void> Function(Task task, TaskStatus status) onDeleteTask;
  final void Function(Task task) onOpenTask;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  late final Color _statusColor = statusColumnColor(widget.status);
  late final Color _columnColor = _statusColor.withValues(
    alpha: widget.status == TaskStatus.inProgress ? 0.12 : 0.08,
  );

  final _dragOver = ValueNotifier(false);

  @override
  void dispose() {
    _dragOver.dispose();
    super.dispose();
  }

  void _setDragOver(bool value) {
    if (_dragOver.value != value) {
      _dragOver.value = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppCard(
            type: CardType.outlined,
            borderRadius: DdtTheme.radius,
            padding: EdgeInsets.all(DdtTheme.spacing.w),
            backgroundColor: _columnColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KanbanColumnHeader(
                  status: widget.status,
                  taskCount: widget.tasks.length,
                  onAddTask: widget.onAddTask,
                ),
                SizedBox(height: DdtTheme.spacing.h),
                Expanded(
                  child: ClipRRect(
                    borderRadius: DdtTheme.radius,
                    child: DragTarget<Task>(
                    onWillAcceptWithDetails: (_) => true,
                    onMove: (details) {
                      _setDragOver(true);
                      widget.onDropPreview(
                        widget.status,
                        widget.onResolveInsertIndex(
                          widget.status,
                          details.offset,
                        ),
                      );
                    },
                    onLeave: (_) {
                      _setDragOver(false);
                    },
                    onAcceptWithDetails: (details) {
                      _setDragOver(false);
                      widget.onRegisterDrop(
                        details.data,
                        widget.status,
                        widget.dropIndex ??
                            widget.onResolveInsertIndex(
                              widget.status,
                              details.offset,
                            ),
                      );
                    },
                    builder: (context, candidateData, rejectedData) {
                      return _KanbanTaskList(
                        key: widget.taskListKey,
                        status: widget.status,
                        tasks: widget.tasks,
                        draggingTaskId: widget.draggingTaskId,
                        dropIndex: widget.dropIndex,
                        placeholderHeight: widget.placeholderHeight,
                        taskCardKey: widget.taskCardKey,
                        onRegisterCardSize: widget.onRegisterCardSize,
                        onDragStarted: widget.onDragStarted,
                        onDragEnd: widget.onDragEnd,
                        onDeleteTask: widget.onDeleteTask,
                        onOpenTask: widget.onOpenTask,
                      );
                    },
                  ),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: _dragOver,
              builder: (context, isHighlighted, child) {
                return IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: isHighlighted ? 1 : 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: DdtTheme.radius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.45,
                      colors: [
                        _statusColor.withValues(alpha: 0.2),
                        _statusColor.withValues(alpha: 0.12),
                        _statusColor.withValues(alpha: 0.05),
                        _statusColor.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.45, 0.82, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KanbanColumnHeader extends StatelessWidget {
  const _KanbanColumnHeader({
    required this.status,
    required this.taskCount,
    required this.onAddTask,
  });

  final TaskStatus status;
  final int taskCount;
  final void Function(TaskStatus status) onAddTask;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            status.label,
            style: DdtTheme.style(
              fontSize: DdtTypography.sectionTitleSize,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: DdtTheme.radius,
          ),
          child: Text(
            '$taskCount',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        IconButton(
          tooltip: 'Добавить задачу',
          onPressed: () => onAddTask(status),
          icon: DdtIcon(DdtIcons.add, size: 20.sp, color: AppColors.primary),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _KanbanTaskList extends StatefulWidget {
  const _KanbanTaskList({
    super.key,
    required this.status,
    required this.tasks,
    required this.draggingTaskId,
    required this.dropIndex,
    required this.placeholderHeight,
    required this.taskCardKey,
    required this.onRegisterCardSize,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDeleteTask,
    required this.onOpenTask,
  });

  final TaskStatus status;
  final List<Task> tasks;
  final int? draggingTaskId;
  final int? dropIndex;
  final double placeholderHeight;
  final GlobalKey Function(TaskStatus status, int taskId) taskCardKey;
  final void Function(int taskId, Size size) onRegisterCardSize;
  final void Function(TaskStatus status, int taskId) onDragStarted;
  final Future<void> Function(Task task, DraggableDetails details) onDragEnd;
  final void Function(Task task, TaskStatus status) onDeleteTask;
  final void Function(Task task) onOpenTask;

  @override
  State<_KanbanTaskList> createState() => _KanbanTaskListState();
}

class _KanbanTaskListState extends State<_KanbanTaskList> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ListView(
          clipBehavior: Clip.hardEdge,
          children: _buildChildren(),
        ),
        if (widget.tasks.isEmpty && widget.dropIndex == null)
          Center(
            child: Text(
              'Перетащите задачу сюда',
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSize,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildChildren() {
    final draggingId = widget.draggingTaskId;
    final dropIndex = draggingId == null ? null : widget.dropIndex;
    final draggingInThisList =
        draggingId != null && widget.tasks.any((task) => task.id == draggingId);
    final slot = widget.placeholderHeight;
    final spacing = DdtTheme.spacing.h;
    final gapSize = slot + spacing;

    if (widget.tasks.isEmpty) {
      if (dropIndex == null) return const [];
      return [
        _DropPlaceholder(
          key: const ValueKey('drop-placeholder'),
          height: slot,
          animateFromZero: true,
        ),
      ];
    }

    var dragVisibleIndex = 0;
    if (draggingInThisList) {
      for (final task in widget.tasks) {
        if (task.id == draggingId) break;
        dragVisibleIndex++;
      }
    }

    final remainingCount = draggingInThisList
        ? widget.tasks.length - 1
        : widget.tasks.length;
    final holeStaysOnDragSlot =
        draggingInThisList && dropIndex == dragVisibleIndex;
    final showEndGap =
        dropIndex != null &&
        dropIndex == remainingCount &&
        !holeStaysOnDragSlot;

    final children = <Widget>[];
    var visibleIndex = 0;

    for (final task in widget.tasks) {
      if (task.id == draggingId) {
        children.add(
          _buildTaskItem(
            task: task,
            isDraggingItem: true,
            gapBefore: 0,
            gapAfter: 0,
            slotHeight: holeStaysOnDragSlot ? slot : 0,
          ),
        );
        continue;
      }

      final isLastRemaining = visibleIndex == remainingCount - 1;
      final gapBefore =
          dropIndex != null &&
              dropIndex == visibleIndex &&
              !holeStaysOnDragSlot
          ? gapSize
          : 0.0;
      final gapAfter = showEndGap && isLastRemaining ? gapSize : 0.0;

      children.add(
        _buildTaskItem(
          task: task,
          isDraggingItem: false,
          gapBefore: gapBefore,
          gapAfter: gapAfter,
          slotHeight: null,
        ),
      );
      visibleIndex++;
    }

    return children;
  }

  Widget _buildTaskItem({
    required Task task,
    required bool isDraggingItem,
    required double gapBefore,
    required double gapAfter,
    required double? slotHeight,
  }) {
    final card = _DraggableTaskCard(
      cardKey: widget.taskCardKey(widget.status, task.id),
      task: task,
      placeholderHeight: widget.placeholderHeight,
      freezeSize: isDraggingItem,
      onSizeChanged: (size) => widget.onRegisterCardSize(task.id, size),
      onDragStarted: () => widget.onDragStarted(widget.status, task.id),
      onDragEnd: (details) => widget.onDragEnd(task, details),
      onDelete: () => widget.onDeleteTask(task, widget.status),
      onTap: () => widget.onOpenTask(task),
    );

    // Snap closed on drop so the arriving card does not sit on top of a
    // still-closing gap (that double offset made cards below jump).
    final duration = widget.draggingTaskId == null
        ? Duration.zero
        : _kKanbanSlotDuration;

    Widget body = card;
    if (isDraggingItem) {
      final collapsed = (slotHeight ?? 0) <= 0;
      body = ClipRect(
        child: AnimatedContainer(
          duration: duration,
          curve: _kKanbanSlotCurve,
          height: collapsed ? 0 : slotHeight! + DdtTheme.spacing.h,
          child: Padding(
            padding: EdgeInsets.only(bottom: DdtTheme.spacing.h),
            child: card,
          ),
        ),
      );
    }

    return Padding(
      key: ValueKey(task.id),
      padding: EdgeInsets.only(bottom: isDraggingItem ? 0 : DdtTheme.spacing.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: duration,
            curve: _kKanbanSlotCurve,
            height: gapBefore,
          ),
          body,
          AnimatedContainer(
            duration: duration,
            curve: _kKanbanSlotCurve,
            height: gapAfter,
          ),
        ],
      ),
    );
  }
}

class _DraggableTaskCard extends StatefulWidget {
  const _DraggableTaskCard({
    required this.cardKey,
    required this.task,
    required this.placeholderHeight,
    required this.freezeSize,
    required this.onSizeChanged,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDelete,
    required this.onTap,
  });

  final GlobalKey cardKey;
  final Task task;
  final double placeholderHeight;
  final bool freezeSize;
  final ValueChanged<Size> onSizeChanged;
  final VoidCallback onDragStarted;
  final ValueChanged<DraggableDetails> onDragEnd;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  State<_DraggableTaskCard> createState() => _DraggableTaskCardState();
}

class _DraggableTaskCardState extends State<_DraggableTaskCard> {
  Size? _cardSize;

  void _updateCardSize() {
    if (widget.freezeSize) return;
    final renderBox =
        widget.cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    if (_cardSize != size) {
      setState(() => _cardSize = size);
      widget.onSizeChanged(size);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCardSize());

    final theme = Theme.of(context);
    final defaultTextStyle = DefaultTextStyle.of(context).style;

    final placeholderHeight = _cardSize?.height ?? widget.placeholderHeight;

    return KeyedSubtree(
      key: widget.cardKey,
      child: RepaintBoundary(
        child: Draggable<Task>(
          data: widget.task,
          rootOverlay: true,
          onDragStarted: widget.onDragStarted,
          onDragEnd: widget.onDragEnd,
          childWhenDragging: _DropPlaceholder(
            height: placeholderHeight,
            includeSpacing: false,
          ),
          feedback: _cardSize == null
              ? const SizedBox.shrink()
              : IgnorePointer(
                  child: Theme(
                    data: theme,
                    child: DefaultTextStyle(
                      style: defaultTextStyle,
                      child: SizedBox(
                        width: _cardSize!.width,
                        height: _cardSize!.height,
                        child: TaskCard(
                          task: widget.task,
                          isDragging: true,
                          onDelete: widget.onDelete,
                        ),
                      ),
                    ),
                  ),
                ),
          child: TaskCard(
            task: widget.task,
            onDelete: widget.onDelete,
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}

class _DropPlaceholder extends StatelessWidget {
  const _DropPlaceholder({
    super.key,
    required this.height,
    this.includeSpacing = true,
    this.animateFromZero = false,
  });

  final double height;
  final bool includeSpacing;
  final bool animateFromZero;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;
    final slot = _AnimatedDropSlot(
      height: height,
      animateFromZero: animateFromZero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: DdtTheme.radius,
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
      ),
    );

    if (!includeSpacing) return slot;

    return Padding(
      padding: EdgeInsets.only(bottom: DdtTheme.spacing.h),
      child: slot,
    );
  }
}

class _AnimatedDropSlot extends StatefulWidget {
  const _AnimatedDropSlot({
    required this.height,
    required this.animateFromZero,
    required this.child,
  });

  final double height;
  final bool animateFromZero;
  final Widget child;

  @override
  State<_AnimatedDropSlot> createState() => _AnimatedDropSlotState();
}

class _AnimatedDropSlotState extends State<_AnimatedDropSlot> {
  late double _height = widget.animateFromZero ? 0 : widget.height;

  @override
  void initState() {
    super.initState();
    if (widget.animateFromZero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _height = widget.height);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedDropSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.height != widget.height) {
      _height = widget.height;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedContainer(
        duration: _kKanbanSlotDuration,
        curve: _kKanbanSlotCurve,
        height: _height,
        child: widget.child,
      ),
    );
  }
}

class _PendingTaskDrop {
  const _PendingTaskDrop({
    required this.task,
    required this.to,
    required this.toIndex,
  });

  final Task task;
  final TaskStatus to;
  final int toIndex;
}
