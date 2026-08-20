import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../models/task_link.dart';
import '../router/route_paths.dart';
import '../services/tasks_api.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import '../widgets/task_comments_section.dart';
import '../widgets/task_side_panel.dart';

class TaskDetailsPage extends StatefulWidget {
  const TaskDetailsPage({super.key, required this.taskId, this.spaceId});

  final int taskId;
  final int? spaceId;

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  Task? _task;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  @override
  void didUpdateWidget(covariant TaskDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId ||
        oldWidget.spaceId != widget.spaceId) {
      _loadTask();
    }
  }

  Future<void> _loadTask() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final task = await TasksApi(
        spaceId: widget.spaceId,
      ).fetchTask(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = task;
        _isLoading = false;
      });
      context.read<TasksBloc>().add(TaskServerSnapshotReceived(task));
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
              if (task.id == widget.taskId) return task;
            }
          }
          return null;
        }

        return findTask(previous) != findTask(current);
      },
      listener: (context, state) {
        final index = state.allTasks.indexWhere(
          (task) => task.id == widget.taskId,
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
            Icon(
              CupertinoIcons.exclamationmark_triangle,
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

        return DdtTheme.glass(
          context: context,
          padding: EdgeInsets.zero,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _TaskMainContent(
                        task: task,
                        onEdit: _editTask,
                        onTaskChanged: (updated) {
                          setState(() => _task = updated);
                        },
                      ),
                    ),
                    Container(
                      width: 1,
                      color: DdtTheme.sidePanelDivider(context),
                    ),
                    _TaskParametersPanel(task: task, pinned: true),
                  ],
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
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
                ),
        );
      },
    );
  }

  String get _backRoute => widget.spaceId == null
      ? RoutePaths.tasksKanban
      : RoutePaths.spaceKanbanFor(widget.spaceId!);
}

class _TaskMainContent extends StatelessWidget {
  const _TaskMainContent({
    required this.task,
    required this.onEdit,
    required this.onTaskChanged,
  });

  final Task task;
  final VoidCallback onEdit;
  final ValueChanged<Task> onTaskChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TaskHeader(task: task, onEdit: onEdit),
              SizedBox(height: 16.h),
              _TaskDescription(task: task),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Divider(
            height: 32.h,
            thickness: 1,
            color: DdtTheme.sidePanelDivider(context),
          ),
        ),
        Expanded(
          child: TaskCommentsSection(
            key: ValueKey('task-comments-${task.id}'),
            task: task,
            inputAtTop: true,
            expand: true,
            onTaskChanged: onTaskChanged,
          ),
        ),
      ],
    );
  }
}

class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.task, required this.onEdit});

  final Task task;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: 'Назад к задачам',
          onPressed: () => context.go(
            task.spaceId == null
                ? RoutePaths.tasksKanban
                : RoutePaths.spaceKanbanFor(task.spaceId!),
          ),
          icon: const Icon(CupertinoIcons.back),
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Задача #${task.id}',
                style: DdtTheme.style(
                  fontSize: 12.sp,
                  color: DdtTheme.sidePanelTextMuted(context),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                task.title,
                style: DdtTheme.style(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: DdtTheme.sidePanelTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Button(
          text: 'Редактировать',
          onPressed: onEdit,
          borderRadius: DdtTheme.radius,
        ),
      ],
    );
  }
}

class _TaskDescription extends StatelessWidget {
  const _TaskDescription({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final isEmpty = task.description.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Описание',
          style: DdtTheme.style(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
        SizedBox(height: 8.h),
        SelectableText(
          isEmpty ? 'Описание не добавлено' : task.description,
          style: DdtTheme.style(
            fontSize: 14.sp,
            height: 1.55,
            color: isEmpty
                ? DdtTheme.sidePanelTextMuted(context)
                : DdtTheme.sidePanelTextPrimary(context),
          ),
        ),
      ],
    );
  }
}

class _TaskParametersPanel extends StatelessWidget {
  const _TaskParametersPanel({required this.task, required this.pinned});

  final Task task;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Параметры',
          style: DdtTheme.style(
            fontSize: 13.sp,
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
              value: Text(
                formatUserRef(task.authorId, fallback: 'Не указан'),
                style: _tableValueStyle(context),
              ),
            ),
            _ParameterTableRow(
              label: 'Исполнитель',
              value: Text(
                formatUserRef(task.executorId, fallback: 'Не указан'),
                style: _tableValueStyle(context),
              ),
            ),
            _ParameterTableRow(
              label: 'Ответственный',
              value: Text(
                formatUserRef(task.responsibleId, fallback: 'Не указан'),
                style: _tableValueStyle(context),
              ),
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
        padding: EdgeInsets.all(20.w),
        child: content,
      ),
    );
  }
}

TextStyle _tableValueStyle(BuildContext context, {bool muted = false}) {
  return DdtTheme.style(
    fontSize: 13.sp,
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
      fontSize: 12.sp,
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

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});

  final TaskLink link;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication),
      borderRadius: DdtTheme.radius,
      child: Row(
        children: [
          Icon(
            CupertinoIcons.link,
            size: 14.sp,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              link.title?.trim().isNotEmpty == true ? link.title! : link.url,
              style: DdtTheme.style(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            CupertinoIcons.arrow_up_right,
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: DdtTheme.style(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
