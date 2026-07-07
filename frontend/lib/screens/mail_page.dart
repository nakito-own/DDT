import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../blocs/mail/mail_bloc.dart';
import '../models/mail_inbox_options.dart';
import '../models/mail_message.dart';
import '../theme/ddt_theme.dart';
import '../widgets/compose_mail_panel.dart';
import '../widgets/ddt_context_menu.dart';
import '../widgets/ddt_glass_fab.dart';
import '../widgets/ddt_tappable.dart';
import '../widgets/mail_body_view.dart';

class MailPage extends StatefulWidget {
  const MailPage({super.key});

  @override
  State<MailPage> createState() => _MailPageState();
}

class _MailPageState extends State<MailPage> {
  @override
  void initState() {
    super.initState();
    // MailBloc уже создан в main.dart; запрашиваем загрузку входящих.
    context.read<MailBloc>().add(const MailInboxLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
          children: [
            BlocBuilder<MailBloc, MailState>(
              buildWhen: (previous, current) =>
                  previous.isLoading != current.isLoading ||
                  previous.errorMessage != current.errorMessage ||
                  previous.messages.isEmpty != current.messages.isEmpty,
              builder: (context, state) {
                if (state.isLoading && state.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.errorMessage != null && state.messages.isEmpty) {
                  return _ErrorState(
                    message: state.errorMessage!,
                    onRetry: () => context
                        .read<MailBloc>()
                        .add(const MailInboxLoadRequested()),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => context
                      .read<MailBloc>()
                      .add(const MailInboxRefreshRequested()),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: const _MailList()),
                      SizedBox(width: 16.w),
                      Expanded(flex: 7, child: const _MailDetail()),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: 24.w,
              bottom: 24.h,
              child: DdtGlassFab(
                onPressed: () => showComposeMailPanel(context),
                icon: Icons.edit_outlined,
                label: 'Написать',
              ),
            ),
          ],
        );
  }
}

class _MailList extends StatefulWidget {
  const _MailList();

  @override
  State<_MailList> createState() => _MailListState();
}

class _MailListState extends State<_MailList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) return;

