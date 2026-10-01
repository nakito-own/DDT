import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import '../theme/ddt_typography.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../theme/ddt_icons.dart';

import '../blocs/analytics/analytics_bloc.dart';
import '../blocs/calendar/calendar_bloc.dart';
import '../blocs/mail/mail_bloc.dart';
import '../models/app_section.dart';
import '../models/space.dart';
import '../models/tasks_view_mode.dart';
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
      r'^/space/([^/]+)/(kanban|list|gantt)$',
    ).firstMatch(location);
    if (board != null) return board.group(1);
    final task = RegExp(r'^/space/(.+)-\d+$').firstMatch(location);
    return task?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedSpaceKey = _spaceKeyFromLocation(location);
    final activeMode = TasksViewMode.fromRoute(location);

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
          selected: activeMode,
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
          onPressed: () {},
        ),
        SizedBox(width: DdtTheme.shellSizeOf(context, 12)),
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
              onSelected: (key) =>
                  context.go(activeMode.routePathForSpace(key)),
            );
          },
        ),
      ],
    );
  }
}

class _TasksAppBarActions extends StatelessWidget {
  const _TasksAppBarActions();

  @override
  Widget build(BuildContext context) {
    // Активный вид определяется из URL — GoRouter является источником истины.
    // Это гарантирует корректное отображение при прямом открытии URL
    // (например, /tasks/list) и при навигации через кнопки браузера.
    final location = GoRouterState.of(context).matchedLocation;
    final activeMode = TasksViewMode.fromRoute(location);

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
          selected: activeMode,
          onChanged: (mode) => context.go(mode.routePath),
        ),
        SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
        _AppBarIconAction(
          tooltip: 'Архив',
          icon: DdtIcons.archive,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _MailAppBarFolderStats extends StatelessWidget {
  const _MailAppBarFolderStats();

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
            ? AppColors.error.withValues(alpha: 0.55)
            : AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.22);

        final stats = Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10 * shell,
            vertical: 4 * shell,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MailAppBarStatItem(
                icon: DdtIcons.inbox,
                label: 'Входящие',
                value: folders == null ? '…' : '${folders.inbox}',
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 * shell),
                child: Container(
                  width: 1,
                  height: 12 * shell,
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.35 : 0.25,
                  ),
                ),
              ),
              _MailAppBarStatItem(
                icon: DdtIcons.mail,
                label: 'Отправленные',
                value: folders == null ? '…' : '${folders.sent}',
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
  });

  final FaIconData icon;
  final String label;
  final String value;

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
          color: AppColors.primary.withValues(alpha: 0.9),
        ),
        SizedBox(width: 4 * shell),
        Text(
          '$label:',
          style: DdtTheme.style(
            fontSize: DdtTypography.microSize,
            fontWeight: FontWeight.w500,
            color: DdtTheme.taskCardTextSecondary(context),
          ),
        ),
        SizedBox(width: 3 * shell),
        Text(
          value,
          style: DdtTheme.style(
            fontSize: DdtTypography.captionSize,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _MailAppBarActions extends StatelessWidget {
  const _MailAppBarActions();

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
            const _MailAppBarFolderStats(),
          ],
        );
      },
    );
  }
}

class _AnalyticsAppBarActions extends StatelessWidget {
  const _AnalyticsAppBarActions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading ||
          previous.dashboard?.sheetName != current.dashboard?.sheetName,
      builder: (context, state) {
        final sheetName = state.dashboard?.sheetName.trim();
        final label = sheetName != null && sheetName.isNotEmpty
            ? sheetName
            : 'Google Таблица';

        final loading = state.isLoading && state.dashboard == null;
        const sheetKey = 'current-sheet';
        const addDashboardKey = 'add-dashboard';

        return _AppBarFilterDropdown(
          width: 240,
          label: loading ? 'Загрузка…' : label,
          isBusy: loading,
          active: !loading,
          options: [
            DdtFilterOption(key: sheetKey, label: label),
            const DdtFilterOption(
              key: addDashboardKey,
              label: 'Добавить дашборд',
              enabled: false,
            ),
          ],
          selected: loading ? const {} : {sheetKey},
          emptyLabel: 'Нет источников',
          onSelected: (_) {},
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
          previous.isRefreshing != current.isRefreshing,
      builder: (context, state) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    this.label,
    this.onPressed,
    this.contextMenuItems,
    this.placement = DdtContextMenuPlacement.belowCenter,
    this.isBusy = false,
    this.isActive = false,
  });

  final String tooltip;
  final FaIconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final List<DdtContextMenuItem>? contextMenuItems;
  final DdtContextMenuPlacement placement;
  final bool isBusy;
  final bool isActive;

  @override
  State<_AppBarIconAction> createState() => _AppBarIconActionState();
}

class _AppBarIconActionState extends State<_AppBarIconAction> {
  final _anchorKey = GlobalKey();

  void _handlePressed() {
    if (widget.contextMenuItems != null) {
      showDdtContextMenu(
        context: context,
        anchorKey: _anchorKey,
        items: widget.contextMenuItems!,
        placement: widget.placement,
      );
      return;
    }

    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foregroundColor = widget.isActive
        ? AppColors.primary
        : (isDark ? Colors.white : AppColors.primary);
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

    return KeyedSubtree(
      key: _anchorKey,
      child: widget.label == null
          ? IconButton(
              tooltip: widget.tooltip,
              visualDensity: VisualDensity.compact,
              padding: DdtGlassAppBar.actionIconButtonPadding(context),
              constraints: DdtGlassAppBar.actionIconButtonConstraints(context),
              style: widget.isActive
                  ? IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(
                        alpha: isDark ? 0.22 : 0.12,
                      ),
                    )
                  : null,
              onPressed: onPressed,
              icon: icon,
            )
          : Tooltip(
              message: widget.tooltip,
              child: TextButton.icon(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: foregroundColor,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(
                    horizontal: DdtTheme.shellSizeOf(context, 8),
                    vertical: DdtTheme.shellSizeOf(context, 4),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: DdtTheme.radius),
                ),
                iconAlignment: IconAlignment.end,
                icon: icon,
                label: Text(
                  widget.label!,
                  style: DdtTheme.style(
                    fontSize: DdtTypography.labelSmallSize,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                ),
              ),
            ),
    );
  }
}
