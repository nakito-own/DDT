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
    return BlocListener<MailBloc, MailState>(
      listenWhen: (previous, current) =>
          (current.archiveErrorMessage != null &&
              previous.archiveErrorMessage != current.archiveErrorMessage) ||
          (current.downloadErrorMessage != null &&
              previous.downloadErrorMessage != current.downloadErrorMessage),
      listener: (context, state) {
        final msg =
            state.archiveErrorMessage ?? state.downloadErrorMessage;
        if (msg == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      },
      child: Stack(
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
                    Expanded(flex: 8, child: const _MailList()),
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
      ),
    );
  }
}

class _MailList extends StatefulWidget {
  const _MailList();

  @override
  State<_MailList> createState() => _MailListState();
}

class _MailFolderBrowser extends StatefulWidget {
  const _MailFolderBrowser({this.embedded = false});

  final bool embedded;

  @override
  State<_MailFolderBrowser> createState() => _MailFolderBrowserState();
}

class _MailFolderBrowserState extends State<_MailFolderBrowser> {
  static const _favoritesSectionKey = 'favorites';
  static const _allSectionKey = 'all';

  final Set<String> _expanded = <String>{};
  final Set<String> _expandedSections = {_favoritesSectionKey};
  bool _defaultsApplied = false;

  static const _favoriteNameGroups = <List<String>>[
    ['inbox', 'входящие'],
    ['sent', 'sent items', 'отправленные'],
    ['drafts', 'черновики'],
    ['deleted', 'deleted items', 'удаленные', 'корзина'],
  ];

