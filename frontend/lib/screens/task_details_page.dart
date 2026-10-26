import 'dart:async';

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
import '../models/task.dart';
import '../models/task_link.dart';
import '../router/route_paths.dart';
import '../services/tasks_api.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import '../models/user_profile.dart';
import '../services/directory_users.dart';
import '../utils/task_formatters.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_user_chip.dart';
import '../widgets/task_comments_section.dart';
import '../widgets/task_side_panel.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_markdown_body.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_side_panel_divider.dart';

class TaskDetailsPage extends StatefulWidget {
  const TaskDetailsPage({super.key, required this.taskKey, this.spaceKey});

  final String taskKey;
  final String? spaceKey;

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  Task? _task;
  bool _isLoading = true;
  String? _error;
  var _restored = false;

  Task? _knownTask() {
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

    final updated = await showTaskSidePanel(
      context,
      mode: TaskSidePanelMode.view,
      task: task,
      taskTypes: context.read<TasksBloc>().state.taskTypes,
    );
    if (updated == null || !mounted) return;

    setState(() => _task = updated);
    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: task, updated: updated),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TasksBloc, TasksState>(
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
              )
            : SingleChildScrollView(
                padding: DdtShellMetrics.scrollPadding(
                  context,
                  base: EdgeInsets.fromLTRB(
                    20.w,
                    12.h,
                    20.w,
                    24.h + DdtShellMetrics.contentBottomPadding(context),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TaskHeader(task: task, onEdit: _editTask),
                    SizedBox(height: 16.h),
                    _TaskDescription(task: task),
                    SizedBox(height: 20.h),
                    _TaskParametersPanel(task: task, pinned: false),
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
  });

  final Task task;
  final VoidCallback onEdit;
  final ValueChanged<Task> onTaskChanged;

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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
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
          width: 300.w,
          child: Padding(
            padding: EdgeInsets.only(top: topInset, bottom: floatingBottom),
            child: Listener(
              onPointerSignal: _onPanelPointerSignal,
              child: _TaskParametersPanel(
                task: widget.task,
                pinned: true,
                scrollController: _panelScroll,
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
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 0, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TaskDescription(task: task, showHeading: false),
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
          ),
        ],
      ),
    );
  }
}

/// Toolbar sits on the solid fade. The title is the last layer of the same
/// stack and continues a little past the gradient.
class _PinnedTaskChrome extends StatelessWidget {
  const _PinnedTaskChrome({
    required this.topInset,
    required this.task,
    required this.onEdit,
  });

  final double topInset;
  final Task task;
  final VoidCallback onEdit;

  /// How far the title hangs below the gradient.
  static const double _titlePastGradient = 12;

  static const double _fadeTail = 28;

  @override
  Widget build(BuildContext context) {
    final background = DdtTheme.scaffoldBackground(context);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: _titlePastGradient.h,
          child: IgnorePointer(
            child: _TaskHeaderFade(color: background, fadeTail: _fadeTail.h),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, topInset + 12.h, 20.w, 0),
          child: _TaskHeader(task: task, onEdit: onEdit, fullscreen: true),
        ),
      ],
    );
  }
}

class _TaskHeaderFade extends StatelessWidget {
  const _TaskHeaderFade({required this.color, required this.fadeTail});

  final Color color;
  final double fadeTail;

