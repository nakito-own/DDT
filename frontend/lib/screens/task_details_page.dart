import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/ddt_icons.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/queue_settings.dart';
import '../models/task.dart';
import '../models/task_link.dart';
import '../models/task_priority.dart';
import '../models/task_ref.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import '../router/route_paths.dart';
import '../services/tasks_api.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import '../utils/task_status_dates.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_desktop_shortcuts.dart';
import '../widgets/ddt_round_back_button.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/task_comments_section.dart';
import '../widgets/task_queue_rules.dart';
import 'task_create_page.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_markdown_body.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_side_panel.dart';
import '../widgets/ddt_side_panel_divider.dart';

class TaskDetailsPage extends StatefulWidget {
  const TaskDetailsPage({
    super.key,
    required this.taskKey,
    this.spaceKey,
    this.initialTask,
  });

  final String taskKey;
  final String? spaceKey;

  /// Already loaded task. A phone sheet has no route extra to read.
  final Task? initialTask;

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  Task? _task;
  bool _isLoading = true;
  String? _error;
  var _restored = false;

  bool get _inSheet => ModalRoute.of(context) is ModalBottomSheetRoute;

  Task? _knownTask() {
    final initial = widget.initialTask;
    if (initial != null &&
        (initial.apiRef == widget.taskKey ||
            initial.key == widget.taskKey ||
            initial.id.toString() == widget.taskKey)) {
      return initial;
    }
    final extra = GoRouterState.of(context).extra;
    if (extra is Task &&
        (extra.apiRef == widget.taskKey ||
            extra.key == widget.taskKey ||
            extra.id.toString() == widget.taskKey)) {
      return extra;
    }
    for (final task in context.read<TasksBloc>().state.allTasks) {
      if (task.apiRef == widget.taskKey ||
          task.key == widget.taskKey ||
          task.id.toString() == widget.taskKey) {
        return task;
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant TaskDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskKey != widget.taskKey ||
        oldWidget.spaceKey != widget.spaceKey) {
      _task = _knownTask();
      _isLoading = _task == null;
      _loadTask();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    _task = _knownTask();
    _isLoading = _task == null;
    _loadTask();
  }

  Future<void> _loadTask() async {
    if (_task == null && !_isLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final task = await TasksApi().fetchTask(widget.taskKey);
      if (!mounted) return;
      setState(() {
        _task = task;
        _isLoading = false;
      });
      context.read<TasksBloc>().add(TaskServerSnapshotReceived(task));
      if (_inSheet) return;
      final canonical = RoutePaths.task(task.key);
      if (task.spaceId == null &&
          task.key.isNotEmpty &&
          GoRouterState.of(context).uri.path != canonical) {
        context.replace(canonical, extra: task);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _editTask() async {
    final task = _task;
    if (task == null) return;

    final Future<Task?> updatedFuture = _inSheet
        ? showDdtFullscreenBottomSheet<Task>(
            context,
            child: TaskEditPage(
              taskKey: widget.taskKey,
              spaceKey: widget.spaceKey ?? task.spaceKey,
              task: task,
            ),
          )
        : openTaskEditPage(context, task);
    final updated = await updatedFuture;
    if (updated == null || !mounted) return;

    setState(() => _task = updated);
    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: task, updated: updated),
    );
  }

  void _saveParameters(Task updated) {
    final original = _task;
    if (original == null) return;
    setState(() => _task = updated);
    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: original, updated: updated),
    );
  }

  void _onEscape() {
    if (ddtPopOverlayIfAny(context)) return;
    final task = _task;
    if (task != null) {
      _leaveTask(context, task);
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(_backRoute);
  }

  @override
  Widget build(BuildContext context) {
    return DdtPageShortcuts(
      onEscape: _onEscape,
      child: BlocListener<TasksBloc, TasksState>(
      listenWhen: (previous, current) {
        Task? findTask(TasksState state) {
          for (final tasks in state.columns.values) {
            for (final task in tasks) {
              if (task.apiRef == widget.taskKey ||
                  task.key == widget.taskKey ||
                  task.id.toString() == widget.taskKey) {
                return task;
              }
            }
          }
          return null;
        }

        return findTask(previous) != findTask(current);
      },
      listener: (context, state) {
        final index = state.allTasks.indexWhere(
          (task) =>
              task.apiRef == widget.taskKey ||
              task.key == widget.taskKey ||
              task.id.toString() == widget.taskKey,
        );
        if (index >= 0 && mounted) {
          setState(() => _task = state.allTasks[index]);
        }
      },
      child: _buildBody(context),
    ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _task == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DdtIcon(
              DdtIcons.warning,
              size: 36.sp,
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: 12.h),
            Text(_error ?? 'Задача не найдена', textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Button(
                  text: 'К задачам',
                  type: ButtonType.outlined,
                  onPressed: () => context.go(_backRoute),
                  borderRadius: DdtTheme.radius,
                ),
                SizedBox(width: 10.w),
                Button(
                  text: 'Повторить',
                  onPressed: _loadTask,
                  borderRadius: DdtTheme.radius,
                ),
              ],
            ),
          ],
        ),
      );
    }

