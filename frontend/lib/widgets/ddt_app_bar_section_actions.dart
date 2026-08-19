import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../blocs/mail/mail_bloc.dart';
import '../models/app_section.dart';
import '../models/space.dart';
import '../models/tasks_view_mode.dart';
import '../services/spaces_api.dart';
import '../theme/ddt_theme.dart';
import 'compose_mail_panel.dart';
import 'ddt_context_menu.dart';
import 'ddt_segmented_control.dart';

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

  int? _spaceIdFromLocation(String location) {
    final match = RegExp(r'^/space/(\d+)').firstMatch(location);
    return int.tryParse(match?.group(1) ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedSpaceId = _spaceIdFromLocation(location);
    final activeMode = TasksViewMode.fromRoute(location);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder<List<Space>>(
          future: _spaces,
          builder: (context, snapshot) {
            final spaces = snapshot.data ?? const <Space>[];
            Space? selectedSpace;
            for (final space in spaces) {
              if (space.id == selectedSpaceId) {
                selectedSpace = space;
                break;
              }
            }

            return _AppBarIconAction(
              tooltip: 'Выбрать пространство',
              label: selectedSpace?.name ?? 'ПРОСТРАНСТВО',
              icon: CupertinoIcons.chevron_down,
              isLoading: snapshot.connectionState == ConnectionState.waiting,
              contextMenuItems: spaces.isEmpty
                  ? null
                  : [
                      for (final space in spaces)
                        DdtContextMenuItem(
                          icon: CupertinoIcons.square_grid_2x2,
                          label: space.name,
                          onTap: () => context.go(
                            activeMode.routePathForSpace(space.id),
                          ),
                        ),
                    ],
            );
          },
        ),
        SizedBox(width: DdtTheme.shellSizeOf(context, 12)),
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
            if (selectedSpaceId != null) {
              context.go(mode.routePathForSpace(selectedSpaceId));
            }
          },
        ),
        SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
        _AppBarIconAction(
          tooltip: 'Архив',
          icon: CupertinoIcons.archivebox,
          onPressed: () {},
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
          icon: CupertinoIcons.archivebox,
          onPressed: () {},
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
              icon: CupertinoIcons.arrow_clockwise,
              isLoading: state.isLoading || state.isRefreshingInbox,
              onPressed: () => context.read<MailBloc>().add(
                const MailInboxRefreshRequested(showAnimation: true),
              ),
            ),
            SizedBox(width: DdtTheme.shellSizeOf(context, 4)),
            _AppBarIconAction(
              tooltip: selectionActive ? 'Отменить выделение' : 'Выделить',
              icon: CupertinoIcons.checkmark_circle,
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
            SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
            _AppBarTextAction(
              label: 'Написать',
              icon: Icons.edit_outlined,
              filled: true,
              onPressed: () => showComposeMailPanel(context),
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
      icon: CupertinoIcons.calendar,
      label: 'Дополнительный календарь',
      onTap: _noop,
    ),
    DdtContextMenuItem(
      icon: CupertinoIcons.doc,
      label: 'Из файла',
      onTap: _noop,
    ),
    DdtContextMenuItem(
      icon: CupertinoIcons.globe,
      label: 'Из интернета',
      onTap: _noop,
    ),
    DdtContextMenuItem(
      icon: CupertinoIcons.book,
      label: 'Из каталога',
      onTap: _noop,
    ),
  ];

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (previous, current) => previous.isLoading != current.isLoading,
      builder: (context, state) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppBarIconAction(
            tooltip: 'Обновить календарь',
            icon: CupertinoIcons.arrow_clockwise,
            isLoading: state.isLoading,
            onPressed: () => context.read<CalendarBloc>().add(
              const CalendarEventsRefreshRequested(),
            ),
          ),
          SizedBox(width: DdtTheme.shellSizeOf(context, 4)),
          const _AppBarIconAction(
            tooltip: 'Добавить календарь',
            icon: CupertinoIcons.calendar_badge_plus,
            contextMenuItems: _addCalendarMenuItems,
          ),
        ],
      ),
    );
  }
}

class _AppBarTextAction extends StatelessWidget {
  const _AppBarTextAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = filled
        ? Colors.white
        : (isDark ? Colors.white : AppColors.primary);

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        backgroundColor: filled ? AppColors.primary : null,
        padding: EdgeInsets.symmetric(
          horizontal: DdtTheme.shellSizeOf(context, 10),
          vertical: DdtTheme.shellSizeOf(context, 6),
        ),
        shape: filled
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  DdtTheme.shellSizeOf(context, 8),
                ),
              )
            : null,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: DdtTheme.shellSizeOf(context, 16)),
      label: Text(
        label,
        style: DdtTheme.style(
          fontSize: DdtTheme.shellSizeOf(context, 14),
          fontWeight: FontWeight.w600,
          color: foregroundColor,
        ),
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
    this.isLoading = false,
    this.isActive = false,
  });

  final String tooltip;
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final List<DdtContextMenuItem>? contextMenuItems;
  final DdtContextMenuPlacement placement;
  final bool isLoading;
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
    final iconSize = DdtTheme.shellSizeOf(context, 20);

    final onPressed = widget.isLoading ? null : _handlePressed;
    final icon = widget.isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor.withValues(alpha: 0.7),
            ),
          )
        : Icon(widget.icon, color: foregroundColor, size: iconSize);

    return KeyedSubtree(
      key: _anchorKey,
      child: widget.label == null
          ? IconButton(
              tooltip: widget.tooltip,
              visualDensity: VisualDensity.compact,
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
                    horizontal: DdtTheme.shellSizeOf(context, 10),
                    vertical: DdtTheme.shellSizeOf(context, 6),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: DdtTheme.radius),
                ),
                iconAlignment: IconAlignment.end,
                icon: icon,
                label: Text(
                  widget.label!,
                  style: DdtTheme.style(
                    fontSize: DdtTheme.shellSizeOf(context, 14),
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                ),
              ),
            ),
    );
  }
}
