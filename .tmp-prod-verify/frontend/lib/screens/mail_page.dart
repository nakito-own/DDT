import 'dart:async';
import 'dart:ui';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../theme/ddt_icons.dart';

import '../blocs/mail/mail_bloc.dart';
import '../models/mail_inbox_options.dart';
import '../models/mail_message.dart';
import '../theme/ddt_scroll_behavior.dart';
import '../theme/ddt_theme.dart';
import '../utils/ddt_toast.dart';
import '../utils/mail_compose.dart';
import 'mail_compose_page.dart';
import '../widgets/ddt_glass_fab.dart';
import '../widgets/ddt_section_refresh.dart';
import '../widgets/ddt_tappable.dart';
import '../widgets/mail_body_view.dart';
import '../theme/ddt_typography.dart';
import '../widgets/ddt_icon.dart';
import '../widgets/ddt_user_chip.dart';
import '../widgets/ddt_adaptive.dart';
import '../widgets/ddt_app_bar_section_actions.dart';
import '../widgets/ddt_mobile_navigation_bar.dart';
import '../widgets/ddt_shell_metrics.dart';
import '../widgets/ddt_filter_dropdown.dart';
import '../widgets/ddt_panel_primary_button.dart';
import '../widgets/ddt_scroll_edge_fade.dart';
import '../widgets/ddt_app_input.dart';
import '../widgets/ddt_section_sidebar.dart';

class MailPage extends StatelessWidget {
  const MailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<MailBloc, MailState>(
      listenWhen: (previous, current) =>
          (current.archiveErrorMessage != null &&
              previous.archiveErrorMessage != current.archiveErrorMessage) ||
          (current.downloadErrorMessage != null &&
              previous.downloadErrorMessage != current.downloadErrorMessage),
      listener: (context, state) {
        final msg = state.archiveErrorMessage ?? state.downloadErrorMessage;
        if (msg == null) return;
        DdtToast.show(
          message: msg,
          type: ToastType.error,
          title: 'Не удалось выполнить действие',
          duration: const Duration(seconds: 4),
        );
      },
      child: BlocBuilder<MailBloc, MailState>(
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
              onRetry: () => context.read<MailBloc>().add(
                const MailInboxLoadRequested(showAnimation: true),
              ),
            );
          }

          if (DdtAdaptive.isCompact(context)) {
            return const _CompactMailBody();
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(flex: 8, child: _MailList()),
              DdtTheme.horizontalGap(),
              Expanded(
                flex: 7,
                child: Padding(
                  padding: DdtShellMetrics.fixedTopPadding(context),
                  child: const _MailDetail(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompactMailBody extends StatefulWidget {
  const _CompactMailBody();

  @override
  State<_CompactMailBody> createState() => _CompactMailBodyState();
}

class _CompactMailBodyState extends State<_CompactMailBody> {
  bool _sheetOpen = false;

  Future<void> _openMessage() async {
    if (_sheetOpen || !mounted) return;
    _sheetOpen = true;
    final surface = Theme.of(context).brightness == Brightness.dark
        ? DdtTheme.darkSurface
        : DdtTheme.lightSurface;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: surface,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: constraints.maxHeight * 0.94,
                child: const _MailDetail(plain: true),
              );
            },
          ),
        );
      },
    );
    _sheetOpen = false;
    if (!mounted) return;
    context.read<MailBloc>().add(const MailDetailClosed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MailBloc, MailState>(
      listenWhen: (previous, current) =>
          previous.selectedMessage?.id != current.selectedMessage?.id,
      listener: (context, state) {
        if (state.selectedMessage != null) {
          _openMessage();
        }
      },
      child: const _MailList(showDock: true),
    );
  }
}

class _MailList extends StatefulWidget {
  const _MailList({this.showDock = false});

  final bool showDock;

  @override
  State<_MailList> createState() => _MailListState();
}

class _MailInboxFilters extends StatelessWidget {
  const _MailInboxFilters({required this.onBeforeInboxQueryChange});

  final VoidCallback onBeforeInboxQueryChange;

  static MailInboxFilter? _filterFromKey(String key) {
    for (final filter in MailInboxFilter.values) {
      if (filter.name == key) return filter;
    }
    return null;
  }