    final task = _task!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;

        return wide
            ? _WideTaskLayout(
                task: task,
                onEdit: _editTask,
                onTaskChanged: (updated) {
                  setState(() => _task = updated);
                },
                onParametersChanged: _saveParameters,
              )
            : SingleChildScrollView(
                padding: DdtShellMetrics.scrollPadding(
                  context,
                  base: EdgeInsets.fromLTRB(
                    DdtRoundBackButton.screenInset,
                    12.h,
                    20.w,
                    24.h + DdtShellMetrics.contentBottomPadding(context),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TaskHeader(task: task, onEdit: _editTask),
                    Padding(
                      padding: EdgeInsets.only(
                        left: DdtRoundBackButton.contentLead(20.w),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 16.h),
                          _TaskDescription(task: task),
                          SizedBox(height: 20.h),
                          _TaskRelationsBlock(task: task),
                          SizedBox(height: 20.h),
                          _TaskParametersPanel(
                            task: task,
                            pinned: false,
                            onChanged: _saveParameters,
                          ),
                          SizedBox(height: 24.h),
                          TaskCommentsSection(
                            key: ValueKey('task-comments-${task.id}'),
                            task: task,
                            inputAtTop: true,
                            onTaskChanged: (updated) {
                              setState(() => _task = updated);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
      },
    );
  }

  String get _backRoute {
    final spaceKey = widget.spaceKey ?? _task?.spaceKey;
    if (spaceKey != null && spaceKey.isNotEmpty) {
      return RoutePaths.spaceListFor(spaceKey);
    }
    return RoutePaths.tasksList;
  }
}

/// Fullscreen task view: the page scrolls as one piece, while the parameters
/// panel stays put once its top meets the content top.
class _WideTaskLayout extends StatefulWidget {
  const _WideTaskLayout({
    required this.task,
    required this.onEdit,
    required this.onTaskChanged,
    required this.onParametersChanged,
  });

  final Task task;
  final VoidCallback onEdit;
  final ValueChanged<Task> onTaskChanged;
  final ValueChanged<Task> onParametersChanged;

  @override
  State<_WideTaskLayout> createState() => _WideTaskLayoutState();
}

class _WideTaskLayoutState extends State<_WideTaskLayout> {
  final _pageScroll = ScrollController();
  final _panelScroll = ScrollController();
  double _chromeHeight = 136;

  @override
  void didUpdateWidget(covariant _WideTaskLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id && _pageScroll.hasClients) {
      _pageScroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _pageScroll.dispose();
    _panelScroll.dispose();
    super.dispose();
  }

  void _onPanelPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0 || _panelCanConsume(dy)) return;
    _scrollPageBy(dy);
  }

  void _scrollPageBy(double dy) {
    if (dy == 0 || !_pageScroll.hasClients) return;
    final page = _pageScroll.position;
    if (!page.hasContentDimensions) return;
    if (page.maxScrollExtent <= page.minScrollExtent) return;
    final next = (page.pixels + dy).clamp(
      page.minScrollExtent,
      page.maxScrollExtent,
    );
    if (next != page.pixels) {
      page.jumpTo(next.toDouble());
    }
  }

  bool _panelCanConsume(double dy) {
    if (!_panelScroll.hasClients) return false;
    final panel = _panelScroll.position;
    if (!panel.hasContentDimensions || panel.maxScrollExtent <= 0) {
      return false;
    }
    final atStart = panel.pixels <= panel.minScrollExtent;
    final atEnd = panel.pixels >= panel.maxScrollExtent;
    return (dy > 0 && !atEnd) || (dy < 0 && !atStart);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = DdtShellMetrics.maybeOf(context)?.contentInsetTop ?? 0;
    final floatingBottom = DdtAdaptive.floatingBottomBar(context)
        ? DdtShellMetrics.contentBottomPadding(context)
        : 0.0;

    final fadeTail = 28.h;
    final chromeFade = _chromeHeight;
    final chromeHold = (chromeFade - fadeTail).clamp(0.0, chromeFade);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              DdtContentFadeMask(
                topHold: chromeHold,
                topFade: chromeFade,
                child: SingleChildScrollView(
                  controller: _pageScroll,
                  primary: false,
                  padding: EdgeInsets.only(
                    top: _chromeHeight,
                    bottom: floatingBottom,
                  ),
                  child: _TaskMainContent(
                    task: widget.task,
                    onTaskChanged: widget.onTaskChanged,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ChromeHeightReporter(
                  onHeight: (height) {
                    if (!mounted || (height - _chromeHeight).abs() < 0.5) {
                      return;
                    }
                    setState(() => _chromeHeight = height);
                  },
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is! PointerScrollEvent) return;
                      _scrollPageBy(event.scrollDelta.dy);
                    },
                    child: _PinnedTaskChrome(
                      topInset: topInset,
                      task: widget.task,
                      onEdit: widget.onEdit,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const DdtSidePanelDivider(),
        SizedBox(
          width: 400.w,
          child: Padding(
            padding: EdgeInsets.only(top: topInset, bottom: floatingBottom),
            child: Listener(
              onPointerSignal: _onPanelPointerSignal,
              child: _TaskParametersPanel(
                task: widget.task,
                pinned: true,
                scrollController: _panelScroll,
                onChanged: widget.onParametersChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskMainContent extends StatelessWidget {
  const _TaskMainContent({
    required this.task,
    required this.onTaskChanged,
  });

  final Task task;
  final ValueChanged<Task> onTaskChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TaskDescription(task: task, showHeading: false),
          SizedBox(height: 20.h),
          _TaskRelationsBlock(task: task),
          Divider(
            height: 32.h,
            thickness: 1,
            color: DdtTheme.sidePanelDivider(context),
          ),
          TaskCommentsSection(
            key: ValueKey('task-comments-${task.id}'),
            task: task,
            inputAtTop: true,
            onTaskChanged: onTaskChanged,
          ),
        ],
      ),
    );
  }
}

/// Toolbar and title stay pinned. Scrolling text fades out under them
/// instead of sitting on a solid color band.
class _PinnedTaskChrome extends StatelessWidget {
  const _PinnedTaskChrome({
    required this.topInset,
    required this.task,
    required this.onEdit,
  });

  final double topInset;
  final Task task;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DdtRoundBackButton.screenInset,
        topInset + 12.h,
        20.w,
        0,
      ),
      child: _TaskHeader(task: task, onEdit: onEdit, fullscreen: true),
    );
  }
}

class _ChromeHeightReporter extends StatefulWidget {
  const _ChromeHeightReporter({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<_ChromeHeightReporter> createState() => _ChromeHeightReporterState();
}

class _ChromeHeightReporterState extends State<_ChromeHeightReporter> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(covariant _ChromeHeightReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _report();
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

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({
    required this.task,
    required this.onEdit,
    this.fullscreen = false,
  });

  final Task task;
  final VoidCallback onEdit;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final title = Padding(
      padding: EdgeInsets.only(left: DdtRoundBackButton.contentLead(20.w)),
      child: Text(
        task.title,
        style: DdtTheme.style(
          fontSize: DdtTypography.entityTitleSize,
          fontWeight: FontWeight.w700,
          color: DdtTheme.sidePanelTextPrimary(context),
        ),
      ),
    );

    if (fullscreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FullscreenTaskToolbar(task: task, onEdit: onEdit),
          SizedBox(height: 8.h),
          title,
        ],
      );
    }

    // Title sits under the toolbar. Beside the edit button it collapsed to a
    // one-word column on a phone.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            DdtRoundBackButton(
              tooltip: 'Назад к задачам',
              onPressed: () => _leaveTask(context, task),
            ),
            const SizedBox(width: DdtRoundBackButton.labelGap),
            Expanded(
              child: Text(
                'Задача ${task.displayKey}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSmallSize,
                  color: DdtTheme.sidePanelTextMuted(context),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Button(
              text: 'Редактировать',
              size: ButtonSize.small,
              onPressed: onEdit,
              borderRadius: DdtTheme.radius,
            ),
          ],
        ),
        SizedBox(height: 8.h),
        title,
      ],
    );
  }
}

