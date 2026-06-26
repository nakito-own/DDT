import 'dart:ui' as ui;

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/ews_auth_controller.dart';
import '../controllers/tasks_controller.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import '../widgets/task_card.dart';
import '../widgets/task_side_panel.dart';

const _kanbanMotionDuration = Duration(milliseconds: 380);
const _kanbanMotionCurve = Curves.easeInOutCubicEmphasized;

class KanbanBoardPage extends StatefulWidget {
  const KanbanBoardPage({super.key});

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage>
    with TickerProviderStateMixin {
  TasksController get _tasks => Get.find<TasksController>();

  final Map<int, GlobalKey> _taskCardKeys = {};
  final Map<int, Size> _taskCardSizes = {};
  final Map<int, Offset> _dragOriginByTaskId = {};
  final Map<TaskStatus, GlobalKey<_KanbanTaskListState>> _taskListKeys = {
    for (final status in TaskStatus.values) status: GlobalKey(),
  };
  int? _animatingTaskId;
  _PendingTaskDrop? _pendingDrop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tasks.loadBoard();
    });
  }

  List<Task> _columnTasks(TaskStatus status) =>
      _tasks.columns[status] ?? const [];

  GlobalKey _taskCardKey(int taskId) =>
      _taskCardKeys.putIfAbsent(taskId, () => GlobalKey());

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

  void _applyMove(Task task, TaskStatus from, TaskStatus to) {
    final fromColumn = _tasks.columns[from];
    final toColumn = _tasks.columns[to];
    if (fromColumn == null || toColumn == null) return;

    fromColumn.removeWhere((item) => item.id == task.id);
    toColumn.add(_updatedTaskForColumn(task, to));
    _tasks.columns.refresh();
  }

  void _registerTaskDrop(Task task, TaskStatus to) {
    _pendingDrop = _PendingTaskDrop(task: task, to: to);
  }

  void _onTaskDragStarted(int taskId) {
    final cardContext = _taskCardKey(taskId).currentContext;
    if (cardContext == null) return;

    final box = cardContext.findRenderObject()! as RenderBox;
    _dragOriginByTaskId[taskId] = box.localToGlobal(Offset.zero);
  }

  void _showMoveToast(Task task, TaskStatus to) {
    Toast.show(
      message: '«${task.title}» → ${to.label}',
      type: ToastType.info,
      title: 'Задача перемещена',
    );
  }

  Future<void> _finishTaskDrag(Task task, DraggableDetails details) async {
    final pending = _pendingDrop;
    _pendingDrop = null;
    final originTopLeft = _dragOriginByTaskId.remove(task.id);
    final cardSize = _taskCardSizes[task.id];

    if (!details.wasAccepted || pending == null || pending.task.id != task.id) {
      if (!details.wasAccepted &&
          originTopLeft != null &&
          cardSize != null) {
        await _animateTaskReturn(
          task: task,
          feedbackTopLeft: details.offset,
          originTopLeft: originTopLeft,
          cardSize: cardSize,
        );
      }
      return;
    }

    final from = task.status;
    final to = pending.to;
    if (from == to) return;

    if (cardSize == null) {
      setState(() => _applyMove(task, from, to));
      final updated = _updatedTaskForColumn(task, to);
      final saved = await _tasks.persistMove(task, from, to, updated);
      if (!mounted) return;
      if (saved == null) {
        setState(() => _applyMove(updated, to, from));
      }
      _showMoveToast(task, to);
      return;
    }

    await _animateTaskDrop(
      task: task,
      from: from,
      to: to,
      feedbackTopLeft: details.offset,
      cardSize: cardSize,
    );

    if (!mounted) return;

    final updated = _updatedTaskForColumn(task, to);
    final saved = await _tasks.persistMove(task, from, to, updated);
    if (!mounted) return;
    if (saved == null) {
      setState(() => _applyMove(updated, to, from));
    }
    _showMoveToast(task, to);
  }

  Future<void> _animateTaskReturn({
    required Task task,
    required Offset feedbackTopLeft,
    required Offset originTopLeft,
    required Size cardSize,
  }) async {
    setState(() => _animatingTaskId = task.id);

    await _runCardFlightAnimation(
      task: task,
      startGlobalTopLeft: feedbackTopLeft,
      endGlobalTopLeft: Future.value(originTopLeft),
      cardSize: cardSize,
    );

    if (!mounted) return;
    setState(() => _animatingTaskId = null);
  }

  Future<void> _animateTaskDrop({
    required Task task,
    required TaskStatus from,
    required TaskStatus to,
    required Offset feedbackTopLeft,
    required Size cardSize,
  }) async {
    final updated = _updatedTaskForColumn(task, to);
    final fromColumn = _tasks.columns[from];
    final toColumn = _tasks.columns[to];
    if (fromColumn == null || toColumn == null) return;

    final fromIndex = fromColumn.indexWhere((item) => item.id == task.id);
    if (fromIndex < 0) return;

    final gap = fromIndex < fromColumn.length - 1 ? DdtTheme.spacing.h : 0;
    final toIndex = toColumn.length;

    setState(() {
      fromColumn.removeAt(fromIndex);
      toColumn.add(updated);
      _animatingTaskId = task.id;
    });
    _tasks.columns.refresh();

    _taskListKeys[from]!.currentState?.removeTaskAt(
      fromIndex,
      slotHeight: cardSize.height + gap,
    );

    _taskListKeys[to]?.currentState?.insertTaskAt(toIndex);

    await _runCardFlightAnimation(
      task: task,
      startGlobalTopLeft: feedbackTopLeft,
      endGlobalTopLeft: _measureTaskCardTopLeft(task.id),
      cardSize: cardSize,
      displayTask: updated,
    );

    if (!mounted) return;
    setState(() => _animatingTaskId = null);
  }

  Future<Offset?> _measureTaskCardTopLeft(int taskId) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;

    final targetContext = _taskCardKey(taskId).currentContext;
    if (targetContext == null || !targetContext.mounted) return null;

    final targetBox = targetContext.findRenderObject()! as RenderBox;
    return targetBox.localToGlobal(Offset.zero);
  }

  Future<void> _runCardFlightAnimation({
    required Task task,
    required Offset startGlobalTopLeft,
    required Future<Offset?> endGlobalTopLeft,
    required Size cardSize,
    Task? displayTask,
  }) async {
    final card = displayTask ?? task;
    final theme = Theme.of(context);
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;

    final startInOverlay = overlayBox.globalToLocal(startGlobalTopLeft);
    var endInOverlay = startInOverlay;

    final controller = AnimationController(
      vsync: this,
      duration: _kanbanMotionDuration,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: _kanbanMotionCurve,
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final left = ui.lerpDouble(startInOverlay.dx, endInOverlay.dx, t)!;
            final top = ui.lerpDouble(startInOverlay.dy, endInOverlay.dy, t)!;

            return Positioned(
              left: left,
              top: top,
              width: cardSize.width,
              height: cardSize.height,
              child: IgnorePointer(
                child: Theme(
                  data: theme,
                  child: DefaultTextStyle(
                    style: defaultTextStyle,
                    child: TaskCard(task: card, isDragging: true),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    overlay.insert(entry);

    final measuredEnd = await endGlobalTopLeft;
    if (!mounted || measuredEnd == null) {
      entry.remove();
      controller.dispose();
      return;
    }

    endInOverlay = overlayBox.globalToLocal(measuredEnd);
    entry.markNeedsBuild();
    await controller.forward();
    entry.remove();
    controller.dispose();
  }

  Future<void> _addTask(TaskStatus status) async {
    final auth = Get.find<EwsAuthController>();
    final created = await showTaskSidePanel(
      context,
      mode: TaskSidePanelMode.create,
      initialStatus: status,
      taskTypes: _tasks.taskTypes.toList(),
      defaultAuthorId: auth.currentUserId,
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
      authorId: auth.currentUserId ?? created.authorId,
      executorId: created.executorId,
      responsibleId: created.responsibleId,
      timeSet: created.timeSet,
      timeStart: created.timeStart ??
          (created.status == TaskStatus.inProgress ? now : null),
      timeEnd:
          created.timeEnd ?? (created.status == TaskStatus.done ? now : null),
      deadline: created.deadline,
      priority: created.priority,
      links: created.links,
      comments: created.comments,
    );

    final task = await _tasks.createTask(draft);
    if (task == null || !mounted) return;

    setState(() {});

    _taskListKeys[task.status]?.currentState?.insertTaskAt(
      _columnTasks(task.status).length - 1,
    );

    Toast.show(
      message: 'Задача добавлена в «${task.status.label}»',
      type: ToastType.success,
    );
  }

  Future<void> _deleteTask(Task task, TaskStatus status) async {
    final column = _columnTasks(status);
    final index = column.indexWhere((item) => item.id == task.id);
    if (index < 0) return;

    final cardSize = _taskCardSizes[task.id];
    final gap = index < column.length - 1 ? DdtTheme.spacing.h : 0.0;

    final deleted = await _tasks.deleteTask(task, status);
    if (!deleted || !mounted) return;

    setState(() {});

    if (cardSize != null) {
      _taskListKeys[status]?.currentState?.removeTaskAt(
        index,
        slotHeight: cardSize.height + gap,
      );
    }

    Toast.show(
      message: '«${task.title}» удалена',
      type: ToastType.success,
    );
  }

  Future<void> _openTaskDetails(Task task) async {
    final updated = await showTaskSidePanel(
      context,
      mode: TaskSidePanelMode.view,
      task: task,
      taskTypes: _tasks.taskTypes.toList(),
    );

    if (updated == null || !mounted) return;

    await _applyTaskUpdate(task, updated);
  }

  Future<void> _applyTaskUpdate(Task original, Task updated) async {
    final oldStatus = original.status;
    final newStatus = updated.status;

    if (oldStatus == newStatus) {
      final saved = await _tasks.updateTask(original, updated);
      if (saved == null || !mounted) return;
      setState(() {});
      return;
    }

    final oldIndex =
        _columnTasks(oldStatus).indexWhere((item) => item.id == original.id);
    if (oldIndex < 0) return;

    final cardSize = _taskCardSizes[original.id];
    final gap =
        oldIndex < _columnTasks(oldStatus).length - 1 ? DdtTheme.spacing.h : 0.0;

    final saved = await _tasks.updateTask(original, updated);
    if (saved == null || !mounted) return;

    setState(() {});

    if (cardSize != null) {
      _taskListKeys[oldStatus]?.currentState?.removeTaskAt(
        oldIndex,
        slotHeight: cardSize.height + gap,
      );
    }

    _taskListKeys[newStatus]?.currentState?.insertTaskAt(
      _columnTasks(newStatus).length - 1,
    );

    Toast.show(
      message: 'Задача перемещена в «${newStatus.label}»',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_tasks.isLoading.value && _tasks.allTasks.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final error = _tasks.errorMessage.value;
      if (error != null && _tasks.allTasks.isEmpty) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Не удалось загрузить задачи',
                  style: DdtTheme.style(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(error, textAlign: TextAlign.center),
                SizedBox(height: 16.h),
                Button(
                  text: 'Повторить',
                  onPressed: _tasks.loadBoard,
                  borderRadius: DdtTheme.radius,
                ),
              ],
            ),
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < TaskStatus.values.length; index++) ...[
                  if (index > 0) DdtTheme.horizontalGap(),
                  Expanded(
                    child: _KanbanColumn(
                      key: ValueKey(TaskStatus.values[index]),
                      status: TaskStatus.values[index],
                      tasks: _columnTasks(TaskStatus.values[index]),
                      taskListKey: _taskListKeys[TaskStatus.values[index]]!,
                      animatingTaskId: _animatingTaskId,
                      taskCardKey: _taskCardKey,
                      onRegisterCardSize: _registerTaskCardSize,
                      onRegisterDrop: _registerTaskDrop,
                      onDragStarted: _onTaskDragStarted,
                      onDragEnd: _finishTaskDrag,
                      onAddTask: _addTask,
                      onDeleteTask: _deleteTask,
                      onOpenTask: _openTaskDetails,
                    ),
                  ),
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
                  child: _KanbanColumn(
                    key: ValueKey(status),
                    status: status,
                    tasks: _columnTasks(status),
                    taskListKey: _taskListKeys[status]!,
                    animatingTaskId: _animatingTaskId,
                    taskCardKey: _taskCardKey,
                    onRegisterCardSize: _registerTaskCardSize,
                    onRegisterDrop: _registerTaskDrop,
                    onDragStarted: _onTaskDragStarted,
                    onDragEnd: _finishTaskDrag,
                    onAddTask: _addTask,
                    onDeleteTask: _deleteTask,
                    onOpenTask: _openTaskDetails,
                  ),
                );
              },
            ),
          );
        },
      );
    });
  }
}

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    super.key,
    required this.status,
    required this.tasks,
    required this.taskListKey,
    required this.animatingTaskId,
    required this.taskCardKey,
    required this.onRegisterCardSize,
    required this.onRegisterDrop,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onAddTask,
    required this.onDeleteTask,
    required this.onOpenTask,
  });

  final TaskStatus status;
  final List<Task> tasks;
  final GlobalKey<_KanbanTaskListState> taskListKey;
  final int? animatingTaskId;
  final GlobalKey Function(int taskId) taskCardKey;
  final void Function(int taskId, Size size) onRegisterCardSize;
  final void Function(Task task, TaskStatus to) onRegisterDrop;
  final void Function(int taskId) onDragStarted;
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _KanbanTaskList(
                        key: widget.taskListKey,
                        status: widget.status,
                        tasks: widget.tasks,
                        animatingTaskId: widget.animatingTaskId,
                        taskCardKey: widget.taskCardKey,
                        onRegisterCardSize: widget.onRegisterCardSize,
                        onDragStarted: widget.onDragStarted,
                        onDragEnd: widget.onDragEnd,
                        onDeleteTask: widget.onDeleteTask,
                        onOpenTask: widget.onOpenTask,
                      ),
                      Positioned.fill(
                        child: DragTarget<Task>(
                          onWillAcceptWithDetails: (details) {
                            final accept =
                                details.data.status != widget.status;
                            _setDragOver(accept);
                            return accept;
                          },
                          onLeave: (_) => _setDragOver(false),
                          onAcceptWithDetails: (details) {
                            _setDragOver(false);
                            widget.onRegisterDrop(details.data, widget.status);
                          },
                          builder: (context, candidateData, rejectedData) {
                            return const SizedBox.expand();
                          },
                        ),
                      ),
                    ],
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
              fontSize: 16.sp,
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
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        IconButton(
          tooltip: 'Добавить задачу',
          onPressed: () => onAddTask(status),
          icon: Icon(
            CupertinoIcons.add,
            size: 20.sp,
            color: AppColors.primary,
          ),
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
    required this.animatingTaskId,
    required this.taskCardKey,
    required this.onRegisterCardSize,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDeleteTask,
    required this.onOpenTask,
  });

  final TaskStatus status;
  final List<Task> tasks;
  final int? animatingTaskId;
  final GlobalKey Function(int taskId) taskCardKey;
  final void Function(int taskId, Size size) onRegisterCardSize;
  final void Function(int taskId) onDragStarted;
  final Future<void> Function(Task task, DraggableDetails details) onDragEnd;
  final void Function(Task task, TaskStatus status) onDeleteTask;
  final void Function(Task task) onOpenTask;

  @override
  State<_KanbanTaskList> createState() => _KanbanTaskListState();
}