  @override
  Widget build(BuildContext context) {
    final solid = color.withValues(alpha: 1);
    final clear = color.withValues(alpha: 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final solidStop = height <= 0
            ? 0.7
            : ((height - fadeTail) / height).clamp(0.0, 1.0);

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
    final title = Text(
      task.title,
      style: DdtTheme.style(
        fontSize: DdtTypography.entityTitleSize,
        fontWeight: FontWeight.w700,
        color: DdtTheme.sidePanelTextPrimary(context),
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
            _TaskBackButton(task: task),
            SizedBox(width: 4.w),
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
        SizedBox(height: 10.h),
        title,
      ],
    );
  }
}

class _TaskBackButton extends StatelessWidget {
  const _TaskBackButton({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    // Avoid IconButton.tooltip (OverlayPortal): navigating/resizing while
    // the tooltip is open trips Flutter's `size == theater.size` assert.
    return Semantics(
      button: true,
      label: 'Назад к задачам',
      child: IconButton(
        onPressed: () {
          Tooltip.dismissAllToolTips();
          _leaveTask(context, task);
        },
        icon: DdtIcon(DdtIcons.back),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Painted height of the fullscreen chevron and edit icon.
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
        _TaskMarkButton(
          icon: DdtIcons.chevronLeft,
          label: 'Назад к задачам',
          onPressed: () => _leaveTask(context, widget.task),
        ),
        SizedBox(width: 6.w),
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

void openTaskDetailsPage(
  BuildContext context,
  Task task, {
  VoidCallback? onSheetClosed,
}) {
  if (DdtAdaptive.isCompact(context)) {
    unawaited(_openTaskSheet(context, task, onSheetClosed));
    return;
  }

  final taskKey = task.key.isNotEmpty
      ? task.key
      : (task.id > 0 ? task.id.toString() : '');
  if (taskKey.isEmpty) return;

  final taskSpace = task.spaceKey;
  final spaceKey = taskSpace != null && taskSpace.isNotEmpty
      ? taskSpace
      : context.read<TasksBloc>().spaceKey;
  context.push(
    RoutePaths.forTask(
      taskKey: taskKey,
      spaceId: task.spaceId,
      spaceKey: spaceKey,
    ),
    extra: task,
  );
}

Future<void> _openTaskSheet(
  BuildContext context,
  Task task,
  VoidCallback? onSheetClosed,
) async {
  final chrome = DdtFloatingChrome.read(context);
  chrome?.hold();
  final tasksBloc = context.read<TasksBloc>();
  final surface = Theme.of(context).brightness == Brightness.dark
      ? DdtTheme.darkSurface
      : DdtTheme.lightSurface;

  final updated = await showModalBottomSheet<Task>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: surface,
    builder: (sheetContext) {
      final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: BlocProvider.value(
          value: tasksBloc,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: constraints.maxHeight * 0.94,
                child: TaskSidePanel(
                  mode: TaskSidePanelMode.view,
                  task: task,
                  taskTypes: tasksBloc.state.taskTypes,
                  personal: tasksBloc.spaceKey == null,
                  relatedTasks: tasksBloc.state.allTasks,
                ),
              );
            },
          ),
        ),
      );
    },
  ).whenComplete(() => chrome?.release());
  if (!context.mounted) return;
  if (updated != null) {
    context.read<TasksBloc>().add(
      TaskUpdateRequested(original: task, updated: updated),
    );
  }
  onSheetClosed?.call();
}

void _leaveTask(BuildContext context, Task task) {
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

class _TaskParametersPanel extends StatelessWidget {
  const _TaskParametersPanel({
    required this.task,
    required this.pinned,
    this.scrollController,
  });

  final Task task;
  final bool pinned;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final content = Column(
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
        _ParametersTable(
          rows: [
            _ParameterTableRow(
              label: 'Статус',
              value: _ParameterBadge(
                label: task.status.label,
                color: statusColumnColor(task.status),
              ),
            ),
            _ParameterTableRow(
              label: 'Тип',
              value: task.type == null
                  ? const _MutedValue(text: 'Не указан')
                  : _ParameterBadge(
                      label: task.type!.name,
                      color: taskTypeColor(task.type!.id),
                    ),
            ),
            _ParameterTableRow(
              label: 'Приоритет',
              value: task.priority == null
                  ? const _MutedValue(text: 'Не указан')
                  : _ParameterBadge(
                      label: task.priority!.label,
                      color: priorityColor(task.priority!),
                    ),
            ),
            _ParameterTableRow(
              label: 'Автор',
              value: _TaskPersonValue(userId: task.authorId),
            ),
            _ParameterTableRow(
              label: 'Исполнитель',
              value: _TaskPersonValue(userId: task.executorId),
            ),
            _ParameterTableRow(
              label: 'Ответственный',
              value: _TaskPersonValue(userId: task.responsibleId),
            ),
            _ParameterTableRow(
              label: 'Создана',
              value: Text(
                formatTaskDateTime(task.timeSet.toLocal()),
                style: _tableValueStyle(context),
              ),
            ),
            _ParameterTableRow(
              label: 'Начало',
              value: Text(
                task.timeStart == null
                    ? 'Не указано'
                    : formatTaskDateTime(task.timeStart!.toLocal()),
                style: _tableValueStyle(context, muted: task.timeStart == null),
              ),
            ),
            _ParameterTableRow(
              label: 'Окончание',
              value: Text(
                task.timeEnd == null
                    ? 'Не указано'
                    : formatTaskDateTime(task.timeEnd!.toLocal()),
                style: _tableValueStyle(context, muted: task.timeEnd == null),
              ),
            ),
            _ParameterTableRow(
              label: 'Родитель',
              value: task.parent == null
                  ? const _MutedValue(text: 'Нет')
                  : _TaskKeyLink(taskKey: task.parent!.key, title: task.parent!.title),
            ),
            _ParameterTableRow(
              label: 'Дочерние',
              value: task.children.isEmpty
                  ? const _MutedValue(text: 'Нет')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final child in task.children)
                          _TaskKeyLink(taskKey: child.key, title: child.title),
                      ],
                    ),
            ),
            _ParameterTableRow(
              label: 'Дедлайн',
              value: Text(
                task.deadline == null
                    ? 'Не указан'
                    : formatTaskDateTime(task.deadline!.toLocal()),
                style: _tableValueStyle(context, muted: task.deadline == null),
              ),
              isLast: task.links == null || task.links!.isEmpty,
            ),
            if (task.links != null && task.links!.isNotEmpty)
              for (var i = 0; i < task.links!.length; i++)
                _ParameterTableRow(
                  label: i == 0 ? 'Ссылки' : '',
                  value: _LinkRow(link: task.links![i]),
                  isLast: i == task.links!.length - 1,
                ),
          ],
        ),
      ],
    );

    if (!pinned) return content;

    return SizedBox(
      width: 300.w,
      child: SingleChildScrollView(
        controller: scrollController,
        primary: false,
        padding: EdgeInsets.all(20.w),
        child: content,
      ),
    );
  }
}

