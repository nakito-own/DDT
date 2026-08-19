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
import '../utils/task_formatters.dart';

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
  late List<TaskComment> _comments;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _comments = _sortedComments(widget.task.comments);
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
    _controller.dispose();
    super.dispose();
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

      setState(() {
        _comments = _sortedComments([comment, ..._comments]);
        _controller.clear();
        _isSending = false;
      });

      final updated = widget.task.copyWith(comments: _comments);
      widget.onTaskChanged?.call(updated);
      context.read<TasksBloc>().add(TaskServerSnapshotReceived(updated));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      Toast.show(
        message: error.toString().replaceFirst('Exception: ', ''),
        type: ToastType.error,
        title: 'Комментарий не отправлен',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : null;

    final header = Row(
      children: [
        Expanded(
          child: Text(
            'Комментарии',
            style: DdtTheme.style(
              fontSize: widget.compact ? 14.sp : 17.sp,
              fontWeight: FontWeight.w700,
              color: DdtTheme.sidePanelTextPrimary(context),
            ),
          ),
        ),
        Text(
          _comments.length.toString(),
          style: DdtTheme.style(
            fontSize: 12.sp,
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
    final sendButton = SizedBox(
      width: 36.w,
      height: 36.w,
      child: IconButton.filled(
        tooltip: 'Отправить',
        onPressed: _isSending ? null : _send,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: Size(36.w, 36.w),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: _isSending
            ? SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(CupertinoIcons.arrow_up, size: 17.sp),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 6.h, 6.w, 6.h),
      decoration: BoxDecoration(
        color: DdtTheme.inputFillColor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: DdtTheme.inputBorderColor(context).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.newline,
              style: DdtTheme.style(
                fontSize: 14.sp,
                color: DdtTheme.sidePanelTextPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Написать комментарий…',
                hintStyle: DdtTheme.inputHintStyle(context),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6.w,
                  vertical: 8.h,
                ),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          sendButton,
        ],
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
              fontSize: 13.sp,
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.sidePanelTextSecondary(context),
                  ),
                ),
                if (comment.createdAt != null) ...[
                  SizedBox(width: 10.w),
                  Text(
                    formatTaskDateTime(comment.createdAt!.toLocal()),
                    style: DdtTheme.style(
                      fontSize: 10.sp,
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
                fontSize: 13.sp,
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