class _KanbanTaskListState extends State<_KanbanTaskList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  void insertTaskAt(int index) {
    _listKey.currentState!.insertItem(
      index,
      duration: Duration.zero,
    );
  }

  void removeTaskAt(int index, {required double slotHeight}) {
    _listKey.currentState!.removeItem(
      index,
      (context, animation) => _KanbanSlotCollapse(
        animation: animation,
        height: slotHeight,
      ),
      duration: _kanbanMotionDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedList(
          key: _listKey,
          initialItemCount: widget.tasks.length,
          itemBuilder: (context, index, animation) {
            final task = widget.tasks[index];

            return _buildTaskItem(
              task: task,
              index: index,
              animation: animation,
            );
          },
        ),
        if (widget.tasks.isEmpty)
          Center(
            child: Text(
              'Перетащите задачу сюда',
              style: DdtTheme.style(
                fontSize: 13.sp,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildTaskItem({
    required Task task,
    required int index,
    required Animation<double> animation,
  }) {
    final card = _DraggableTaskCard(
      key: ValueKey(task.id),
      cardKey: widget.taskCardKey(task.id),
      isHidden: widget.animatingTaskId == task.id,
      task: task,
      onSizeChanged: (size) => widget.onRegisterCardSize(task.id, size),
      onDragStarted: () => widget.onDragStarted(task.id),
      onDragEnd: (details) => widget.onDragEnd(task, details),
      onDelete: () => widget.onDeleteTask(task, widget.status),
      onTap: () => widget.onOpenTask(task),
    );

    final animatedCard = SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ),
      axisAlignment: -1,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: card,
      ),
    );

    if (index >= widget.tasks.length - 1) {
      return animatedCard;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        animatedCard,
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          axisAlignment: -1,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: DdtTheme.verticalGap(),
          ),
        ),
      ],
    );
  }
}