    _requestLoadMore();
  }

  void _requestLoadMore() {
    final bloc = context.read<MailBloc>();
    final state = bloc.state;
    if (state.isLoading ||
        state.isRefreshingInbox ||
        state.isLoadingMore ||
        !state.hasMoreMessages ||
        state.messages.isEmpty) {
      return;
    }

    bloc.add(const MailInboxLoadMoreRequested());
  }

  void _scheduleLoadMoreIfNotScrollable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final position = _scrollController.position;
      if (position.maxScrollExtent > 0) return;

      _requestLoadMore();
    });
  }

  List<DdtContextMenuItem> _filterMenuItems(MailInboxFilter selected) {
    final bloc = context.read<MailBloc>();

    DdtContextMenuItem item(MailInboxFilter filter, IconData icon) {
      return DdtContextMenuItem(
        icon: icon,
        label: filter.label,
        isSelected: selected == filter,
        onTap: () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
          bloc.add(MailInboxQueryChanged(filter: filter));
        },
      );
    }

    return [
      item(MailInboxFilter.all, CupertinoIcons.tray),
      item(MailInboxFilter.toMe, CupertinoIcons.person),
      item(MailInboxFilter.flagged, CupertinoIcons.flag),
      item(MailInboxFilter.mentions, CupertinoIcons.at),
    ];
  }

  List<DdtContextMenuItem> _sortMenuItems(MailInboxSort selected) {
    final bloc = context.read<MailBloc>();

    DdtContextMenuItem item(MailInboxSort sort, IconData icon) {
      return DdtContextMenuItem(
        icon: icon,
        label: sort.label,
        isSelected: selected == sort,
        onTap: () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
          bloc.add(MailInboxQueryChanged(sort: sort));
        },
      );
    }

    return [
      item(MailInboxSort.dateAsc, CupertinoIcons.arrow_up),
      item(MailInboxSort.dateDesc, CupertinoIcons.arrow_down),
      item(MailInboxSort.fromAddress, CupertinoIcons.person_crop_circle),
      item(MailInboxSort.toAddress, CupertinoIcons.envelope),
      item(MailInboxSort.subject, CupertinoIcons.textformat),
      item(MailInboxSort.attachments, CupertinoIcons.paperclip),
      item(MailInboxSort.importance, CupertinoIcons.exclamationmark_triangle),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MailBloc, MailState>(
      listenWhen: (previous, current) =>
          previous.messages.length != current.messages.length ||
          previous.isLoadingMore != current.isLoadingMore ||
          previous.isRefreshingInbox != current.isRefreshingInbox ||
          previous.hasMoreMessages != current.hasMoreMessages,
      listener: (context, state) {
        if (state.hasMoreMessages &&
            !state.isLoadingMore &&
            !state.isRefreshingInbox &&
            !state.isLoading) {
          _scheduleLoadMoreIfNotScrollable();
        }
      },
      child: DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<MailBloc, MailState>(
            buildWhen: (previous, current) =>
                previous.folders != current.folders ||
                previous.filter != current.filter ||
                previous.sort != current.sort ||
                previous.isRefreshingInbox != current.isRefreshingInbox ||
                previous.inboxQueryErrorMessage !=
                    current.inboxQueryErrorMessage,
            builder: (context, state) {
              final folders = state.folders;
              final subtitle = folders == null
                  ? 'Загрузка...'
                  : 'Входящие: ${folders.inbox} · Отправленные: ${folders.sent}';
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subtitle,
                          style: DdtTheme.style(
                            fontSize: 13.sp,
                            color: DdtTheme.taskCardTextSecondary(context),
                          ),
                        ),
                        if (state.inboxQueryErrorMessage != null) ...[
                          SizedBox(height: 4.h),
                          Text(
                            state.inboxQueryErrorMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DdtTheme.style(
                              fontSize: 11.sp,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (state.isRefreshingInbox)
                    Padding(
                      padding: EdgeInsets.only(right: 6.w),
                      child: SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  _MailListMenuButton(
                    tooltip: 'Фильтр',
                    icon: CupertinoIcons.line_horizontal_3_decrease,
                    items: _filterMenuItems(state.filter),
                    placement: DdtContextMenuPlacement.belowEnd,
                  ),
                  SizedBox(width: 4.w),
                  _MailListMenuButton(
                    tooltip: 'Сортировка',
                    icon: CupertinoIcons.arrow_up_arrow_down,
                    items: _sortMenuItems(state.sort),
                    placement: DdtContextMenuPlacement.belowEnd,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 12.h),
          Expanded(
            child: BlocBuilder<MailBloc, MailState>(
              buildWhen: (previous, current) =>
                  previous.messages != current.messages ||
                  previous.selectedMessage?.id !=
                      current.selectedMessage?.id ||
                  previous.isLoadingMore != current.isLoadingMore ||
                  previous.isRefreshingInbox != current.isRefreshingInbox ||
                  previous.hasMoreMessages != current.hasMoreMessages ||
                  previous.loadMoreErrorMessage !=
                      current.loadMoreErrorMessage,
              builder: (context, state) {
                final messages = state.messages;
                final selectedId = state.selectedMessage?.id;

                if (messages.isEmpty) {
                  if (state.isLoading || state.isRefreshingInbox) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Center(
                    child: Text(
                      'Входящие пусты',
                      style: DdtTheme.style(fontSize: 14.sp),
                    ),
                  );
                }

                final showFooter = state.isLoadingMore ||
                    state.isRefreshingInbox ||
                    state.hasMoreMessages ||
                    state.loadMoreErrorMessage != null;

                final listView = ListView.separated(
                  controller: _scrollController,
                  cacheExtent: 480,
                  itemCount: messages.length + (showFooter ? 1 : 0),
                  separatorBuilder: (context, index) {
                    if (index >= messages.length - 1) {
                      return const SizedBox.shrink();
                    }
                    return SizedBox(height: 8.h);
                  },
                  itemBuilder: (context, index) {
                    if (index >= messages.length) {
                      return _MailListFooter(
                        isLoading:
                            state.isLoadingMore || state.isRefreshingInbox,
                        hasMore: state.hasMoreMessages,
                        errorMessage: state.loadMoreErrorMessage,
                        onRetry: () => context
                            .read<MailBloc>()
                            .add(const MailInboxLoadMoreRequested()),
                      );
                    }

                    final message = messages[index];
                    return MailListItem(
                      key: ValueKey(message.id),
                      message: message,
                      selected: message.id == selectedId,
                      onTap: () => context
                          .read<MailBloc>()
                          .add(MailMessageSelected(message)),
                    );
                  },
                );

                return _MailListRefreshAnimation(
                  isRefreshing: state.isRefreshingInbox,
                  child: listView,
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _MailListRefreshAnimation extends StatelessWidget {
  const _MailListRefreshAnimation({
    required this.isRefreshing,
    required this.child,
  });

  final bool isRefreshing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isRefreshing ? 0.985 : 1,
      alignment: Alignment.topCenter,
      duration: DdtTheme.selectionAnimationDuration,
      curve: DdtTheme.selectionAnimationCurve,
      child: AnimatedOpacity(
        opacity: isRefreshing ? 0.20 : 1,
        duration: DdtTheme.selectionAnimationDuration,
        curve: DdtTheme.selectionAnimationCurve,
        child: child,
      ),
    );
  }
}

class _MailListMenuButton extends StatefulWidget {
  const _MailListMenuButton({
    required this.tooltip,
    required this.icon,
    required this.items,
    this.placement = DdtContextMenuPlacement.belowCenter,
  });

  final String tooltip;
  final IconData icon;
  final List<DdtContextMenuItem> items;
  final DdtContextMenuPlacement placement;

  @override
  State<_MailListMenuButton> createState() => _MailListMenuButtonState();
}

class _MailListMenuButtonState extends State<_MailListMenuButton> {
  final _anchorKey = GlobalKey();

  void _openMenu() {
    showDdtContextMenu(
      context: context,
      anchorKey: _anchorKey,
      items: widget.items,
      placement: widget.placement,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : AppColors.primary;

    return KeyedSubtree(
      key: _anchorKey,
      child: IconButton(
        tooltip: widget.tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.all(4.w),
        constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.w),
        onPressed: _openMenu,
        icon: Icon(
          widget.icon,
          color: foregroundColor.withValues(alpha: 0.85),
          size: 18.sp,
        ),
      ),
    );
  }
}

class _MailListFooter extends StatelessWidget {
  const _MailListFooter({
    required this.isLoading,
    required this.hasMore,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Column(
          children: [
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: DdtTheme.style(
                fontSize: 12.sp,
                color: DdtTheme.taskCardTextSecondary(context),
              ),
            ),
            SizedBox(height: 8.h),
            Button(
              text: 'Повторить',
              onPressed: onRetry,
              borderRadius: DdtTheme.radius,
            ),
          ],
        ),
      );
    }

    if (hasMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Center(
          child: Text(
            'Прокрутите вниз, чтобы загрузить ещё',
            style: DdtTheme.style(
              fontSize: 12.sp,
              color: DdtTheme.taskCardTextSecondary(context),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _MailDetail extends StatelessWidget {
  const _MailDetail();

  @override
  Widget build(BuildContext context) {
    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(20.w),
      child: BlocBuilder<MailBloc, MailState>(
        buildWhen: (previous, current) =>
            previous.selectedMessage != current.selectedMessage ||
            previous.isLoadingDetail != current.isLoadingDetail,
        builder: (context, state) {
          final message = state.selectedMessage;
          if (message == null) {
            return Center(
              child: Text(
                'Выберите письмо',
                style: DdtTheme.style(fontSize: 15.sp),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MailDetailHeader(message: message),
              SizedBox(height: 20.h),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final body = message.body ?? '';
                    final bodyType = message.bodyType;

                    if (state.isLoadingDetail && body.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final bodyView = MailBodyView(
                      key: ValueKey(message.id),
                      messageId: message.id,
                      body: body,
                      bodyType: bodyType,
                      fallback: message.preview,
                    );

                    if (bodyType == 'html') {
                      return bodyView;
                    }

                    return SingleChildScrollView(child: bodyView);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MailDetailHeader extends StatelessWidget {
  const _MailDetailHeader({required this.message});

  final MailMessage message;

  static final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.subject,
          style: DdtTheme.style(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: DdtTheme.taskCardTextPrimary(context),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'От: ${message.sender ?? '—'}',
          style: DdtTheme.style(fontSize: 14.sp),
        ),
        if (message.datetimeReceived != null)
          Text(
            _dateFormat.format(message.datetimeReceived!.toLocal()),
            style: DdtTheme.style(
              fontSize: 13.sp,
              color: DdtTheme.taskCardTextSecondary(context),
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: DdtTheme.style(fontSize: 14.sp)),
          SizedBox(height: 12.h),
          Button(
            text: 'Повторить',
            onPressed: onRetry,
            borderRadius: DdtTheme.radius,
          ),
        ],
      ),
    );
  }
}

class MailListItem extends StatelessWidget {
  const MailListItem({
    super.key,
    required this.message,
    required this.selected,
    required this.onTap,
  });

  final MailMessage message;
  final bool selected;
  final VoidCallback onTap;

  static final _dateFormat = DateFormat('dd.MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final isUnread = !message.isRead;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final borderRadius = DdtTheme.radius;

    final Color backgroundColor;
    final Color borderColor;
    final double borderWidth;

    if (selected) {
      backgroundColor =
          AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.14);
      borderColor = AppColors.primary;
      borderWidth = 2;
    } else if (isUnread) {
      backgroundColor =
          AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.06);
      borderColor = AppColors.primary.withValues(alpha: 0.55);
      borderWidth = 1.5;
    } else {
      backgroundColor = Colors.transparent;
      borderColor =
          DdtTheme.glassBorderColor(brightness).withValues(alpha: 0.12);
      borderWidth = 1;
    }

    return RepaintBoundary(
      child: DdtTappable(
        onTap: onTap,
        borderRadius: borderRadius,
        backgroundColor: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            children: [
              if (isUnread && !selected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4.w,
                    color: AppColors.primary,
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isUnread && !selected ? 16.w : 12.w,
                  12.h,
                  12.w,
                  12.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUnread && !selected)
                        Padding(
                          padding: EdgeInsets.only(top: 5.h, right: 8.w),
                          child: Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          message.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DdtTheme.style(
                            fontSize: 14.sp,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? AppColors.primary
                                : DdtTheme.taskCardTextPrimary(context),
                          ),
                        ),
                      ),
                      if (message.datetimeReceived != null)
                        Text(
                          _dateFormat
                              .format(message.datetimeReceived!.toLocal()),
                          style: DdtTheme.style(
                            fontSize: 12.sp,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: DdtTheme.taskCardTextSecondary(context),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    message.sender ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DdtTheme.style(
                      fontSize: 12.sp,
                      fontWeight:
                          isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: DdtTheme.taskCardTextSecondary(context),
                    ),
                  ),
                  if (message.preview.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      message.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DdtTheme.style(
                        fontSize: 12.sp,
                        color: isUnread
                            ? DdtTheme.taskCardTextPrimary(context)
                                .withValues(alpha: 0.85)
                            : DdtTheme.taskCardTextSecondary(context),
                      ),
                    ),
                  ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