/// Painted height of the fullscreen edit icon.
/// App-bar glyphs are 16 before [DdtIcon.visualScale], about 14 on screen.
const double _taskMarkSize = 14;

/// Copy actions sit beside the key and stay smaller than the main marks.
const double _taskCopyMarkSize = 11;

class _FullscreenTaskToolbar extends StatefulWidget {
  const _FullscreenTaskToolbar({required this.task, required this.onEdit});

  final Task task;
  final VoidCallback onEdit;

  @override
  State<_FullscreenTaskToolbar> createState() => _FullscreenTaskToolbarState();
}

class _FullscreenTaskToolbarState extends State<_FullscreenTaskToolbar> {
  bool _keyHovered = false;

  String get _keyLabel => widget.task.displayKey.toUpperCase();

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    DdtToast.show(message: message, type: ToastType.success);
  }

  String _taskLink() {
    final task = widget.task;
    final key = task.key.isNotEmpty ? task.key : task.displayKey;
    // Flutter web keeps the route in the hash: /#/tasks/<key>.
    return '${Uri.base.origin}/#${RoutePaths.task(key)}';
  }

  @override
  Widget build(BuildContext context) {
    final keyStyle = DdtTheme.style(
      fontSize: DdtTypography.labelSize,
      height: 1,
      fontWeight: FontWeight.w500,
      color: DdtTheme.sidePanelTextMuted(context).withValues(alpha: 0.55),
    );
    final editButton = _TaskMarkButton(
      icon: DdtIcons.edit,
      label: 'Редактировать',
      onPressed: widget.onEdit,
    );

    return Row(
      children: [
        DdtRoundBackButton(
          tooltip: 'Назад к задачам',
          onPressed: () => _leaveTask(context, widget.task),
        ),
        const SizedBox(width: DdtRoundBackButton.labelGap),
        Expanded(
          child: MouseRegion(
            onEnter: (_) => setState(() => _keyHovered = true),
            onExit: (_) => setState(() => _keyHovered = false),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _keyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: keyStyle,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  alignment: Alignment.centerLeft,
                  child: _keyHovered
                      ? Padding(
                          padding: EdgeInsets.only(left: 10.w),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TaskMarkButton(
                                icon: DdtIcons.copy,
                                label: 'Копировать ключ',
                                size: _taskCopyMarkSize,
                                onPressed: () => _copy(
                                  _keyLabel,
                                  'Ключ скопирован',
                                ),
                              ),
                              SizedBox(width: 10.w),
                              _TaskMarkButton(
                                icon: DdtIcons.link,
                                label: 'Копировать ссылку',
                                size: _taskCopyMarkSize,
                                onPressed: () => _copy(
                                  _taskLink(),
                                  'Ссылка скопирована',
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.w),
        editButton,
      ],
    );
  }
}

class _TaskMarkButton extends StatelessWidget {
  const _TaskMarkButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = _taskMarkSize,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Tooltip.dismissAllToolTips();
              onPressed();
            },
            child: DdtIcon(
              icon,
              size: size / DdtIcon.visualScale,
              color: DdtTheme.sidePanelTextSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openTaskDetailsPage(BuildContext context, Task task) {
  final taskKey = task.key.isNotEmpty
      ? task.key
      : (task.id > 0 ? task.id.toString() : '');
  if (taskKey.isEmpty) return Future.value();

  final taskSpace = task.spaceKey;
  final spaceKey = taskSpace != null && taskSpace.isNotEmpty
      ? taskSpace
      : context.read<TasksBloc>().spaceKey;
  if (DdtAdaptive.isCompact(context)) {
    return showDdtFullscreenBottomSheet<void>(
      context,
      child: TaskDetailsPage(
        taskKey: taskKey,
        spaceKey: spaceKey,
        initialTask: task,
      ),
    );
  }
  return context.push(
    RoutePaths.forTask(
      taskKey: taskKey,
      spaceId: task.spaceId,
      spaceKey: spaceKey,
    ),
    extra: task,
  );
}

void _leaveTask(BuildContext context, Task task) {
  if (ModalRoute.of(context) is ModalBottomSheetRoute) {
    Navigator.of(context).pop();
    return;
  }
  if (context.canPop()) {
    context.pop();
    return;
  }
  final spaceKey = task.spaceKey;
  context.go(
    spaceKey != null && spaceKey.isNotEmpty
        ? RoutePaths.spaceListFor(spaceKey)
        : RoutePaths.tasksList,
  );
}

class _TaskDescription extends StatelessWidget {
  const _TaskDescription({required this.task, this.showHeading = true});

  final Task task;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final isEmpty = task.description.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            'Описание',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.sidePanelTextMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
        ],
        if (isEmpty)
          Text(
            'Описание не добавлено',
            style: DdtTheme.style(
              fontSize: DdtTypography.bodySize,
              height: 1.55,
              color: DdtTheme.sidePanelTextMuted(context),
            ),
          )
        else
          DdtMarkdownBody(data: task.description),
      ],
    );
  }
}