TextStyle _tableValueStyle(BuildContext context, {bool muted = false}) {
  return DdtTheme.style(
    fontSize: DdtTypography.labelSize,
    fontWeight: FontWeight.w500,
    color: muted
        ? DdtTheme.sidePanelTextMuted(context)
        : DdtTheme.sidePanelTextPrimary(context),
  );
}

class _ParametersTable extends StatelessWidget {
  const _ParametersTable({required this.rows});

  final List<_ParameterTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final labelStyle = DdtTheme.style(
      fontSize: DdtTypography.labelSmallSize,
      fontWeight: FontWeight.w600,
      color: DdtTheme.sidePanelTextMuted(context),
    );

    return Table(
      columnWidths: {0: FixedColumnWidth(108.w), 1: const FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (var i = 0; i < rows.length; i++)
          TableRow(
            decoration: BoxDecoration(
              border: rows[i].isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: DdtTheme.sidePanelDivider(context),
                      ),
                    ),
            ),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(0, 10.h, 12.w, 10.h),
                child: Text(rows[i].label, style: labelStyle),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: rows[i].value,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TaskPersonValue extends StatelessWidget {
  const _TaskPersonValue({required this.userId});

  final int? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const _MutedValue(text: 'Не указан');
    }

    return FutureBuilder<List<UserProfile>>(
      future: loadDirectoryUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <UserProfile>[];
        final person = directoryUserById(users, userId);
        final waiting =
            snapshot.connectionState == ConnectionState.waiting &&
            person == null;
        return Align(
          alignment: Alignment.centerLeft,
          child: DdtUserChip(
            name: person?.label ?? (waiting ? 'Загрузка…' : 'Пользователь'),
            userId: person?.id ?? userId,
          ),
        );
      },
    );
  }
}

class _ParameterTableRow {
  const _ParameterTableRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final Widget value;
  final bool isLast;
}

class _TaskKeyLink extends StatelessWidget {
  const _TaskKeyLink({required this.taskKey, required this.title});

  final String taskKey;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;
    return InkWell(
      onTap: taskKey.isEmpty ? null : () => context.go(RoutePaths.task(taskKey)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Text(
          title.isEmpty ? taskKey : '$taskKey · $title',
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
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

class _MutedValue extends StatelessWidget {
  const _MutedValue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _tableValueStyle(context, muted: true));
  }
}

class _ParameterBadge extends StatelessWidget {
  const _ParameterBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? Color.lerp(color, Colors.white, 0.36)!
        : Color.lerp(color, Colors.black, 0.14)!;
    final dotColor = isDark
        ? Color.lerp(color, Colors.white, 0.22)!
        : color;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: DdtTheme.badgeBorderRadius,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.38 : 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSmallSize,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