  static MailInboxSort? _sortFromKey(String key) {
    for (final sort in MailInboxSort.values) {
      if (sort.name == key) return sort;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filterOptions = [
      for (final filter in MailInboxFilter.values)
        DdtFilterOption(key: filter.name, label: filter.label),
    ];
    final sortOptions = [
      for (final sort in MailInboxSort.values)
        DdtFilterOption(key: sort.name, label: sort.label),
    ];

    return BlocBuilder<MailBloc, MailState>(
      buildWhen: (previous, current) =>
          previous.filter != current.filter || previous.sort != current.sort,
      builder: (context, state) {
        final selectedFilter = {state.filter.name};
        final selectedSort = {state.sort.name};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DdtSectionSidebarTitle(),
            SizedBox(height: DdtSectionSidebar.afterTitleGap),
            DdtSectionSidebarField(
              label: 'Письма',
              gapAbove: false,
              child: DdtSearchableFilterDropdown(
                summary: state.filter.label,
                active: state.filter != MailInboxFilter.all,
                options: filterOptions,
                selected: selectedFilter,
                multi: false,
                onSelected: (key) {
                  final filter = _filterFromKey(key);
                  if (filter == null) return;
                  onBeforeInboxQueryChange();
                  context.read<MailBloc>().add(
                    MailInboxQueryChanged(filter: filter),
                  );
                },
              ),
            ),
            DdtSectionSidebarField(
              label: 'Сортировка',
              child: DdtSearchableFilterDropdown(
                summary: state.sort.label,
                active: state.sort != MailInboxSort.dateDesc,
                options: sortOptions,
                selected: selectedSort,
                multi: false,
                onSelected: (key) {
                  final sort = _sortFromKey(key);
                  if (sort == null) return;
                  onBeforeInboxQueryChange();
                  context.read<MailBloc>().add(
                    MailInboxQueryChanged(sort: sort),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
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
                              style: DdtTheme.style(
                                fontSize: DdtTypography.labelSmallSize,
                              ),
                            ),
                    )
                  : DdtScrollEdgeFade(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          widget.embedded ? DdtSectionSidebar.gutter.w : 0,
                          0,
                          widget.embedded
                              ? DdtSectionSidebar.scrollRightInset.w
                              : 0,
                          DdtScrollEdgeFade.listBottomPadding(context),
                        ),
                        children: [
                          SizedBox(height: kDdtScrollEdgeFadeHeightCompact.h),
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
        fontSize: DdtTypography.bodySize,
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
                child: DdtIcon(
                  DdtIcons.chevronRight,
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

    final entries = byOrder.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DdtIcon(
      isSelected ? DdtIcons.folderOpen : DdtIcons.folder,
      size: 12.sp,
      color: isSelected
          ? (isDark ? DdtTheme.accentColor : DdtTheme.primaryColor)
          : DdtTheme.textMuted(context),
    );
  }

  Widget _buildFolderNode(
    BuildContext context,
    MailFolderNode folder, {
    required String? selectedFolderId,
    required int depth,
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasChildren = folder.children.isNotEmpty;
    final isExpanded = _expanded.contains(folder.id);
    final isSelected = selectedFolderId == folder.id;
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;

    final rowPadding = compact
        ? EdgeInsets.symmetric(horizontal: 7.w, vertical: 5.h)
        : EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h);
    final rowSpacing = compact ? 2.h : 3.h;
    final indent = depth * (compact ? 10.0 : 12.0);

    final items = <Widget>[
      Padding(
        padding: EdgeInsets.only(left: indent.w),
        child: DdtTappable(
          onTap: () {
            context.read<MailBloc>().add(
              MailInboxQueryChanged(folderId: folder.id),
            );
          },
          enableHoverFill: true,
          borderRadius: BorderRadius.circular(6.r),
          backgroundColor: isSelected
              ? DdtTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.09)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? DdtTheme.primaryColor.withValues(alpha: isDark ? 0.36 : 0.22)
                : Colors.transparent,
            width: 1,
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
                      padding: EdgeInsets.only(right: 5.w),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOutCubic,
                        child: DdtIcon(
                          DdtIcons.chevronRight,
                          size: 11.sp,
                          color: DdtTheme.textMuted(context),
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: _buildFolderIcon(context, isSelected: isSelected),
                  ),
                Expanded(
                  child: Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DdtTheme.style(
                      fontSize: compact
                          ? DdtTypography.labelSmallSize
                          : DdtTypography.labelSize,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? accent
                          : DdtTheme.taskCardTextPrimary(context),
                    ),
                  ),
                ),
                if (folder.unreadCount > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.5.w,
                      vertical: 1.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: DdtTheme.primaryColor.withValues(
                        alpha: isDark ? 0.22 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                    child: Text(
                      '${folder.unreadCount}',
                      style: DdtTheme.style(
                        fontSize: DdtTypography.microSize,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  )
                else
                  Text(
                    '${folder.totalCount}',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.microSize,
                      color: DdtTheme.textMuted(context),
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
            .map(
              (child) => _buildFolderNode(
                context,
                child,
                selectedFolderId: selectedFolderId,
                depth: depth + 1,
                compact: compact,
              ),
            )
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
                : SizedBox(key: ValueKey('collapsed-${folder.id}'), height: 0),
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
  final _showScrollToTopButton = ValueNotifier(false);

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
    _showScrollToTopButton.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final showScrollToTopButton = position.pixels > 240;
    if (showScrollToTopButton != _showScrollToTopButton.value) {
      _showScrollToTopButton.value = showScrollToTopButton;
    }

    if (position.pixels < position.maxScrollExtent - 240) return;

    _requestLoadMore();
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;

    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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

  void _resetMessageListScroll() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  /// Extra list padding when the bulk-action bar is visible over the scroll area.
  static const double _bulkActionBarReserve = 56;

  Widget _buildMessagesToolbar(BuildContext context) {
    return BlocBuilder<MailBloc, MailState>(
      buildWhen: (previous, current) =>
          previous.selectedMessageIds != current.selectedMessageIds ||
          previous.messages.length != current.messages.length ||
          previous.isArchiving != current.isArchiving ||
          previous.archiveErrorMessage != current.archiveErrorMessage,
      builder: (context, state) {
        final visible = state.selectedMessageIds.isNotEmpty;
        final topInset = DdtShellMetrics.of(context).topReserve;

        return Padding(
          padding: EdgeInsets.only(top: topInset),
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: DdtTheme.selectionAnimationDuration,
              switchInCurve: DdtTheme.selectionAnimationCurve,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: visible
                  ? _MailBulkActionBar(
                      key: const ValueKey('mail-bulk-toolbar'),
                      selectedCount: state.selectedMessageIds.length,
                      totalCount: state.messages.length,
                      isArchiving: state.isArchiving,
                      errorMessage: state.archiveErrorMessage,
                      onSelectAll: () => context.read<MailBloc>().add(
                        const MailSelectAllRequested(),
                      ),
                      onMarkRead: () => context.read<MailBloc>().add(
                        const MailBulkMarkReadRequested(),
                      ),
                      onArchive: () {
                        final bloc = context.read<MailBloc>();
                        final s = bloc.state;
                        bloc.add(
                          MailArchiveRequested(
                            messageIds: s.selectedMessageIds.toList(),
                            folderId: s.selectedFolderId,
                          ),
                        );
                      },
                      onClear: () => context.read<MailBloc>().add(
                        const MailSelectionCleared(),
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('mail-bulk-toolbar-hidden'),
                      width: double.infinity,
                      height: 0,
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listener 1: reset scroll only when the active folder changes.
    return BlocListener<MailBloc, MailState>(
      listenWhen: (previous, current) =>
          previous.selectedFolderId != current.selectedFolderId ||
          previous.searchQuery != current.searchQuery,
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
        child: DdtAdaptiveSectionColumns(
          sheetTitle: 'Папки',
          sheetIcon: DdtIcons.folder,
          sidebar: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: DdtSectionSidebar.contentPadding(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DdtSectionSidebarField(
                      gapAbove: false,
                      child: DdtPanelPrimaryButton(
                        label: 'Написать',
                        icon: DdtIcons.edit,
                        onPressed: () => openMailComposePage(context),
                      ),
                    ),
                    SizedBox(height: DdtSectionSidebar.afterPrimaryButtonGap),
                    DdtSectionSidebarField(
                      label: 'Поиск',
                      gapAbove: false,
                      child: _MailSearchField(
                        onBeforeQueryChange: _resetMessageListScroll,
                      ),
                    ),
                    _MailInboxFilters(
                      onBeforeInboxQueryChange: _resetMessageListScroll,
                    ),
                    SizedBox(height: DdtSectionSidebar.blockGap),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: DdtTheme.sidePanelDivider(context),
                    ),
                    SizedBox(height: DdtSectionSidebar.afterDividerGap),
                  ],
                ),
              ),
              Expanded(
                child: const DdtSectionSidebarScroll(
                  child: _MailFolderBrowser(embedded: true),
                ),
              ),
            ],
          ),
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              BlocBuilder<MailBloc, MailState>(
                buildWhen: (previous, current) =>
                    previous.messages != current.messages ||
                    previous.searchQuery != current.searchQuery ||
                    previous.isLoadingMore != current.isLoadingMore ||
                    previous.isRefreshingInbox != current.isRefreshingInbox ||
                    previous.hasMoreMessages != current.hasMoreMessages ||
                    previous.loadMoreErrorMessage !=
                        current.loadMoreErrorMessage ||
                    previous.selectedMessageIds != current.selectedMessageIds,
                builder: (context, state) {
                  final messages = state.messages;

                  if (messages.isEmpty) {
                    if (state.isLoading) {
                      return const Positioned.fill(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Positioned.fill(
                      child: DdtSectionRefreshOverlay(
                        isRefreshing: state.isRefreshingInbox,
                        child: Center(
                          child: Text(
                            state.searchQuery.isEmpty
                                ? 'В этой папке нет писем'
                                : 'Ничего не найдено',
                            style: DdtTheme.style(
                              fontSize: DdtTypography.bodySize,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final showFooter =
                      state.isLoadingMore ||
                      state.hasMoreMessages ||
                      state.loadMoreErrorMessage != null;

                  final metrics = DdtShellMetrics.of(context);
                  final bulkReserve = state.selectedMessageIds.isEmpty
                      ? 0.0
                      : DdtTheme.shellSize(_bulkActionBarReserve);
                  final listTop = metrics.topReserve + bulkReserve;

                  final dockReserve = widget.showDock
                      ? MailMobileDock.reserve
                      : 0.0;
                  final listView = ScrollConfiguration(
                    behavior: const DdtScrollBehavior(),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        3.w,
                        0,
                        3.w,
                        DdtScrollEdgeFade.listBottomPadding(context) +
                            dockReserve,
                      ),
                      cacheExtent: 720,
                      itemCount: 1 + messages.length + (showFooter ? 1 : 0),
                      separatorBuilder: (context, index) {
                        if (index == 0 || index >= messages.length) {
                          return const SizedBox.shrink();
                        }
                        return SizedBox(height: 8.h);
                      },
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return AnimatedContainer(
                            duration: DdtTheme.selectionAnimationDuration,
                            curve: DdtTheme.selectionAnimationCurve,
                            height: listTop,
                          );
                        }

                        final messageIndex = index - 1;
                        if (messageIndex >= messages.length) {
                          return _MailListFooter(
                            isLoading: state.isLoadingMore,
                            hasMore: state.hasMoreMessages,
                            errorMessage: state.loadMoreErrorMessage,
                            onRetry: () => context.read<MailBloc>().add(
                              const MailInboxLoadMoreRequested(),
                            ),
                          );
                        }

                        final message = messages[messageIndex];
                        return _MailListRowConnector(
                          key: ValueKey(message.id),
                          message: message,
                        );
                      },
                    ),
                  );

                  return Positioned.fill(
                    child: DdtSectionRefreshOverlay(
                      isRefreshing: state.isRefreshingInbox,
                      child: DdtScrollEdgeFade(child: listView),
                    ),
                  );
                },
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildMessagesToolbar(context),
              ),
              if (widget.showDock)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: DdtAdaptive.floatingBottomBar(context)
                      ? DdtMobileNavigationBar.clearance(context)
                      : 0,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [MailMobileDock()],
                  ),
                ),
              Positioned(
                right: 12.w,
                bottom:
                    (widget.showDock ? MailMobileDock.reserve : 12.h) +
                    (DdtAdaptive.floatingBottomBar(context)
                        ? DdtMobileNavigationBar.clearance(context)
                        : 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _showScrollToTopButton,
                  builder: (context, show, child) {
                    return IgnorePointer(
                      ignoring: !show,
                      child: AnimatedScale(
                        scale: show ? 1.0 : 0.72,
                        duration: DdtTheme.selectionAnimationDuration,
                        curve: DdtTheme.selectionAnimationCurve,
                        child: AnimatedOpacity(
                          opacity: show ? 1.0 : 0.0,
                          duration: DdtTheme.selectionAnimationDuration,
                          curve: DdtTheme.selectionAnimationCurve,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Tooltip(
                    message: 'Наверх',
                    child: DdtGlassFab(
                      onPressed: _scrollToTop,
                      icon: DdtIcons.arrowUp,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                fontSize: DdtTypography.labelSmallSize,
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
              fontSize: DdtTypography.labelSmallSize,
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
  const _MailDetail({this.plain = false});

  /// Fills a modal bottom sheet instead of the desktop glass card.
  final bool plain;

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
            prev?.subject != curr?.subject ||
            prev?.body != curr?.body ||
            prev?.bodyType != curr?.bodyType ||
            prev?.preview != curr?.preview ||
            prev?.isRead != curr?.isRead ||
            prev?.hasAttachments != curr?.hasAttachments ||
            prev?.detailLoaded != curr?.detailLoaded ||
            prev?.attachments.length != curr?.attachments.length ||
            prev?.sender != curr?.sender ||
            prev?.datetimeReceived != curr?.datetimeReceived ||
            previous.isLoadingDetail != current.isLoadingDetail;
      },
      builder: (context, state) {
        final message = _messageForDetail(state);
        if (message == null) {
          return Center(
            child: Text(
              'Выберите письмо',
              style: DdtTheme.style(fontSize: DdtTypography.bodyLargeSize),
            ),
          );
        }

        final showAttachments =
            message.attachments.isNotEmpty || message.hasAttachments;

        final detail = Column(
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
                          fontSize: DdtTypography.labelSize,
                          color: DdtTheme.taskCardTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Не удалось загрузить список вложений',
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSize,
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

        if (plain) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 16.h),
            child: detail,
          );
        }

        return DdtTheme.glass(
          context: context,
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 12.w, 20.h),
          child: detail,
        );
      },
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                message.subject,
                style: DdtTheme.style(
                  fontSize: DdtTypography.pageTitleSize,
                  fontWeight: FontWeight.w700,
                  color: DdtTheme.taskCardTextPrimary(context),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Tooltip(
              message: 'Ответить',
              child: Semantics(
                button: true,
                label: 'Ответить',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Tooltip.dismissAllToolTips();
                      openMailComposePage(
                        context,
                        draft: MailComposeDraft.replyTo(message),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: DdtIcon(
                        DdtIcons.reply,
                        size: 16 / DdtIcon.visualScale,
                        color: DdtTheme.taskCardTextSecondary(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        DdtUserChip(name: message.sender),
        if (message.datetimeReceived != null) ...[
          SizedBox(height: 6.h),
          Text(
            _dateFormat.format(message.datetimeReceived!.toLocal()),
            style: DdtTheme.style(
              fontSize: DdtTypography.captionSize,
              color: DdtTheme.textMuted(context),
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
          Text(
            message,
            style: DdtTheme.style(fontSize: DdtTypography.bodySize),
          ),
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
    super.key,
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
    final allSelected = selectedCount >= totalCount;

    return DdtTheme.taskCardGlass(
      context: context,
      blurIntensity: 8,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _countLabel,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSize,
                    fontWeight: FontWeight.w600,
                    color: DdtTheme.taskCardTextPrimary(context),
                  ),
                ),
              ),
              // Select all / Deselect all
              _BulkButton(
                label: allSelected ? 'Снять все' : 'Все',
                icon: allSelected ? DdtIcons.deselect : DdtIcons.selectAll,
                enabled: !isArchiving,
                onTap: onSelectAll,
              ),
              SizedBox(width: 4.w),
              // Mark as read
              _BulkButton(
                label: 'Прочитано',
                icon: DdtIcons.drafts,
                enabled: !isArchiving,
                onTap: onMarkRead,
              ),
              SizedBox(width: 4.w),
              // Archive
              _BulkButton(
                label: 'В архив',
                icon: DdtIcons.archive,
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
                constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.w),
                onPressed: isArchiving ? null : onClear,
                icon: DdtIcon(
                  DdtIcons.close,
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
                fontSize: DdtTypography.captionSize,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MailListSelectionLeading extends StatelessWidget {
  const _MailListSelectionLeading({
    required this.showCheckbox,
    required this.isUnread,
    required this.selected,
    required this.isChecked,
    required this.onCheckedChanged,
  });

  final bool showCheckbox;
  final bool isUnread;
  final bool selected;
  final bool isChecked;
  final VoidCallback? onCheckedChanged;

  static Widget _transitionChild(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: DdtTheme.selectionAnimationCurve,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.55, end: 1).animate(curved),
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDot = isUnread && !selected && !showCheckbox;
    final Widget leading;
    if (showCheckbox) {
      leading = GestureDetector(
        key: const ValueKey('mail-selection-checkbox'),
        behavior: HitTestBehavior.opaque,
        onTap: onCheckedChanged,
        child: Padding(
          padding: EdgeInsets.only(top: 2.h, right: 8.w),
          child: _MailSelectionCheckbox(isChecked: isChecked),
        ),
      );
    } else if (showDot) {
      leading = Padding(
        key: const ValueKey('mail-unread-dot'),
        padding: EdgeInsets.only(top: 5.h, right: 8.w),
        child: Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      );
    } else {
      leading = const SizedBox(
        key: ValueKey('mail-leading-empty'),
        width: 0,
        height: 18,
      );
    }

    return AnimatedSize(
      duration: DdtTheme.selectionAnimationDuration,
      curve: DdtTheme.selectionAnimationCurve,
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      child: AnimatedSwitcher(
        duration: DdtTheme.selectionAnimationDuration,
        switchInCurve: DdtTheme.selectionAnimationCurve,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: _transitionChild,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [...previousChildren, ?currentChild],
          );
        },
        child: leading,
      ),
    );
  }
}

class _MailSelectionCheckbox extends StatelessWidget {
  const _MailSelectionCheckbox({required this.isChecked});

  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: DdtTheme.selectionAnimationDuration,
      curve: DdtTheme.selectionAnimationCurve,
      width: 18.w,
      height: 18.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isChecked
              ? AppColors.primary
              : DdtTheme.taskCardTextSecondary(context).withValues(alpha: 0.5),
          width: 1.5,
        ),
        color: isChecked ? AppColors.primary : Colors.transparent,
      ),
      child: AnimatedSwitcher(
        duration: DdtTheme.selectionAnimationDuration,
        switchInCurve: DdtTheme.selectionAnimationCurve,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: _MailListSelectionLeading._transitionChild,
        child: isChecked
            ? DdtIcon(
                key: const ValueKey('checked'),
                DdtIcons.check,
                size: 11.sp,
                color: Colors.white,
                fitParent: true,
              )
            : SizedBox(
                key: const ValueKey('unchecked'),
                width: 18.w,
                height: 18.w,
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
  final FaIconData icon;
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
                  DdtIcon(icon, size: 14.sp, color: color),
                  SizedBox(width: 4.w),
                  Text(
                    label,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSmallSize,
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
  const _AttachmentsBar({required this.attachments, required this.onDownload});

  final List<MailAttachment> attachments;
  final ValueChanged<MailAttachment> onDownload;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: attachments
            .map(
              (att) => Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: _AttachmentChip(
                  attachment: att,
                  onTap: () => onDownload(att),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, required this.onTap});

  final MailAttachment attachment;
  final VoidCallback onTap;

  FaIconData _iconFor(String contentType) {
    final type = contentType.toLowerCase();
    if (type.startsWith('image/')) return DdtIcons.fileImage;
    if (type == 'application/pdf') return DdtIcons.filePdf;
    if (type.startsWith('audio/')) return DdtIcons.fileAudio;
    if (type.startsWith('video/')) return DdtIcons.fileVideo;
    if (type.contains('zip') ||
        type.contains('rar') ||
        type.contains('tar') ||
        type.contains('7z')) {
      return DdtIcons.fileZip;
    }
    if (type.startsWith('text/')) return DdtIcons.fileLines;
    if (type.contains('word') ||
        type.contains('document') ||
        type.contains('msword')) {
      return DdtIcons.file;
    }
    if (type.contains('excel') ||
        type.contains('spreadsheet') ||
        type.contains('sheet')) {
      return DdtIcons.fileTable;
    }
    return DdtIcons.paperclip;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return DdtTappable(
      onTap: onTap,
      enableHoverFill: true,
      borderRadius: DdtTheme.inputControlBorderRadius,
      backgroundColor: DdtTheme.inputFillColor(context),
      border: Border.all(color: DdtTheme.borderSubtle(context), width: 1),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DdtIcon(
              _iconFor(attachment.contentType),
              size: 13.sp,
              color: isDark ? DdtTheme.accentColor : DdtTheme.primaryColor,
            ),
            SizedBox(width: 8.w),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 100.w, maxWidth: 240.w),
              child: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DdtTheme.style(
                  fontSize: DdtTypography.captionSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              attachment.displaySize,
              style: DdtTheme.style(
                fontSize: DdtTypography.microSize,
                color: DdtTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mail list item ───────────────────────────────────────────────────────────

class _MailListRowConnector extends StatefulWidget {
  const _MailListRowConnector({
    super.key,
    required this.message,
    this.nested = false,
  });

  final MailMessage message;
  final bool nested;

  @override
  State<_MailListRowConnector> createState() => _MailListRowConnectorState();
}

class _MailListRowConnectorState extends State<_MailListRowConnector>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  ScrollPosition? _scrollPosition;
  late final AnimationController _expand;
  late final CurvedAnimation _expandCurve;

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: DdtTheme.selectionAnimationDuration,
      reverseDuration: DdtTheme.selectionAnimationDuration,
    );
    _expandCurve = CurvedAnimation(
      parent: _expand,
      curve: DdtTheme.selectionAnimationCurve,
      reverseCurve: Curves.easeInCubic,
    );
    if (widget.message.isExpanded || widget.message.isExpanding) {
      _expand.value = 1;
    }
    _expand.addStatusListener(_onExpandStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition == next) return;
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
    _scrollPosition = next;
    _scrollPosition?.isScrollingNotifier.addListener(_onScrollActivity);
  }

  @override
  void didUpdateWidget(_MailListRowConnector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final open = widget.message.isExpanded || widget.message.isExpanding;
    if (open) {
      _expand.forward();
    } else {
      _expand.reverse();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivity);
    _expand.removeStatusListener(_onExpandStatus);
    _expandCurve.dispose();
    _expand.dispose();
    super.dispose();
  }

  void _onExpandStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed ||
        status == AnimationStatus.completed) {
      setState(() {});
    }
  }

  void _onScrollActivity() {
    if (_scrollPosition?.isScrollingNotifier.value != true || !_hover) return;
    setState(() => _hover = false);
  }

  void _setHover(bool value) {
    if (_scrollPosition?.isScrollingNotifier.value == true) return;
    if (_hover == value) return;
    setState(() => _hover = value);
  }

  void _action(MailQuickAction action) {
    context.read<MailBloc>().add(
      MailMessageActionRequested(widget.message, action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    return BlocSelector<
      MailBloc,
      MailState,
      ({bool selected, bool selectionModeActive, bool isChecked})
    >(
      selector: (state) => (
        selected: state.selectedMessage?.id == message.id,
        selectionModeActive: state.isSelectionModeActive,
        isChecked: state.selectedMessageIds.contains(message.id),
      ),
      builder: (context, selection) {
        final row = MouseRegion(
          onEnter: (_) => _setHover(true),
          onExit: (_) => _setHover(false),
          child: Stack(
            children: [
              MailListItem(
                message: message,
                selected: selection.selected,
                selectionModeActive: selection.selectionModeActive,
                isChecked: selection.isChecked,
                showDate: !_hover,
                onTap: () =>
                    context.read<MailBloc>().add(MailMessageSelected(message)),
                onCheckedChanged: () => context.read<MailBloc>().add(
                  MailSelectionToggled(message.id),
                ),
                onToggleThread: message.canExpand && !widget.nested
                    ? () => context.read<MailBloc>().add(
                        MailConversationToggled(message.id),
                      )
                    : null,
              ),
              if (_hover)
                Positioned(
                  top: 4,
                  right: 6,
                  child: _MailHoverActions(
                    message: message,
                    onPin: () => _action(MailQuickAction.pin),
                    onFlag: () => _action(MailQuickAction.flag),
                    onUnread: () => _action(MailQuickAction.unread),
                    onDelete: () => _action(MailQuickAction.delete),
                  ),
                ),
            ],
          ),
        );
        final showThread =
            !widget.nested &&
            (message.isExpanded ||
                message.isExpanding ||
                _expand.status != AnimationStatus.dismissed);
        if (!showThread) return row;
        // SizeTransition всегда клипует ребёнка. После раскрытия показываем
        // список напрямую, чтобы окантовка выбранной карточки не обрезалась.
        final threadSettled = _expand.status == AnimationStatus.completed;
        final thread = _MailThreadChildren(message: message);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row,
            if (threadSettled)
              thread
            else
              SizeTransition(
                sizeFactor: _expandCurve,
                axisAlignment: -1,
                child: thread,
              ),
          ],
        );
      },
    );
  }
}

class _MailThreadChildren extends StatelessWidget {
  const _MailThreadChildren({required this.message});

  final MailMessage message;

  @override
  Widget build(BuildContext context) {
    final lineColor = DdtTheme.glassBorderColor(
      Theme.of(context).brightness,
    ).withValues(alpha: 0.55);
    final children = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message.isExpanding && message.thread.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        for (final child in message.thread)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: _MailListRowConnector(
              key: ValueKey(child.id),
              message: child,
              nested: true,
            ),
          ),
      ],
    );
    if (message.thread.isEmpty) return children;
    return Padding(
      padding: EdgeInsets.only(top: 2.h, left: 6.w),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: lineColor,
              child: SizedBox(width: 2.w),
            ),
            SizedBox(width: 10.w),
            Expanded(child: children),
          ],
        ),
      ),
    );
  }
}

class _MailHoverActions extends StatelessWidget {
  const _MailHoverActions({
    required this.message,
    required this.onPin,
    required this.onFlag,
    required this.onUnread,
    required this.onDelete,
  });

  final MailMessage message;
  final VoidCallback onPin;
  final VoidCallback onFlag;
  final VoidCallback onUnread;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = DdtTheme.textSecondary(context);
    final accent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;

    return ClipRRect(
      borderRadius: DdtTheme.inputControlBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: isDark
                ? DdtTheme.darkPickerSurface.withValues(alpha: 0.84)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: DdtTheme.inputControlBorderRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : DdtTheme.borderStrong(context),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MailHoverButton(
                tooltip: message.isPinned ? 'Открепить' : 'Закрепить',
                icon: DdtIcons.pin,
                color: message.isPinned ? accent : muted,
                onPressed: onPin,
              ),
              _MailHoverButton(
                tooltip: message.isFlagged ? 'Снять пометку' : 'Пометить',
                icon: DdtIcons.flag,
                color: message.isFlagged ? DdtTheme.warningColor : muted,
                onPressed: onFlag,
              ),
              _MailHoverButton(
                tooltip: 'Отметить как непрочитанное',
                icon: DdtIcons.envelopeOpen,
                color: muted,
                onPressed: onUnread,
              ),
              _MailHoverButton(
                tooltip: 'Удалить',
                icon: DdtIcons.trash,
                color: muted,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MailHoverButton extends StatelessWidget {
  const _MailHoverButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final FaIconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: DdtTheme.radius,
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: DdtIcon(icon, size: 13.sp, color: color),
        ),
      ),
    );
  }
}

class _MailSearchField extends StatefulWidget {
  const _MailSearchField({required this.onBeforeQueryChange});

  final VoidCallback onBeforeQueryChange;

  @override
  State<_MailSearchField> createState() => _MailSearchFieldState();
}

class _MailSearchFieldState extends State<_MailSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    _debounce?.cancel();
    widget.onBeforeQueryChange();
    context.read<MailBloc>().add(MailSearchQueryChanged(value));
  }

  @override
  Widget build(BuildContext context) {
    return DdtAppInput(
      hint: 'Поиск в почте',
      controller: _controller,
      type: InputType.search,
      variant: DdtInputVariant.compact,
      prefixIcon: DdtIcons.search,
      borderRadius: DdtTheme.radius,
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          _submit(value);
        });
      },
    );
  }
}

/// Selection ring drawn outside [child] so inner padding stays fixed.
class _MailListOutwardBorder extends StatelessWidget {
  const _MailListOutwardBorder({
    required this.width,
    required this.color,
    required this.borderRadius,
    required this.child,
  });

  final double width;
  final Color color;
  final BorderRadius borderRadius;
  final Widget child;

  BorderRadius _expandedRadius(double ringWidth) {
    return BorderRadius.only(
      topLeft: Radius.elliptical(
        borderRadius.topLeft.x + ringWidth,
        borderRadius.topLeft.y + ringWidth,
      ),
      topRight: Radius.elliptical(
        borderRadius.topRight.x + ringWidth,
        borderRadius.topRight.y + ringWidth,
      ),
      bottomLeft: Radius.elliptical(
        borderRadius.bottomLeft.x + ringWidth,
        borderRadius.bottomLeft.y + ringWidth,
      ),
      bottomRight: Radius.elliptical(
        borderRadius.bottomRight.x + ringWidth,
        borderRadius.bottomRight.y + ringWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: DdtTheme.selectionAnimationDuration,
      curve: DdtTheme.selectionAnimationCurve,
      tween: Tween<double>(end: width),
      builder: (context, ringWidth, child) {
        if (ringWidth <= 0) return child!;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -ringWidth,
              top: -ringWidth,
              right: -ringWidth,
              bottom: -ringWidth,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _expandedRadius(ringWidth),
                    border: Border.all(color: color, width: ringWidth),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: child,
    );
  }
}

class MailListItem extends StatelessWidget {
  const MailListItem({
    super.key,
    required this.message,
    required this.selected,
    required this.onTap,
    this.selectionModeActive = false,
    this.isChecked = false,
    this.onCheckedChanged,
    this.onToggleThread,
    this.showDate = true,
  });

  final MailMessage message;
  final bool selected;
  final VoidCallback onTap;
  final bool selectionModeActive;
  final bool isChecked;
  final VoidCallback? onCheckedChanged;
  final VoidCallback? onToggleThread;
  final bool showDate;

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
    final Color? outwardBorderColor;
    final double outwardBorderWidth;

    final neutralBorder = isDark
        ? Colors.white.withValues(alpha: 0.11)
        : DdtTheme.lightBorderSubtle.withValues(alpha: 0.90);
    final activeAccent = isDark ? DdtTheme.accentColor : DdtTheme.primaryColor;

    if (isChecked) {
      backgroundColor = isDark
          ? const Color(0xCC242D42)
          : const Color(0xE6EEF3FC);
      borderColor = activeAccent.withValues(alpha: 0.42);
      borderWidth = 1;
      outwardBorderColor = activeAccent.withValues(alpha: 0.72);
      outwardBorderWidth = 1.5;
    } else if (selected) {
      backgroundColor = isDark
          ? const Color(0xD927324A)
          : const Color(0xEBEDF2FC);
      borderColor = activeAccent.withValues(alpha: 0.48);
      borderWidth = 1;
      outwardBorderColor = activeAccent;
      outwardBorderWidth = 1.5;
    } else if (isUnread) {
      backgroundColor = isDark
          ? DdtTheme.darkWidget.withValues(alpha: 0.80)
          : Colors.white.withValues(alpha: 0.86);
      borderColor = activeAccent.withValues(alpha: isDark ? 0.36 : 0.24);
      borderWidth = 1;
      outwardBorderColor = null;
      outwardBorderWidth = 0;
    } else {
      backgroundColor = isDark
          ? DdtTheme.darkWidget.withValues(alpha: 0.60)
          : Colors.white.withValues(alpha: 0.68);
      borderColor = neutralBorder;
      borderWidth = 1;
      outwardBorderColor = null;
      outwardBorderWidth = 0;
    }

    final showCheckbox = selectionModeActive || isChecked;

    final item = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DdtTappable(
          onTap: onTap,
          enableHoverFill: true,
          borderRadius: borderRadius,
          backgroundColor: backgroundColor,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: selected && !isChecked
              ? [
                  BoxShadow(
                    color: activeAccent.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.18 : 0.025,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (onToggleThread != null)
                      Padding(
                        padding: EdgeInsets.only(right: 4.w),
                        child: InkWell(
                          onTap: onToggleThread,
                          borderRadius: DdtTheme.radius,
                          child: Padding(
                            padding: EdgeInsets.all(2.w),
                            child: message.isExpanding
                                ? SizedBox(
                                    width: 14.sp,
                                    height: 14.sp,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : DdtIcon(
                                    message.isExpanded
                                        ? DdtIcons.chevronDown
                                        : DdtIcons.chevronRight,
                                    size: 12.sp,
                                    color: DdtTheme.taskCardTextSecondary(
                                      context,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    _MailListSelectionLeading(
                      showCheckbox: showCheckbox,
                      isUnread: isUnread,
                      selected: selected,
                      isChecked: isChecked,
                      onCheckedChanged: onCheckedChanged,
                    ),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: DdtTheme.selectionAnimationDuration,
                        curve: DdtTheme.selectionAnimationCurve,
                        style: DdtTheme.style(
                          fontSize: DdtTypography.bodySize,
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? activeAccent
                              : DdtTheme.taskCardTextPrimary(context),
                        ),
                        child: Text(
                          message.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.hasAttachments)
                          Padding(
                            padding: EdgeInsets.only(left: 4.w, right: 2.w),
                            child: DdtIcon(
                              DdtIcons.paperclip,
                              size: 13.sp,
                              color: DdtTheme.taskCardTextSecondary(context),
                            ),
                          ),
                        if (message.messageCount > 1)
                          Padding(
                            padding: EdgeInsets.only(right: 4.w),
                            child: Text(
                              '${message.messageCount}',
                              style: DdtTheme.style(
                                fontSize: DdtTypography.microSize,
                                fontWeight: FontWeight.w600,
                                color: DdtTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        if (showDate && message.datetimeReceived != null)
                          Text(
                            MailListItem._dateFormat.format(
                              message.datetimeReceived!.toLocal(),
                            ),
                            style: DdtTheme.style(
                              fontSize: DdtTypography.microSize,
                              fontWeight: isUnread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: DdtTheme.textMuted(context),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DdtUserChip(
                    name: message.sender,
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (message.preview.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    message.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSmallSize,
                      color: isUnread
                          ? DdtTheme.textSecondary(context)
                          : DdtTheme.textMuted(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: _MailListOutwardBorder(
        width: outwardBorderWidth,
        color: outwardBorderColor ?? Colors.transparent,
        borderRadius: borderRadius,
        child: item,
      ),
    );
  }
}