class _DraggableTaskCard extends StatefulWidget {
  const _DraggableTaskCard({
    super.key,
    required this.cardKey,
    required this.isHidden,
    required this.task,
    required this.onSizeChanged,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDelete,
    required this.onTap,
  });

  final GlobalKey cardKey;
  final bool isHidden;
  final Task task;
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

    final card = IgnorePointer(
      ignoring: widget.isHidden,
      child: Opacity(
        opacity: widget.isHidden ? 0 : 1,
        child: TaskCard(
          key: widget.cardKey,
          task: widget.task,
          onDelete: widget.onDelete,
          onTap: widget.onTap,
        ),
      ),
    );

    return RepaintBoundary(
      child: Draggable<Task>(
        data: widget.task,
        rootOverlay: true,
        onDragStarted: widget.onDragStarted,
        onDragEnd: widget.onDragEnd,
        feedback: _cardSize == null
            ? const SizedBox.shrink()
            : Theme(
                data: theme,
                child: DefaultTextStyle(
                  style: defaultTextStyle,
                  child: SizedBox(
                    width: _cardSize!.width,
                    height: _cardSize!.height,
                    child: TaskCard(task: widget.task, isDragging: true),
                  ),
                ),
              ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: TaskCard(task: widget.task),
        ),
        child: card,
      ),
    );
  }
}

class _KanbanSlotCollapse extends StatelessWidget {
  const _KanbanSlotCollapse({
    required this.animation,
    required this.height,
  });

  final Animation<double> animation;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final heightFactor =
            _kanbanMotionCurve.transform(animation.value).clamp(0.0, 1.0);

        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: heightFactor,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: height,
      ),
    );
  }
}

class _PendingTaskDrop {
  const _PendingTaskDrop({required this.task, required this.to});

  final Task task;
  final TaskStatus to;
}