  @override
  Widget build(BuildContext context) {
    final browser = BlocBuilder<MailBloc, MailState>(
        buildWhen: (previous, current) =>
            previous.folders != current.folders ||
            previous.selectedFolderId != current.selectedFolderId ||
            previous.isLoading != current.isLoading,
        builder: (context, state) {
          final mailFolders = state.folders;
          final folders = mailFolders?.folders ?? const <MailFolderNode>[];
          final selectedFolderId = state.selectedFolderId;
          final favoriteFolders = _collectFavoriteFolders(
            folders,
            inboxFolderId: mailFolders?.inboxFolderId,
            sentFolderId: mailFolders?.sentFolderId,
          );
          final favoriteIds = favoriteFolders.map((folder) => folder.id).toSet();
          final otherFolders = _buildAllFolders(folders, favoriteIds);
          _ensureDefaultExpansion(favoriteFolders, mailFolders?.inboxFolderId);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: folders.isEmpty
                    ? Center(
                        child: state.isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                'Нет папок',
                                style: DdtTheme.style(fontSize: 12.sp),
                              ),
                      )
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          if (favoriteFolders.isNotEmpty)
                            _buildExpandableSection(
                              context: context,
                              title: 'Избранное',
                              sectionKey: _favoritesSectionKey,
                              children: favoriteFolders
                                  .map(
                                    (folder) => _buildFolderNode(
                                      context,
                                      folder,
                                      selectedFolderId: selectedFolderId,
                                      depth: 0,
                                      compact: true,
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (otherFolders.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            _buildExpandableSection(
                              context: context,
                              title: 'Все',
                              sectionKey: _allSectionKey,
                              children: otherFolders
                                  .map(
                                    (folder) => _buildFolderNode(
                                      context,
                                      folder,
                                      selectedFolderId: selectedFolderId,
                                      depth: 0,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      );

    if (widget.embedded) {
      return browser;
    }

    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 12.w, 12.h),
      child: browser,
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: DdtTheme.style(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: DdtTheme.taskCardTextPrimary(context),
      ),
    );
  }

  Widget _buildExpandableSection({
    required BuildContext context,
    required String title,
    required String sectionKey,
    required List<Widget> children,
  }) {
    final isExpanded = _expandedSections.contains(sectionKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSections.remove(sectionKey);
              } else {
                _expandedSections.add(sectionKey);
              }
            });
          },
          child: Row(
            children: [
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOutCubic,
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 11.sp,
                  color: DdtTheme.taskCardTextSecondary(context),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(child: _buildSectionTitle(context, title)),
            ],
          ),
        ),
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            reverseDuration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: isExpanded
                ? Column(
                    key: ValueKey('section-expanded-$sectionKey'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 6.h),
                      ...children,
                    ],
                  )
                : SizedBox(
                    key: ValueKey('section-collapsed-$sectionKey'),
                    height: 0,
                  ),
          ),
        ),
      ],
    );
  }

  void _ensureDefaultExpansion(
    List<MailFolderNode> favoriteFolders,
    String? inboxFolderId,
  ) {
    if (_defaultsApplied || favoriteFolders.isEmpty) return;

    MailFolderNode? inboxFolder;
    for (final folder in favoriteFolders) {
      if (_favoriteOrder(folder) == 0 ||
          (inboxFolderId != null &&
              inboxFolderId.isNotEmpty &&
              folder.id == inboxFolderId)) {
        inboxFolder = folder;
        break;
      }
    }

    _defaultsApplied = true;
    if (inboxFolder == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _expanded.add(inboxFolder!.id));
    });
  }

  String _normalizeFolderName(String name) => name.trim().toLowerCase();

  int? _favoriteOrder(MailFolderNode folder) {
    final normalized = _normalizeFolderName(folder.name);
    for (var index = 0; index < _favoriteNameGroups.length; index++) {
      if (_favoriteNameGroups[index].contains(normalized)) {
        return index;
      }
    }
    return null;
  }

  List<MailFolderNode> _flattenFolders(List<MailFolderNode> folders) {
    final result = <MailFolderNode>[];
    for (final folder in folders) {
      result
        ..add(folder)
        ..addAll(_flattenFolders(folder.children));
    }
    return result;
  }

  List<MailFolderNode> _collectFavoriteFolders(
    List<MailFolderNode> folders, {
    String? inboxFolderId,
    String? sentFolderId,
  }) {
    final byOrder = <int, MailFolderNode>{};
    for (final folder in _flattenFolders(folders)) {
      final order = _favoriteOrder(folder);
      if (order != null) {
        byOrder.putIfAbsent(order, () => folder);
      }
      if (inboxFolderId != null &&
          inboxFolderId.isNotEmpty &&
          folder.id == inboxFolderId) {
        byOrder.putIfAbsent(0, () => folder);
      }
      if (sentFolderId != null &&
          sentFolderId.isNotEmpty &&
          folder.id == sentFolderId) {
        byOrder.putIfAbsent(1, () => folder);
      }
    }

    final entries = byOrder.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => entry.value).toList();
  }

  List<MailFolderNode> _buildAllFolders(
    List<MailFolderNode> folders,
    Set<String> favoriteIds,
  ) {
    final result = <MailFolderNode>[];
    for (final folder in folders) {
      if (favoriteIds.contains(folder.id)) {
        continue;
      }

      result.add(
        MailFolderNode(
          id: folder.id,
          name: folder.name,
          totalCount: folder.totalCount,
          unreadCount: folder.unreadCount,
          children: _buildAllFolders(folder.children, favoriteIds),
        ),
      );
    }
    return result;
  }

  Widget _buildFolderIcon(BuildContext context, {required bool isSelected}) {
    return Icon(
      isSelected ? Icons.folder_open_outlined : Icons.folder_outlined,
      size: 11.sp,
      color: isSelected
          ? AppColors.primary
          : DdtTheme.taskCardTextSecondary(context),
    );
  }

  Widget _buildFolderNode(
    BuildContext context,
    MailFolderNode folder, {
    required String? selectedFolderId,
    required int depth,
    bool compact = false,
  }) {
    final hasChildren = folder.children.isNotEmpty;
    final isExpanded = _expanded.contains(folder.id);
    final isSelected = selectedFolderId == folder.id;

    final rowPadding = compact
        ? EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h)
        : EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h);
    final rowSpacing = compact ? 3.h : 4.h;
    final indent = depth * (compact ? 10.0 : 12.0);

    final items = <Widget>[
      Padding(
        padding: EdgeInsets.only(left: indent.w),
        child: DdtTappable(
          onTap: () {
            context.read<MailBloc>().add(MailInboxQueryChanged(folderId: folder.id));
          },
          enableHoverFill: true,
          borderRadius: DdtTheme.radius,
          backgroundColor: isSelected
              ? AppColors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : DdtTheme.glassBorderColor(Theme.of(context).brightness)
                    .withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
          child: Padding(
            padding: rowPadding,
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expanded.remove(folder.id);
                        } else {
                          _expanded.add(folder.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(right: 4.w),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          CupertinoIcons.chevron_right,
                          size: 11.sp,
                          color: DdtTheme.taskCardTextSecondary(context),
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(right: 4.w),
                    child: _buildFolderIcon(context, isSelected: isSelected),
                  ),
                Expanded(
                  child: Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DdtTheme.style(
                      fontSize: compact ? 12.sp : 12.5.sp,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : DdtTheme.taskCardTextPrimary(context),
                    ),
                  ),
                ),
                if (folder.unreadCount > 0)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      '${folder.unreadCount}',
                      style: DdtTheme.style(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else
                  Text(
                    '${folder.totalCount}',
                    style: DdtTheme.style(
                      fontSize: 10.sp,
                      color: DdtTheme.taskCardTextSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      SizedBox(height: rowSpacing),
    ];

    if (hasChildren) {
      final childTree = Column(
        key: ValueKey('expanded-${folder.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: folder.children
            .map((child) => _buildFolderNode(
                  context,
                  child,
                  selectedFolderId: selectedFolderId,
                  depth: depth + 1,
                  compact: compact,
                ))
            .toList(),
      );

      items.add(
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            reverseDuration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: isExpanded
                ? childTree
                : SizedBox(
                    key: ValueKey('collapsed-${folder.id}'),
                    height: 0,
                  ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }
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
    // Listener 1: reset scroll only when the active folder changes.
    return BlocListener<MailBloc, MailState>(
      listenWhen: (previous, current) =>
          previous.selectedFolderId != current.selectedFolderId,
      listener: (context, state) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      },
      // Listener 2: schedule load-more when a new batch arrives.
      child: BlocListener<MailBloc, MailState>(
        listenWhen: (previous, current) =>
            previous.hasMoreMessages != current.hasMoreMessages ||
            previous.isLoadingMore != current.isLoadingMore ||
            previous.isRefreshingInbox != current.isRefreshingInbox,
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
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 16.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
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
                                color:
                                    DdtTheme.taskCardTextSecondary(context),
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
                              color:
                                  AppColors.primary.withValues(alpha: 0.85),
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
              // ── Bulk action bar (visible when any messages are selected) ─
              BlocBuilder<MailBloc, MailState>(
                buildWhen: (previous, current) =>
                    previous.selectedMessageIds != current.selectedMessageIds ||
                    previous.messages.length != current.messages.length ||
                    previous.isArchiving != current.isArchiving ||
                    previous.archiveErrorMessage !=
                        current.archiveErrorMessage,
                builder: (context, state) {
                  return AnimatedSize(
                    duration: DdtTheme.selectionAnimationDuration,
                    curve: DdtTheme.selectionAnimationCurve,
                    alignment: Alignment.topCenter,
                    child: state.selectedMessageIds.isEmpty
                        ? const SizedBox.shrink()
                        : _MailBulkActionBar(
                            selectedCount: state.selectedMessageIds.length,
                            totalCount: state.messages.length,
                            isArchiving: state.isArchiving,
                            errorMessage: state.archiveErrorMessage,
                            onSelectAll: () => context
                                .read<MailBloc>()
                                .add(const MailSelectAllRequested()),
                            onMarkRead: () => context
                                .read<MailBloc>()
                                .add(const MailBulkMarkReadRequested()),
                            onArchive: () {
                              final bloc = context.read<MailBloc>();
                              final s = bloc.state;
                              bloc.add(MailArchiveRequested(
                                messageIds:
                                    s.selectedMessageIds.toList(),
                                folderId: s.selectedFolderId,
                              ));
                            },
                            onClear: () => context
                                .read<MailBloc>()
                                .add(const MailSelectionCleared()),
                          ),
                  );
                },
              ),
              SizedBox(height: 8.h),
              // ── Folder browser + message list ───────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: EdgeInsets.only(top: 2.h, right: 1.w),
                        child: _MailFolderBrowser(embedded: true),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      width: 1,
                      color: DdtTheme.glassBorderColor(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.22),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      flex: 7,
                      child: BlocBuilder<MailBloc, MailState>(
                        buildWhen: (previous, current) =>
                            previous.messages != current.messages ||
                            previous.selectedMessage?.id !=
                                current.selectedMessage?.id ||
                            previous.selectedMessageIds !=
                                current.selectedMessageIds ||
                            previous.isSelectionModeActive !=
                                current.isSelectionModeActive ||
                            previous.isLoadingMore != current.isLoadingMore ||
                            previous.isRefreshingInbox !=
                                current.isRefreshingInbox ||
                            previous.hasMoreMessages !=
                                current.hasMoreMessages ||
                            previous.loadMoreErrorMessage !=
                                current.loadMoreErrorMessage,
                        builder: (context, state) {
                          final messages = state.messages;
                          final selectedId = state.selectedMessage?.id;

                          if (messages.isEmpty) {
                            if (state.isLoading || state.isRefreshingInbox) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            return Center(
                              child: Text(
                                'В этой папке нет писем',
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
                            itemCount:
                                messages.length + (showFooter ? 1 : 0),
                            separatorBuilder: (context, index) {
                              if (index >= messages.length - 1) {
                                return const SizedBox.shrink();
                              }
                              return SizedBox(height: 8.h);
                            },
                            itemBuilder: (context, index) {
                              if (index >= messages.length) {
                                return _MailListFooter(
                                  isLoading: state.isLoadingMore ||
                                      state.isRefreshingInbox,
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
                                selectionModeActive: state.isSelectionModeActive,
                                isChecked: state.selectedMessageIds
                                    .contains(message.id),
                                onTap: () => context
                                    .read<MailBloc>()
                                    .add(MailMessageSelected(message)),
                                onCheckedChanged: () => context
                                    .read<MailBloc>()
                                    .add(MailSelectionToggled(message.id)),
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
            ],
          ),
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

  MailMessage? _messageForDetail(MailState state) {
    final selected = state.selectedMessage;
    if (selected == null) return null;

    for (final message in state.messages) {
      if (message.id == selected.id) {
        return message;
      }
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailBloc, MailState>(
      buildWhen: (previous, current) {
        final prev = _messageForDetail(previous);
        final curr = _messageForDetail(current);
        return prev?.id != curr?.id ||
            prev?.hasAttachments != curr?.hasAttachments ||
            prev?.detailLoaded != curr?.detailLoaded ||
            prev?.attachments.length != curr?.attachments.length ||
            prev?.sender != curr?.sender ||
            prev?.datetimeReceived != curr?.datetimeReceived ||
            previous.isLoadingDetail != current.isLoadingDetail ||
            previous.messages != current.messages;
      },
      builder: (context, state) {
        final message = _messageForDetail(state);
        if (message == null) {
          return DdtTheme.glass(
            context: context,
            padding: EdgeInsets.all(20.w),
            child: Center(
              child: Text(
                'Выберите письмо',
                style: DdtTheme.style(fontSize: 15.sp),
              ),
            ),
          );
        }

        final showAttachments =
            message.attachments.isNotEmpty || message.hasAttachments;

        return DdtTheme.glass(
          context: context,
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MailDetailHeader(message: message),
              if (showAttachments) ...[
                SizedBox(height: 12.h),
                if (message.attachments.isNotEmpty)
                  _AttachmentsBar(
                    attachments: message.attachments,
                    onDownload: (att) => context.read<MailBloc>().add(
                          MailAttachmentDownloadRequested(
                            messageId: message.id,
                            attachment: att,
                            folderId: message.folderId,
                          ),
                        ),
                  )
                else if (state.isLoadingDetail || !message.detailLoaded)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Загрузка вложений…',
                          style: DdtTheme.style(
                            fontSize: 13.sp,
                            color:
                                DdtTheme.taskCardTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Не удалось загрузить список вложений',
                    style: DdtTheme.style(
                      fontSize: 13.sp,
                      color: DdtTheme.taskCardTextSecondary(context),
                    ),
                  ),
              ],
              SizedBox(height: 20.h),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final body = message.body ?? '';
                    final bodyType = message.bodyType;

                    if (state.isLoadingDetail && body.isEmpty) {
                      return const Center(
                          child: CircularProgressIndicator());
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
          ),
        );
      },
    );
  }
}

class _MailSenderChip extends StatelessWidget {
  const _MailSenderChip({
    required this.sender,
    this.fontWeight = FontWeight.w400,
  });

  final String? sender;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(2.w, 3.h, 6.w, 3.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18.w,
            height: 18.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
            ),
            child: Icon(
              CupertinoIcons.person_fill,
              size: 10.sp,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 4.w),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              sender ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: 11.sp,
                fontWeight: fontWeight,
                color: DdtTheme.taskCardTextSecondary(context),
              ),
            ),
          ),
        ],
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
        SizedBox(height: 8.h),
        _MailSenderChip(sender: message.sender),
        if (message.datetimeReceived != null) ...[
          SizedBox(height: 6.h),
          Text(
            _dateFormat.format(message.datetimeReceived!.toLocal()),
            style: DdtTheme.style(
              fontSize: 11.sp,
              color: DdtTheme.textMuted(context).withValues(alpha: 0.62),
            ),
          ),
        ],
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

// ─── Bulk action bar ──────────────────────────────────────────────────────────

class _MailBulkActionBar extends StatelessWidget {
  const _MailBulkActionBar({
    required this.selectedCount,
    required this.totalCount,
    required this.isArchiving,
    required this.onSelectAll,
    required this.onMarkRead,
    required this.onArchive,
    required this.onClear,
    this.errorMessage,
  });

  final int selectedCount;
  final int totalCount;
  final bool isArchiving;
  final VoidCallback onSelectAll;
  final VoidCallback onMarkRead;
  final VoidCallback onArchive;
  final VoidCallback onClear;
  final String? errorMessage;

  String get _countLabel {
    final n = selectedCount;
    if (n % 10 == 1 && n % 100 != 11) return 'Выбрано $n письмо';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'Выбрано $n письма';
    }
    return 'Выбрано $n писем';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final allSelected = selectedCount >= totalCount;

    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.10),
          borderRadius: DdtTheme.radius,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _countLabel,
                    style: DdtTheme.style(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                // Select all / Deselect all
                _BulkButton(
                  label: allSelected ? 'Снять все' : 'Все',
                  icon: allSelected
                      ? Icons.deselect
                      : Icons.select_all,
                  enabled: !isArchiving,
                  onTap: onSelectAll,
                ),
                SizedBox(width: 4.w),
                // Mark as read
                _BulkButton(
                  label: 'Прочитано',
                  icon: Icons.drafts_outlined,
                  enabled: !isArchiving,
                  onTap: onMarkRead,
                ),
                SizedBox(width: 4.w),
                // Archive
                _BulkButton(
                  label: 'В архив',
                  icon: Icons.archive_outlined,
                  enabled: !isArchiving,
                  isLoading: isArchiving,
                  onTap: onArchive,
                ),
                SizedBox(width: 4.w),
                // Cancel selection
                IconButton(
                  tooltip: 'Снять выделение',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.all(4.w),
                  constraints: BoxConstraints(
                      minWidth: 28.w, minHeight: 28.w),
                  onPressed: isArchiving ? null : onClear,
                  icon: Icon(
                    Icons.close,
                    size: 16.sp,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (errorMessage != null) ...[
              SizedBox(height: 4.h),
              Text(
                errorMessage!,
                style: DdtTheme.style(
                  fontSize: 11.sp,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BulkButton extends StatelessWidget {
  const _BulkButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !isLoading;
    final color = active
        ? AppColors.primary
        : DdtTheme.taskCardTextSecondary(context);

    return DdtTappable(
      onTap: active ? onTap : null,
      borderRadius: DdtTheme.radius,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: isLoading
            ? SizedBox(
                width: 14.w,
                height: 14.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14.sp, color: color),
                  SizedBox(width: 4.w),
                  Text(
                    label,
                    style: DdtTheme.style(
                      fontSize: 12.sp,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Attachments bar ──────────────────────────────────────────────────────────

class _AttachmentsBar extends StatelessWidget {
  const _AttachmentsBar({
    required this.attachments,
    required this.onDownload,
  });

  final List<MailAttachment> attachments;
  final ValueChanged<MailAttachment> onDownload;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: attachments
            .map((att) => Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: _AttachmentChip(
                    attachment: att,
                    onTap: () => onDownload(att),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    required this.onTap,
  });

  final MailAttachment attachment;
  final VoidCallback onTap;

  IconData _iconFor(String contentType) {
    final type = contentType.toLowerCase();
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (type.startsWith('audio/')) return Icons.audio_file_outlined;
    if (type.startsWith('video/')) return Icons.video_file_outlined;
    if (type.contains('zip') ||
        type.contains('rar') ||
        type.contains('tar') ||
        type.contains('7z')) {
      return Icons.folder_zip_outlined;
    }
    if (type.startsWith('text/')) return Icons.text_snippet_outlined;
    if (type.contains('word') ||
        type.contains('document') ||
        type.contains('msword')) {
      return Icons.description_outlined;
    }
    if (type.contains('excel') ||
        type.contains('spreadsheet') ||
        type.contains('sheet')) {
      return Icons.table_chart_outlined;
    }
    return Icons.attach_file;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return DdtTappable(
      onTap: onTap,
      enableHoverFill: true,
      borderRadius: DdtTheme.radius,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.black.withValues(alpha: 0.04),
      border: Border.all(
        color:
            DdtTheme.glassBorderColor(brightness).withValues(alpha: 0.18),
        width: 1,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(attachment.contentType),
              size: 14.sp,
              color: DdtTheme.taskCardTextSecondary(context),
            ),
            SizedBox(width: 8.w),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 120.w, maxWidth: 240.w),
              child: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              attachment.displaySize,
              style: DdtTheme.style(
                fontSize: 10.sp,
                color: DdtTheme.taskCardTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mail list item ───────────────────────────────────────────────────────────

class MailListItem extends StatefulWidget {
  const MailListItem({
    super.key,
    required this.message,
    required this.selected,
    required this.onTap,
    this.selectionModeActive = false,
    this.isChecked = false,
    this.onCheckedChanged,
  });

  final MailMessage message;
  final bool selected;
  final VoidCallback onTap;
  final bool selectionModeActive;
  final bool isChecked;
  final VoidCallback? onCheckedChanged;

  static final _dateFormat = DateFormat('dd.MM HH:mm');

  @override
  State<MailListItem> createState() => _MailListItemState();
}

class _MailListItemState extends State<MailListItem> {
  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final selected = widget.selected;
    final isChecked = widget.isChecked;
    final selectionModeActive = widget.selectionModeActive;
    final isUnread = !message.isRead;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final borderRadius = DdtTheme.radius;

    final Color backgroundColor;
    final Color borderColor;
    final double borderWidth;

    if (isChecked) {
      backgroundColor =
          AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.11);
      borderColor = AppColors.primary.withValues(alpha: 0.7);
      borderWidth = 1.5;
    } else if (selected) {
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

    final showCheckbox = selectionModeActive || isChecked;

    return RepaintBoundary(
      child: DdtTappable(
          onTap: widget.onTap,
          enableHoverFill: true,
          borderRadius: borderRadius,
          backgroundColor: backgroundColor,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: selected && !isChecked
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
                if (isUnread && !selected && !isChecked && !showCheckbox)
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
                    isUnread && !selected && !showCheckbox ? 16.w : 12.w,
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
                          // Leading: checkbox (in selection mode/checked) or unread dot
                          if (showCheckbox)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onCheckedChanged,
                              child: Padding(
                                padding:
                                    EdgeInsets.only(top: 2.h, right: 8.w),
                                child: AnimatedContainer(
                                  duration:
                                      DdtTheme.selectionAnimationDuration,
                                  curve: DdtTheme.selectionAnimationCurve,
                                  width: 18.w,
                                  height: 18.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isChecked
                                          ? AppColors.primary
                                          : DdtTheme.taskCardTextSecondary(
                                                  context)
                                              .withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    color: isChecked
                                        ? AppColors.primary
                                        : Colors.transparent,
                                  ),
                                  child: isChecked
                                      ? Icon(
                                          Icons.check,
                                          size: 11.sp,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            )
                          else if (isUnread && !selected)
                            Padding(
                              padding:
                                  EdgeInsets.only(top: 5.h, right: 8.w),
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.hasAttachments)
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: 4.w, right: 2.w),
                                  child: Icon(
                                    Icons.attach_file,
                                    size: 13.sp,
                                    color: DdtTheme.taskCardTextSecondary(
                                        context),
                                  ),
                                ),
                              if (message.datetimeReceived != null)
                                Text(
                                  MailListItem._dateFormat.format(
                                      message.datetimeReceived!.toLocal()),
                                  style: DdtTheme.style(
                                    fontSize: 10.sp,
                                    fontWeight: isUnread
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    color: DdtTheme.textMuted(context)
                                        .withValues(alpha: 0.62),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _MailSenderChip(
                          sender: message.sender,
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
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
                            color: DdtTheme.textMuted(context).withValues(
                              alpha: isUnread ? 0.82 : 0.68,
                            ),
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