/// Копия задачи для правой панели. Ссылки не пересылаются, чтобы смена
/// статуса или срока не перезаписывала их.
Task _parameterEdit(
  Task task, {
  TaskStatus? status,
  bool typeSpecified = false,
  int? typeId,
  bool typeObjectSpecified = false,
  TaskType? type,
  bool prioritySpecified = false,
  TaskPriority? priority,
  bool authorSpecified = false,
  int? authorId,
  bool executorSpecified = false,
  int? executorId,
  bool responsibleSpecified = false,
  int? responsibleId,
  DateTime? timeSet,
  bool timeStartSpecified = false,
  DateTime? timeStart,
  bool timeEndSpecified = false,
  DateTime? timeEnd,
  bool deadlineSpecified = false,
  DateTime? deadline,
  bool parentSpecified = false,
  TaskRef? parent,
  List<TaskRef>? children,
  List<TaskFieldValue>? fieldValues,
  List<TaskComponentRef>? components,
  TaskNotifications? notifications,
}) {
  return Task(
    id: task.id,
    key: task.key,
    title: task.title,
    status: status ?? task.status,
    typeId: typeSpecified ? typeId : task.typeId,
    type: typeObjectSpecified ? type : task.type,
    description: task.description,
    executorId: executorSpecified ? executorId : task.executorId,
    authorId: authorSpecified ? authorId : task.authorId,
    responsibleId: responsibleSpecified ? responsibleId : task.responsibleId,
    ownerId: task.ownerId,
    spaceId: task.spaceId,
    spaceKey: task.spaceKey,
    parentId: parentSpecified ? parent?.id : task.parentId,
    parent: parentSpecified ? parent : task.parent,
    children: children ?? task.children,
    timeSet: timeSet ?? task.timeSet,
    timeStart: timeStartSpecified ? timeStart : task.timeStart,
    timeEnd: timeEndSpecified ? timeEnd : task.timeEnd,
    deadline: deadlineSpecified ? deadline : task.deadline,
    priority: prioritySpecified ? priority : task.priority,
    deleted: task.deleted,
    archive: task.archive,
    comments: task.comments,
    fieldValues: fieldValues ?? task.fieldValues,
    components: components ?? task.components,
    notifications: notifications ?? task.notifications,
    queueRulesSpecified: true,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
  );
}

