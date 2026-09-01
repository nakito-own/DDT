import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../models/task.dart';
import '../models/task_comment.dart';
import '../services/tasks_api.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import '../utils/task_formatters.dart';
import 'ddt_app_input.dart';
import '../theme/ddt_typography.dart';

class TaskCommentsSection extends StatefulWidget {
  const TaskCommentsSection({
    super.key,
    required this.task,
    this.compact = false,
    this.inputAtTop = false,
    this.expand = false,
    this.onTaskChanged,
  });

  final Task task;
  final bool compact;
  final bool inputAtTop;
  final bool expand;
  final ValueChanged<Task>? onTaskChanged;

  @override
  State<TaskCommentsSection> createState() => _TaskCommentsSectionState();
}

class _TaskCommentsSectionState extends State<TaskCommentsSection> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late List<TaskComment> _comments;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _comments = _sortedComments(widget.task.comments);
    _controller.addListener(_handleDraftChanged);
  }

  @override
  void didUpdateWidget(covariant TaskCommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id ||
        oldWidget.task.comments != widget.task.comments) {
      _comments = _sortedComments(widget.task.comments);
    }
  }

  List<TaskComment> _sortedComments(List<TaskComment> comments) {
    final sorted = List<TaskComment>.of(comments);
    sorted.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleDraftChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleDraftChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final comment = await TasksApi(
        spaceId: widget.task.spaceId,
      ).addComment(widget.task.id, text);
      if (!mounted) return;

      _controller.clear();
      setState(() {
        _comments = _sortedComments([comment, ..._comments]);
        _isSending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });

      final updated = widget.task.copyWith(comments: _comments);
      widget.onTaskChanged?.call(updated);
      context.read<TasksBloc>().add(TaskServerSnapshotReceived(updated));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      DdtToast.show(
        message: error.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
        title: 'Комментарий не отправлен',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.select<AuthBloc, int?>((bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated ? state.user.id : null;
    });

    final header = Row(
      children: [
        Expanded(
          child: Text(
            'Комментарии',
            style: DdtTheme.style(
              fontSize: widget.compact
                  ? DdtTypography.bodySize
                  : DdtTypography.sectionTitleSize,
              fontWeight: FontWeight.w700,
              color: DdtTheme.sidePanelTextPrimary(context),
            ),
          ),
        ),
        Text(
          _comments.length.toString(),
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSmallSize,
            color: DdtTheme.sidePanelTextMuted(context),
          ),
        ),
      ],
    );

    final input = _buildInput();
    final comments = _buildCommentsList(currentUserId);

    final horizontalPadding = widget.expand
        ? EdgeInsets.symmetric(horizontal: 20.w)
        : EdgeInsets.zero;

    if (widget.expand) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: horizontalPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                SizedBox(height: 12.h),
                if (widget.inputAtTop) input,
              ],
            ),
          ),
          if (widget.inputAtTop) SizedBox(height: 12.h),
          Expanded(
            child: Padding(padding: horizontalPadding, child: comments),
          ),
          if (!widget.inputAtTop) ...[
            Padding(padding: horizontalPadding, child: input),
            SizedBox(height: 12.h),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: 12.h),
        if (widget.inputAtTop) ...[input, SizedBox(height: 12.h)],
        comments,
        if (!widget.inputAtTop) ...[SizedBox(height: 8.h), input],
      ],
    );
  }

  Widget _buildInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canSend = !_isSending && _controller.text.trim().isNotEmpty;
    final disabledButtonColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final sendButton = Tooltip(
      message: 'Отправить комментарий',
      child: SizedBox.square(
        dimension: 34,
        child: IconButton(
          onPressed: canSend ? _send : null,
          style: IconButton.styleFrom(
            backgroundColor: canSend ? AppColors.primary : disabledButtonColor,
            foregroundColor: Colors.white,
            disabledForegroundColor: DdtTheme.sidePanelTextMuted(context),
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: _isSending
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(CupertinoIcons.arrow_up, size: 17),
        ),
      ),
    );

    return DdtAppInput(
      hint: 'Написать комментарий…',
      controller: _controller,
      focusNode: _focusNode,
      variant: DdtInputVariant.standard,
      minLines: 1,
      maxLines: 4,
      contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      borderRadius: BorderRadius.circular(14.r),
      textInputAction: TextInputAction.newline,
      textColor: DdtTheme.sidePanelTextPrimary(context),
      readOnly: _isSending,
      suffix: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: sendButton,
      ),
    );
  }

  Widget _buildCommentsList(int? currentUserId) {
    if (_comments.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: Text(
            'Комментариев пока нет. Начните обсуждение задачи.',
            textAlign: TextAlign.center,
            style: DdtTheme.style(
              fontSize: DdtTypography.labelSize,
              color: DdtTheme.sidePanelTextMuted(context),
            ),
          ),
        ),
      );
    }

    final list = [
      for (final comment in _comments)
        _CommentBubble(
          comment: comment,
          isOwn: comment.authorId == currentUserId,
        ),
    ];

    if (widget.expand) {
      return ListView(
        padding: EdgeInsets.only(bottom: 16.h),
        children: list,
      );
    }

    return Column(children: list);
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment, required this.isOwn});

  final TaskComment comment;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: widgetMaxWidth(context)),
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isOwn
              ? primary.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12.r),
            topRight: Radius.circular(12.r),
            bottomLeft: Radius.circular(isOwn ? 12.r : 3.r),
            bottomRight: Radius.circular(isOwn ? 3.r : 12.r),
          ),
          border: Border.all(
            color: isOwn
                ? primary.withValues(alpha: 0.28)
                : DdtTheme.sidePanelDivider(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.person_crop_circle_fill,
                  size: 15.sp,
                  color: isOwn ? primary : DdtTheme.sidePanelTextMuted(context),
                ),
                SizedBox(width: 6.w),
                Text(
                  isOwn
                      ? 'Вы'
                      : formatUserRef(
                          comment.authorId,
                          fallback: 'Пользователь',
                        ),
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSmallSize,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.sidePanelTextSecondary(context),
                  ),
                ),
                if (comment.createdAt != null) ...[
                  SizedBox(width: 10.w),
                  Text(
                    formatTaskDateTime(comment.createdAt!.toLocal()),
                    style: DdtTheme.style(
                      fontSize: DdtTypography.microSize,
                      color: DdtTheme.sidePanelTextMuted(context),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 6.h),
            SelectableText(
              comment.text,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSize,
                height: 1.4,
                color: DdtTheme.sidePanelTextPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double widgetMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 700 ? width * 0.78 : 520.w;
  }
}
