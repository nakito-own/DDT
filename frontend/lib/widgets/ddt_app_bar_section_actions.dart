import 'package:flutter/material.dart';
import '../theme/ddt_typography.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';
import '../theme/ddt_icons.dart';

import '../blocs/analytics/analytics_bloc.dart';
import '../models/analytics_dashboard.dart';
import '../blocs/calendar/calendar_bloc.dart';
import '../blocs/mail/mail_bloc.dart';
import '../models/app_section.dart';
import '../models/space.dart';
import '../models/tasks_view_mode.dart';
import '../router/route_paths.dart';
import '../screens/notes_page.dart';
import '../services/spaces_api.dart';
import '../theme/ddt_theme.dart';
import 'ddt_context_menu.dart';
import 'ddt_glass_app_bar.dart';
import 'ddt_filter_dropdown.dart';
import 'ddt_segmented_control.dart';
import '../widgets/ddt_icon.dart';

class DdtAppBarSectionActions extends StatelessWidget {
  const DdtAppBarSectionActions({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AppSection.tasks => const _TasksAppBarActions(),
      AppSection.space => const _SpaceAppBarActions(),
      AppSection.mail => const _MailAppBarActions(),
      AppSection.calendar => const _CalendarAppBarActions(),
      AppSection.analytics => const _AnalyticsAppBarActions(),
      AppSection.notes => const _NotesAppBarActions(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _SpaceAppBarActions extends StatefulWidget {
  const _SpaceAppBarActions();

  @override
  State<_SpaceAppBarActions> createState() => _SpaceAppBarActionsState();
}

class _SpaceAppBarActionsState extends State<_SpaceAppBarActions> {
  late final Future<List<Space>> _spaces = spacesApi.fetchSpaces();

  String? _spaceKeyFromLocation(String location) {
    final board = RegExp(
      r'^/space/([^/]+)/(kanban|list|gantt|archive)$',
    ).firstMatch(location);
    if (board != null) return board.group(1);
    final task = RegExp(r'^/space/(.+)-\d+$').firstMatch(location);
    return task?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    // uri.path is the open page. matchedLocation can stay on the shell prefix,
    // so a task opened from kanban or gantt looked like the list.
    final location = GoRouterState.of(context).uri.path;
    final selectedSpaceKey = _spaceKeyFromLocation(location);
    final activeMode = TasksViewMode.fromRoute(location);
    final archiveOpen = RoutePaths.isArchiveRoute(location);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtSegmentedControl<TasksViewMode>(
          segments: const [
            DdtSegmentedControlSegment(
              value: TasksViewMode.kanban,
              label: 'Канбан',
            ),
            DdtSegmentedControlSegment(
              value: TasksViewMode.list,
              label: 'Список',
            ),
            DdtSegmentedControlSegment(
              value: TasksViewMode.gantt,
              label: 'Гант',
            ),
          ],
          selected: archiveOpen ? null : activeMode,
          onChanged: (mode) {
            if (selectedSpaceKey != null) {
              context.go(mode.routePathForSpace(selectedSpaceKey));
            }
          },
        ),
        SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
        _AppBarIconAction(
          tooltip: 'Архив',
          icon: DdtIcons.archive,
          isActive: archiveOpen,
          onPressed: selectedSpaceKey == null
              ? null
              : () => context.go(RoutePaths.spaceArchiveFor(selectedSpaceKey)),
        ),
        SizedBox(width: DdtTheme.shellSizeOf(context, 10)),
        FutureBuilder<List<Space>>(
          future: _spaces,
          builder: (context, snapshot) {
            final spaces = snapshot.data ?? const <Space>[];
            Space? selectedSpace;
            for (final space in spaces) {
              if (space.spaceKey == selectedSpaceKey) {
                selectedSpace = space;
                break;
              }
            }

            final loading = snapshot.connectionState == ConnectionState.waiting;

            return _AppBarFilterDropdown(
              width: 220,
              label: loading
                  ? 'Загрузка…'
                  : (selectedSpace?.name ?? 'Пространство'),
              isBusy: loading,
              active: selectedSpaceKey != null,
              options: [
                for (final space in spaces)
                  DdtFilterOption(key: space.spaceKey, label: space.name),
              ],
              selected: selectedSpaceKey != null
                  ? {selectedSpaceKey}
                  : const {},
              emptyLabel: 'Нет пространств',
              onSelected: (key) => context.go(
                archiveOpen
                    ? RoutePaths.spaceArchiveFor(key)
                    : activeMode.routePathForSpace(key),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NotesAppBarActions extends StatelessWidget {
  const _NotesAppBarActions();

  @override
  Widget build(BuildContext context) {
    return _AppBarIconAction(
      tooltip: 'Создать папку',
      icon: DdtIcons.folder,
      onPressed: () {
        createNotesFolder(context);
      },
    );
  }
}

class _TasksAppBarActions extends StatelessWidget {
  const _TasksAppBarActions();

  @override
  Widget build(BuildContext context) {
    // Shell routes expose their own prefix in matchedLocation (`/tasks`),
    // while uri.path is the page that is actually open.
    final location = GoRouterState.of(context).uri.path;
    final activeMode = TasksViewMode.fromRoute(location);
    final archiveOpen = RoutePaths.isArchiveRoute(location);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtSegmentedControl<TasksViewMode>(
          segments: const [
            DdtSegmentedControlSegment(
              value: TasksViewMode.kanban,
              label: 'Канбан',
            ),
            DdtSegmentedControlSegment(
              value: TasksViewMode.list,
              label: 'Список',
            ),
            DdtSegmentedControlSegment(
              value: TasksViewMode.gantt,
              label: 'Гант',
            ),
          ],
          selected: archiveOpen ? null : activeMode,
          onChanged: (mode) => context.go(mode.routePath),
        ),
        SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
        _AppBarIconAction(
          tooltip: 'Архив',
          icon: DdtIcons.archive,
          isActive: archiveOpen,
          onPressed: () => context.go(RoutePaths.tasksArchive),
        ),
      ],
    );
  }
}

class _MailAppBarFolderStats extends StatelessWidget {
  const _MailAppBarFolderStats({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shell = DdtTheme.shellSizeOf(context, 1);

    return BlocBuilder<MailBloc, MailState>(
      buildWhen: (previous, current) =>
          previous.folders != current.folders ||
          previous.inboxQueryErrorMessage != current.inboxQueryErrorMessage,
      builder: (context, state) {
        final folders = state.folders;
        final hasError = state.inboxQueryErrorMessage != null;
        final borderColor = hasError
            ? DdtTheme.dangerColor.withValues(alpha: 0.55)
            : DdtTheme.borderSubtle(context);
        final inboxValue = folders == null ? '…' : '${folders.inbox}';
        final sentValue = folders == null ? '…' : '${folders.sent}';

        if (dense) {
          Widget glassStat({
            required FaIconData icon,
            required String label,
            required String value,
          }) {
            return Tooltip(
              message: hasError ? state.inboxQueryErrorMessage! : label,
              child: DdtTheme.shellAppBarGlass(
                context: context,
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * shell,
                  vertical: 8 * shell,
                ),
                child: _MailAppBarStatItem(
                  icon: icon,
                  label: label,
                  value: value,
                  dense: true,
                ),
              ),
            );
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              glassStat(
                icon: DdtIcons.inbox,
                label: 'Входящие',
                value: inboxValue,
              ),
              SizedBox(width: 8 * shell),
              glassStat(
                icon: DdtIcons.mail,
                label: 'Отправленные',
                value: sentValue,
              ),
            ],
          );
        }

        final stats = Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10 * shell,
            vertical: 5 * shell,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: DdtTheme.inputControlBorderRadius,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MailAppBarStatItem(
                icon: DdtIcons.inbox,
                label: 'Входящие',
                value: inboxValue,
                dense: dense,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 * shell),
                child: Container(
                  width: 1,
                  height: 12 * shell,
                  color: DdtTheme.borderStrong(context),
                ),
              ),
              _MailAppBarStatItem(
                icon: DdtIcons.mail,
                label: 'Отправленные',
                value: sentValue,
                dense: dense,
              ),
            ],
          ),
        );

        if (hasError) {
          return Tooltip(message: state.inboxQueryErrorMessage!, child: stats);
        }
        return stats;
      },
    );
  }
}

class _MailAppBarStatItem extends StatelessWidget {
  const _MailAppBarStatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.dense = false,
  });

  final FaIconData icon;
  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shell = DdtTheme.shellSizeOf(context, 1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DdtIcon(
          icon,
          size: 11 * shell,
          color: isDark ? DdtTheme.accentColor : DdtTheme.primaryColor,
        ),
        SizedBox(width: 5 * shell),
        if (!dense) ...[
          Text(
            '$label:',
            style: DdtTheme.style(
              fontSize: DdtTypography.microSize,
              fontWeight: FontWeight.w500,
              color: DdtTheme.textMuted(context),
            ),
          ),
          SizedBox(width: 4 * shell),
        ],
        Text(
          value,
          style: DdtTheme.style(
            fontSize: DdtTypography.captionSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

class _MailAppBarActions extends StatelessWidget {
  const _MailAppBarActions({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailBloc, MailState>(
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.isRefreshingInbox != current.isRefreshingInbox ||
          previous.isSelectionModeActive != current.isSelectionModeActive,
      builder: (context, state) {
        final selectionActive = state.isSelectionModeActive;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AppBarIconAction(
              tooltip: 'Обновить почту',
              icon: DdtIcons.refresh,
              isBusy: state.isLoading || state.isRefreshingInbox,
              onPressed: () => context.read<MailBloc>().add(
                const MailInboxRefreshRequested(showAnimation: true),
              ),
            ),
            SizedBox(width: DdtTheme.shellSizeOf(context, 4)),
            _AppBarIconAction(
              tooltip: selectionActive ? 'Отменить выделение' : 'Выделить',
              icon: DdtIcons.checkCircle,
              isActive: selectionActive,
              onPressed: () {
                final bloc = context.read<MailBloc>();
                if (selectionActive) {
                  bloc.add(const MailSelectionCleared());
                } else {
                  bloc.add(const MailSelectionModeEntered());
                }
              },
            ),
            SizedBox(width: DdtTheme.shellSizeOf(context, 10)),
            _MailAppBarFolderStats(dense: dense),
          ],
        );
      },
    );
  }
}

class _AnalyticsAppBarActions extends StatefulWidget {
  const _AnalyticsAppBarActions();

  @override
  State<_AnalyticsAppBarActions> createState() =>
      _AnalyticsAppBarActionsState();
}

class _AnalyticsAppBarActionsState extends State<_AnalyticsAppBarActions> {
  static const _dashboardKindStorageKey = 'analytics_dashboard_kind';
  static const _dashboardSpaceIdStorageKey = 'analytics_space_id';

  final _storage = GetStorage('ddt_storage');
  late final Future<List<Space>> _spaces = spacesApi.fetchSpaces();

  String _selectionKey(AnalyticsState state) {
    return switch (state.dashboardKind) {
      AnalyticsDashboardKind.stp => 'stp',
      AnalyticsDashboardKind.tasksPersonal => 'personal',
      AnalyticsDashboardKind.tasksSpace => 'space:${state.spaceId ?? 0}',
    };
  }

  String _selectionLabel(AnalyticsState state, List<Space> spaces) {
    return switch (state.dashboardKind) {
      AnalyticsDashboardKind.stp => 'КРР МР — Аналитика СТП',
      AnalyticsDashboardKind.tasksPersonal => 'Личные задачи',
      AnalyticsDashboardKind.tasksSpace => () {
        final id = state.spaceId;
        Space? space;
        for (final item in spaces) {
          if (item.id == id) {
            space = item;
            break;
          }
        }
        final name = space?.name ?? state.dashboard?.spaceName;
        return name != null ? 'Задачи $name' : 'Задачи пространства';
      }(),
    };
  }

  void _selectDashboard(
    BuildContext context, {
    required AnalyticsDashboardKind kind,
    int? spaceId,
  }) {
    _storage.write(_dashboardKindStorageKey, switch (kind) {
      AnalyticsDashboardKind.stp => 'stp',
      AnalyticsDashboardKind.tasksPersonal => 'personal',
      AnalyticsDashboardKind.tasksSpace => 'space',
    });
    if (kind == AnalyticsDashboardKind.tasksSpace) {
      _storage.write(_dashboardSpaceIdStorageKey, spaceId);
    } else {
      _storage.remove(_dashboardSpaceIdStorageKey);
    }
    context.read<AnalyticsBloc>().add(
      AnalyticsDashboardSourceChanged(kind: kind, spaceId: spaceId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.dashboardKind != current.dashboardKind ||
          previous.spaceId != current.spaceId ||
          previous.dashboard?.sheetName != current.dashboard?.sheetName,
      builder: (context, state) {
        final loading = state.isLoading && state.dashboard == null;

        return FutureBuilder<List<Space>>(
          future: _spaces,
          builder: (context, snapshot) {
            final spaces = snapshot.data ?? const <Space>[];
            final selectedKey = _selectionKey(state);
            final label = loading
                ? 'Загрузка…'
                : _selectionLabel(state, spaces);

            final options = [
              const DdtFilterOption(
                key: 'stp',
                label: 'КРР МР — Аналитика СТП',
              ),
              const DdtFilterOption(key: 'personal', label: 'Личные задачи'),
              for (final space in spaces)
                DdtFilterOption(
                  key: 'space:${space.id}',
                  label: 'Задачи ${space.name}',
                ),
            ];

            return _AppBarFilterDropdown(
              width: 280,
              label: label,
              isBusy:
                  loading ||
                  snapshot.connectionState == ConnectionState.waiting,
              active: !loading,
              options: options,
              selected: loading ? const {} : {selectedKey},
              emptyLabel: 'Нет дашбордов',
              onSelected: (key) {
                if (key == 'stp') {
                  _selectDashboard(context, kind: AnalyticsDashboardKind.stp);
                  return;
                }
                if (key == 'personal') {
                  _selectDashboard(
                    context,
                    kind: AnalyticsDashboardKind.tasksPersonal,
                  );
                  return;
                }
                if (key.startsWith('space:')) {
                  final id = int.tryParse(key.substring('space:'.length));
                  if (id == null) return;
                  _selectDashboard(
                    context,
                    kind: AnalyticsDashboardKind.tasksSpace,
                    spaceId: id,
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

/// Date and previous/next controls centered in the calendar app bar.
class CalendarAppBarDateNav extends StatelessWidget {
  const CalendarAppBarDateNav({super.key});

  @override
  Widget build(BuildContext context) {
    final foregroundColor = DdtTheme.textPrimary(context);

    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) =>
          previous.viewMode != current.viewMode ||
          previous.focusedDate != current.focusedDate,
      builder: (context, state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AppBarIconAction(
              tooltip: 'Назад',
              icon: DdtIcons.chevronLeft,
              onPressed: () => context.read<CalendarBloc>().add(
                const CalendarGoPreviousRequested(),
              ),
            ),
            SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
            Text(
              state.titleLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DdtTheme.style(
                fontSize: DdtTypography.bodyLargeSize,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
            SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
            _AppBarIconAction(
              tooltip: 'Вперёд',
              icon: DdtIcons.chevronRight,
              onPressed: () => context.read<CalendarBloc>().add(
                const CalendarGoNextRequested(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CalendarAppBarActions extends StatelessWidget {
  const _CalendarAppBarActions();

  static const _addCalendarMenuItems = [
    DdtContextMenuItem(
      icon: DdtIcons.calendar,
      label: 'Дополнительный календарь',
      onTap: _noop,
    ),
    DdtContextMenuItem(
      icon: DdtIcons.fileLines,
      label: 'Из файла',
      onTap: _noop,
    ),
    DdtContextMenuItem(
      icon: DdtIcons.globe,
      label: 'Из интернета',
      onTap: _noop,
    ),
    DdtContextMenuItem(icon: DdtIcons.book, label: 'Из каталога', onTap: _noop),
  ];

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.isRefreshing != current.isRefreshing ||
          previous.viewMode != current.viewMode,
      builder: (context, state) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CalendarViewSwitcher(),
          SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
          _AppBarIconAction(
            tooltip: 'Обновить календарь',
            icon: DdtIcons.refresh,
            isBusy: state.isRefreshing || state.isLoading,
            onPressed: () => context.read<CalendarBloc>().add(
              const CalendarEventsRefreshRequested(showAnimation: true),
            ),
          ),
          SizedBox(width: DdtTheme.shellSizeOf(context, 4)),
          const _AppBarIconAction(
            tooltip: 'Добавить календарь',
            icon: DdtIcons.calendarPlus,
            contextMenuItems: _addCalendarMenuItems,
          ),
        ],
      ),
    );
  }
}

class _AppBarFilterDropdown extends StatelessWidget {
  const _AppBarFilterDropdown({
    required this.width,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.isBusy = false,
    this.active = false,
    this.emptyLabel = 'Нет значений',
  });

  final double width;
  final String label;
  final List<DdtFilterOption> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  final bool isBusy;
  final bool active;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final menuWidth = DdtTheme.shellSizeOf(context, width);

    return SizedBox(
      width: menuWidth,
      height: kDdtCompactFilterDropdownHeight,
      child: Builder(
        builder: (anchorContext) {
          return DdtFilterDropdownAnchor(
            label: label,
            active: active,
            compact: true,
            onTap: isBusy
                ? () {}
                : () => showDdtSearchableFilterMenu(
                    context: context,
                    anchorContext: anchorContext,
                    options: options,
                    selected: selected,
                    onSelected: onSelected,
                    multi: false,
                    emptyLabel: emptyLabel,
                    menuWidth: menuWidth,
                  ),
          );
        },
      ),
    );
  }
}

class _AppBarIconAction extends StatefulWidget {
  const _AppBarIconAction({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.contextMenuItems,
    this.isBusy = false,
    this.isActive = false,
  });

  final String tooltip;
  final FaIconData icon;
  final VoidCallback? onPressed;
  final List<DdtContextMenuItem>? contextMenuItems;
  final bool isBusy;
  final bool isActive;

  @override
  State<_AppBarIconAction> createState() => _AppBarIconActionState();
}

class _AppBarIconActionState extends State<_AppBarIconAction> {
  final _anchorKey = GlobalKey();
  bool _hovered = false;

  void _handlePressed() {
    if (widget.contextMenuItems != null) {
      showDdtContextMenu(
        context: context,
        anchorKey: _anchorKey,
        items: widget.contextMenuItems!,
        placement: DdtContextMenuPlacement.belowCenter,
      );
      return;
    }

    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = widget.isActive
        ? (isDark ? DdtTheme.accentColor : DdtTheme.primaryColor)
        : (_hovered
              ? DdtTheme.textPrimary(context)
              : DdtTheme.textSecondary(context));
    final iconSize = DdtGlassAppBar.actionIconSizeOf(context);

    final onPressed = widget.isBusy ? null : _handlePressed;
    final icon = widget.isBusy
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor.withValues(alpha: 0.7),
            ),
          )
        : DdtIcon(widget.icon, color: foregroundColor, size: iconSize);

    final bgColor = widget.isActive
        ? DdtTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.10)
        : (_hovered
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF1F5F9))
              : Colors.transparent);

    return KeyedSubtree(
      key: _anchorKey,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: DdtTheme.inputControlBorderRadius,
            border: Border.all(
              color: widget.isActive
                  ? DdtTheme.primaryColor.withValues(
                      alpha: isDark ? 0.35 : 0.22,
                    )
                  : Colors.transparent,
            ),
          ),
          child: IconButton(
            tooltip: widget.tooltip,
            visualDensity: VisualDensity.compact,
            padding: DdtGlassAppBar.actionIconButtonPadding(context),
            constraints: DdtGlassAppBar.actionIconButtonConstraints(context),
            onPressed: onPressed,
            icon: icon,
          ),
        ),
      ),
    );
  }
}

/// Day / week / month switch shared by the app bar and the phone dock.
class CalendarViewSwitcher extends StatelessWidget {
  const CalendarViewSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) => previous.viewMode != current.viewMode,
      builder: (context, state) {
        return DdtSegmentedControl<CalendarViewMode>(
          segments: const [
            DdtSegmentedControlSegment(
              value: CalendarViewMode.day,
              label: 'День',
              icon: DdtIcons.clock,
            ),
            DdtSegmentedControlSegment(
              value: CalendarViewMode.week,
              label: 'Неделя',
              icon: DdtIcons.calendar,
            ),
            DdtSegmentedControlSegment(
              value: CalendarViewMode.month,
              label: 'Месяц',
              icon: DdtIcons.calendarPlus,
            ),
          ],
          selected: state.viewMode,
          onChanged: (mode) =>
              context.read<CalendarBloc>().add(CalendarViewModeChanged(mode)),
        );
      },
    );
  }
}

/// Format switcher floating above the phone navigation bar.
class CalendarMobileViewBar extends StatelessWidget {
  const CalendarMobileViewBar({super.key});

  static const double reserve = 64;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CalendarViewSwitcher(),
          _CalendarRefreshAction(),
          _CalendarAddAction(),
        ],
      ),
    );
  }
}

class _CalendarRefreshAction extends StatelessWidget {
  const _CalendarRefreshAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.isRefreshing != current.isRefreshing,
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.only(left: DdtTheme.shellSizeOf(context, 8)),
          child: _AppBarIconAction(
            tooltip: 'Обновить календарь',
            icon: DdtIcons.refresh,
            isBusy: state.isRefreshing || state.isLoading,
            onPressed: () => context.read<CalendarBloc>().add(
              const CalendarEventsRefreshRequested(showAnimation: true),
            ),
          ),
        );
      },
    );
  }
}

class _CalendarAddAction extends StatelessWidget {
  const _CalendarAddAction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: DdtTheme.shellSizeOf(context, 4)),
      child: const _AppBarIconAction(
        tooltip: 'Добавить календарь',
        icon: DdtIcons.calendarPlus,
        contextMenuItems: _CalendarAppBarActions._addCalendarMenuItems,
      ),
    );
  }
}

/// View switcher and archive button floating over the task list.
class TasksMobileViewBar extends StatelessWidget {
  const TasksMobileViewBar({super.key});

  static const double reserve = 64;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: _TasksAppBarActions(),
    );
  }
}

/// Refresh, selection and folder counts floating over the message list.
class MailMobileDock extends StatelessWidget {
  const MailMobileDock({super.key});

  static const double reserve = 56;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: _MailAppBarActions(dense: true),
    );
  }
}