class _TaskRelationsBlock extends StatelessWidget {
  const _TaskRelationsBlock({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final parent = task.parent;
    final children = task.children;
    if (parent == null && children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Связи',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
        SizedBox(height: 8.h),
        if (parent != null)
          _TaskRelationLink(task: task, related: parent, role: 'Родитель'),
        for (final child in children)
          _TaskRelationLink(task: task, related: child, role: 'Дочерняя'),
      ],
    );
  }
}

class _TaskRelationLink extends StatelessWidget {
  const _TaskRelationLink({
    required this.task,
    required this.related,
    required this.role,
  });

  final Task task;
  final TaskRef related;
  final String role;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    final title = related.title.trim().isEmpty
        ? related.key
        : '${related.key} · ${related.title}';

    return InkWell(
      onTap: () => context.push(
        RoutePaths.forTask(
          taskKey: related.key,
          spaceId: task.spaceId,
          spaceKey: task.spaceKey,
        ),
      ),
      borderRadius: DdtTheme.radius,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          children: [
            DdtIcon(DdtIcons.link, size: 14.sp, color: accent),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              role,
              style: DdtTheme.style(
                fontSize: DdtTypography.captionSize,
                color: DdtTheme.sidePanelTextMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskParametersPanel extends StatelessWidget {
  const _TaskParametersPanel({
    required this.task,
    required this.pinned,
    required this.onChanged,
    this.scrollController,
  });

  final Task task;
  final bool pinned;
  final ValueChanged<Task> onChanged;
  final ScrollController? scrollController;

  List<Task> _candidates(List<Task> tasks) {
    final seen = <String>{};
    return [
      for (final item in tasks)
        if (item.id > 0 &&
            item.key.isNotEmpty &&
            item.key != task.key &&
            seen.add(item.key))
          item,
    ];
  }

  TaskRef _ref(Task item) {
    return TaskRef(
      id: item.id,
      key: item.key,
      title: item.title,
      status: item.status,
    );
  }

  void _setParent(String key, List<Task> candidates) {
    if (key.isEmpty) {
      onChanged(_parameterEdit(task, parentSpecified: true));
      return;
    }
    for (final item in candidates) {
      if (item.key != key) continue;
      onChanged(
        _parameterEdit(
          task,
          parentSpecified: true,
          parent: _ref(item),
          children: [
            for (final child in task.children)
              if (child.key != key) child,
          ],
        ),
      );
      return;
    }
  }

  void _toggleChild(String key, List<Task> candidates) {
    if (task.children.any((child) => child.key == key)) {
      onChanged(
        _parameterEdit(
          task,
          children: [
            for (final child in task.children)
              if (child.key != key) child,
          ],
        ),
      );
      return;
    }
    if (task.parent?.key == key) return;
    for (final item in candidates) {
      if (item.key != key) continue;
      onChanged(
        _parameterEdit(task, children: [...task.children, _ref(item)]),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<TasksBloc>();
    final personal = bloc.spaceKey == null;
    final candidates = _candidates(bloc.state.allTasks);
    final links = task.links ?? const <TaskLink>[];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskParametersForm(
          tintValues: true,
          personal: personal,
          statuses: bloc.state.boardStatuses,
          taskTypes: bloc.state.taskTypes,
          candidates: candidates,
          status: task.status,
          typeId: task.typeId,
          priority: task.priority,
          authorId: task.authorId,
          executorId: task.executorId,
          responsibleId: task.responsibleId,
          timeSet: task.timeSet,
          timeStart: task.timeStart,
          timeEnd: task.timeEnd,
          deadline: task.deadline,
          parent: task.parent,
          children: task.children,
          onStatus: (status) {
            final dated = applyTaskStatusDates(task, status);
            onChanged(
              _parameterEdit(
                task,
                status: dated.status,
                timeStart: dated.timeStart,
                timeStartSpecified: true,
                timeEnd: dated.timeEnd,
                timeEndSpecified: true,
              ),
            );
          },
          onType: (id) {
            TaskType? type;
            for (final item in bloc.state.taskTypes) {
              if (item.id == id) type = item;
            }
            onChanged(
              _parameterEdit(
                task,
                typeSpecified: true,
                typeId: id,
                typeObjectSpecified: true,
                type: type,
              ),
            );
          },
          onPriority: (value) => onChanged(
            _parameterEdit(
              task,
              prioritySpecified: true,
              priority: value,
            ),
          ),
          onAuthor: (id) => onChanged(
            _parameterEdit(task, authorSpecified: true, authorId: id),
          ),
          onExecutor: (id) => onChanged(
            _parameterEdit(task, executorSpecified: true, executorId: id),
          ),
          onResponsible: (id) => onChanged(
            _parameterEdit(
              task,
              responsibleSpecified: true,
              responsibleId: id,
            ),
          ),
          onTimeSet: (value) => onChanged(_parameterEdit(task, timeSet: value)),
          onTimeStart: (value) => onChanged(
            _parameterEdit(
              task,
              timeStartSpecified: true,
              timeStart: value,
            ),
          ),
          onTimeEnd: (value) => onChanged(
            _parameterEdit(task, timeEndSpecified: true, timeEnd: value),
          ),
          onDeadline: (value) => onChanged(
            _parameterEdit(
              task,
              deadlineSpecified: true,
              deadline: value,
            ),
          ),
          onParent: (key) => _setParent(key, candidates),
          onToggleChild: (key) => _toggleChild(key, candidates),
        ),
        TaskQueueRulesLoader(
          spaceKey: task.spaceKey ?? bloc.spaceKey,
          showNotifications: false,
          fieldValues: task.fieldValues,
          componentIds: [for (final item in task.components) item.id],
          notifications: task.notifications,
          onFieldValues: (values) => onChanged(
            _parameterEdit(task, fieldValues: values),
          ),
          onComponentIds: (ids) => onChanged(
            _parameterEdit(
              task,
              components: [
                for (final id in ids) TaskComponentRef(id: id, name: ''),
              ],
            ),
          ),
          onNotifications: (value) => onChanged(
            _parameterEdit(task, notifications: value),
          ),
        ),
        if (links.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Text(
            'Ссылки',
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              fontWeight: FontWeight.w600,
              color: DdtTheme.sidePanelTextMuted(context),
            ),
          ),
          SizedBox(height: 8.h),
          for (final link in links) ...[
            _LinkRow(link: link),
            SizedBox(height: 8.h),
          ],
        ],
      ],
    );

    if (!pinned) return content;

    return SizedBox(
      width: 400.w,
      child: SingleChildScrollView(
        controller: scrollController,
        primary: false,
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.w),
        child: content,
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});

  final TaskLink link;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
      borderRadius: DdtTheme.radius,
      child: Row(
        children: [
          DdtIcon(
            DdtIcons.link,
            size: 14.sp,
            color: accent,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              link.title?.trim().isNotEmpty == true ? link.title! : link.url,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSize,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DdtIcon(
            DdtIcons.arrowUpRight,
            size: 12.sp,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ],
      ),
    );
  }
}

