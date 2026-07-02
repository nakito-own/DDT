import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../blocs/mail/mail_bloc.dart';
import '../blocs/tasks/tasks_bloc.dart';
import '../models/app_section.dart';
import '../models/tasks_view_mode.dart';
import '../theme/ddt_theme.dart';
import 'ddt_context_menu.dart';

class DdtAppBarSectionActions extends StatelessWidget {
  const DdtAppBarSectionActions({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AppSection.tasks => const _TasksAppBarActions(),
      AppSection.mail => const _MailAppBarActions(),
      AppSection.calendar => const _CalendarAppBarActions(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _TasksAppBarActions extends StatelessWidget {
  const _TasksAppBarActions();

  @override
  Widget build(BuildContext context) {
    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    return BlocBuilder<TasksBloc, TasksState>(
      buildWhen: (previous, current) =>
          previous.viewMode != current.viewMode,
      builder: (context, state) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppBarSegmentedControl<TasksViewMode>(
            segments: const [
              _AppBarSegment(value: TasksViewMode.kanban, label: 'Канбан'),
              _AppBarSegment(value: TasksViewMode.list, label: 'Список'),
              _AppBarSegment(value: TasksViewMode.gantt, label: 'Гант'),
            ],
            selected: state.viewMode,
            onChanged: (mode) => context
                .read<TasksBloc>()
                .add(TasksViewModeChanged(mode)),
            textSecondary: textSecondary,
          ),
          SizedBox(width: DdtTheme.shellSizeOf(context, 8)),
          _AppBarIconAction(
            tooltip: 'Архив',
            icon: CupertinoIcons.archivebox,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _MailAppBarActions extends StatelessWidget {
  const _MailAppBarActions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailBloc, MailState>(
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading,
      builder: (context, state) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppBarIconAction(
            tooltip: 'Обновить почту',
            icon: CupertinoIcons.arrow_clockwise,
            isLoading: state.isLoading,
            onPressed: () => context
                .read<MailBloc>()
                .add(const MailInboxRefreshRequested()),
          ),
          SizedBox(width: DdtTheme.shellSizeOf(context, 4)),
          const _AppBarIconAction(
            tooltip: 'Выделить',
            icon: CupertinoIcons.checkmark_circle,
          ),
        ],
      ),
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
      buildWhen: (previous, current) =>
          previous.isLoading != current.isLoading,
      builder: (context, state) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppBarIconAction(
            tooltip: 'Обновить календарь',
            icon: CupertinoIcons.arrow_clockwise,
            isLoading: state.isLoading,
            onPressed: () => context
                .read<CalendarBloc>()
                .add(const CalendarEventsRefreshRequested()),
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

class _AppBarSegment<T> {
  const _AppBarSegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class _AppBarSegmentedControl<T> extends StatelessWidget {
  const _AppBarSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.textSecondary,
  });

  final List<_AppBarSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SegmentedButton<T>(
      segments: [
        for (final segment in segments)
          ButtonSegment(
            value: segment.value,
            label: Text(segment.label),
            icon: segment.icon == null
                ? null
                : Icon(segment.icon, size: 16.sp),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        ),
        textStyle: WidgetStatePropertyAll(DdtTheme.style(fontSize: 12.sp)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withValues(alpha: 0.85);
          }
          return textSecondary;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(
              color: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.2),
            );
          }
          return BorderSide.none;
        }),
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
    this.placement = DdtContextMenuPlacement.belowCenter,
    this.isLoading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final List<DdtContextMenuItem>? contextMenuItems;
  final DdtContextMenuPlacement placement;
  final bool isLoading;

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
    final foregroundColor = isDark ? Colors.white : AppColors.primary;
    final iconSize = DdtTheme.shellSizeOf(context, 20);

    return KeyedSubtree(
      key: _anchorKey,
      child: IconButton(
        tooltip: widget.tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: widget.isLoading ? null : _handlePressed,
        icon: widget.isLoading
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor.withValues(alpha: 0.7),
                ),
              )
            : Icon(widget.icon, color: foregroundColor, size: iconSize),
      ),
    );
  }
}
