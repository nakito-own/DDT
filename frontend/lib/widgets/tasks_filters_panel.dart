import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';
import '../theme/ddt_theme.dart';
import 'ddt_app_input.dart';
import '../theme/ddt_typography.dart';
import 'ddt_filter_dropdown.dart';
import '../widgets/ddt_icon.dart';

/// Fixed width of the tasks filter column (slightly narrower than analytics).
const kTasksFiltersPanelWidth = 272.0;

/// Horizontal inset for hover/shadow; all controls share this width.
EdgeInsets _tasksFiltersContentPadding() =>
    EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 12.h);

/// Vertical-only inset so controls align with search (no extra horizontal shrink).
class _TasksFiltersControlSlot extends StatelessWidget {
  const _TasksFiltersControlSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class TasksFiltersPanel extends StatefulWidget {
  const TasksFiltersPanel({super.key, this.onCreatePressed});

  final VoidCallback? onCreatePressed;

  @override
  State<TasksFiltersPanel> createState() => _TasksFiltersPanelState();
}

class _TasksFiltersPanelState extends State<TasksFiltersPanel> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<TasksBloc>().state.searchQuery,
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final bloc = context.read<TasksBloc>();
    final query = _searchController.text;
    if (query == bloc.state.searchQuery) return;
    bloc.add(TasksSearchQueryChanged(query));
  }

  void _syncSearchFromBloc(String query) {
    if (_searchController.text == query) return;
    _searchController.text = query;
  }

  static TaskStatus? _statusFromKey(String key) {
    for (final status in TaskStatus.values) {
      if (status.value == key) return status;
    }
    return null;
  }

  static TaskPriority? _priorityFromKey(String key) {
    if (key.isEmpty) return null;
    return TaskPriority.fromValue(key);
  }

  static TasksSortOption? _sortFromKey(String key) {
    for (final option in TasksSortOption.values) {
      if (option.name == key) return option;
    }
    return null;
  }

  bool _hasActiveFilters(TasksState state) {
    final allStatuses = state.statusFilters.length == TaskStatus.values.length;
    return state.searchQuery.trim().isNotEmpty ||
        !allStatuses ||
        state.priorityFilter != null ||
        state.typeFilter != null ||
        state.sortOption != TasksSortOption.deadlineAsc;
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final textSecondary = DdtTheme.taskCardTextSecondary(context);
    final dividerColor = DdtTheme.sidePanelDivider(context);

    return BlocConsumer<TasksBloc, TasksState>(
      listenWhen: (previous, current) =>
          previous.searchQuery != current.searchQuery,
      listener: (context, state) => _syncSearchFromBloc(state.searchQuery),
      buildWhen: (previous, current) =>
          previous.searchQuery != current.searchQuery ||
          previous.statusFilters != current.statusFilters ||
          previous.priorityFilter != current.priorityFilter ||
          previous.typeFilter != current.typeFilter ||
          previous.sortOption != current.sortOption ||
          previous.taskTypes != current.taskTypes ||
          previous.filteredTasks.length != current.filteredTasks.length,
      builder: (context, state) {
        final statusOptions = [
          for (final status in TaskStatus.values)
            DdtFilterOption(key: status.value, label: status.label),
        ];
        final selectedStatuses = {
          for (final status in state.statusFilters) status.value,
        };
        final allStatusesSelected =
            selectedStatuses.length == TaskStatus.values.length;

        final priorityOptions = [
          const DdtFilterOption(key: '', label: 'Все приоритеты'),
          for (final priority in TaskPriority.values)
            DdtFilterOption(key: priority.value, label: priority.label),
        ];
        final selectedPriority = {
          if (state.priorityFilter != null)
            state.priorityFilter!.value
          else
            '',
        };

        final typeOptions = [
          const DdtFilterOption(key: '', label: 'Все типы'),
          for (final type in state.taskTypes)
            DdtFilterOption(key: '${type.id}', label: type.name),
        ];
        final selectedType = {
          if (state.typeFilter != null) '${state.typeFilter}' else '',
        };

        final sortOptions = [
          for (final option in TasksSortOption.values)
            DdtFilterOption(key: option.name, label: option.label),
        ];
        final selectedSort = {state.sortOption.name};

        return ListView(
          padding: _tasksFiltersContentPadding(),
          children: [
            if (widget.onCreatePressed != null) ...[
              _TasksFiltersControlSlot(
                child: _TasksCreateButton(onPressed: widget.onCreatePressed!),
              ),
              SizedBox(height: 10.h),
            ],
            Row(
              children: [
                DdtIcon(
                  DdtIcons.sliders,
                  size: 18.sp,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Фильтры',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.sectionTitleSize,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _TasksFiltersControlSlot(
              child: DdtAppInput(
                label: 'Поиск',
                hint: 'Поиск по названию',
                controller: _searchController,
                type: InputType.search,
                prefixIcon: DdtIcons.search,
              ),
            ),
            SizedBox(height: 10.h),
            const DdtFilterLabel('Статус'),
            SizedBox(height: 4.h),
            _TasksFiltersControlSlot(
              child: DdtSearchableFilterDropdown(
                summary: ddtFilterSelectionSummary(
                  selectedStatuses,
                  statusOptions,
                  emptyLabel: 'Все статусы',
                ),
                active: !allStatusesSelected,
                options: statusOptions,
                selected: selectedStatuses,
                emptyLabel: 'Нет статусов',
                onSelected: (key) {
                  final status = _statusFromKey(key);
                  if (status != null) {
                    context.read<TasksBloc>().add(
                      TasksStatusFilterToggled(status),
                    );
                  }
                },
              ),
            ),
            SizedBox(height: 10.h),
            const DdtFilterLabel('Приоритет'),
            SizedBox(height: 4.h),
            _TasksFiltersControlSlot(
              child: DdtSearchableFilterDropdown(
                summary: state.priorityFilter?.label ?? 'Все приоритеты',
                active: state.priorityFilter != null,
                options: priorityOptions,
                selected: selectedPriority,
                multi: false,
                onSelected: (key) {
                  context.read<TasksBloc>().add(
                    TasksPriorityFilterChanged(_priorityFromKey(key)),
                  );
                },
              ),
            ),
            if (state.taskTypes.isNotEmpty) ...[
              SizedBox(height: 10.h),
              const DdtFilterLabel('Тип'),
              SizedBox(height: 4.h),
              _TasksFiltersControlSlot(
                child: DdtSearchableFilterDropdown(
                  summary: state.taskTypes
                          .where((t) => t.id == state.typeFilter)
                          .map((t) => t.name)
                          .firstOrNull ??
                      'Все типы',
                  active: state.typeFilter != null,
                  options: typeOptions,
                  selected: selectedType,
                  multi: false,
                  onSelected: (key) {
                    final typeId = key.isEmpty ? null : int.tryParse(key);
                    context.read<TasksBloc>().add(
                      TasksTypeFilterChanged(typeId),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 10.h),
            const DdtFilterLabel('Сортировка'),
            SizedBox(height: 4.h),
            _TasksFiltersControlSlot(
              child: DdtSearchableFilterDropdown(
                summary: state.sortOption.label,
                active: state.sortOption != TasksSortOption.deadlineAsc,
                options: sortOptions,
                selected: selectedSort,
                multi: false,
                onSelected: (key) {
                  final option = _sortFromKey(key);
                  if (option != null) {
                    context.read<TasksBloc>().add(
                      TasksSortOptionChanged(option),
                    );
                  }
                },
              ),
            ),
            SizedBox(height: 16.h),
            Divider(height: 1, thickness: 1, color: dividerColor),
            SizedBox(height: 12.h),
            _TasksFiltersControlSlot(
              child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.12
                      : 0.07,
                ),
                borderRadius: DdtTheme.radius,
                border: Border.all(
                  color: AppColors.primary.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.28
                        : 0.18,
                  ),
                ),
              ),
              child: Text(
                'Найдено: ${state.filteredTasks.length}',
                style: DdtTheme.style(
                  fontSize: DdtTypography.labelSize,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            ),
            if (_hasActiveFilters(state)) ...[
              SizedBox(height: 12.h),
              _TasksFiltersControlSlot(
                child: Button(
                  text: 'Сбросить фильтры',
                  type: ButtonType.outlined,
                  width: double.infinity,
                  onPressed: () =>
                      context.read<TasksBloc>().add(const TasksFiltersReset()),
                  borderRadius: DdtTheme.radius,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TasksCreateButton extends StatefulWidget {
  const _TasksCreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_TasksCreateButton> createState() => _TasksCreateButtonState();
}

class _TasksCreateButtonState extends State<_TasksCreateButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = AppColors.primary;
    final fill = _hovered
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: isDark ? 0.14 : 0.2),
            base,
          )
        : base;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hovered ? 1.015 : 1,
          duration: DdtTheme.selectionAnimationDuration,
          curve: DdtTheme.selectionAnimationCurve,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: DdtTheme.selectionAnimationDuration,
            curve: DdtTheme.selectionAnimationCurve,
            width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: DdtTheme.radius,
                boxShadow: _hovered
                    ? DdtTheme.inputFocusShadow(context)
                    : [
                        BoxShadow(
                          color: base.withValues(alpha: 0.22),
                          blurRadius: 4,
                          offset: Offset(0, 1.5.h),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: _hovered ? 1.08 : 1,
                    duration: DdtTheme.selectionAnimationDuration,
                    curve: DdtTheme.selectionAnimationCurve,
                    child: DdtIcon(
                      DdtIcons.add,
                      size: 14.sp,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 7.w),
                  Text(
                    'Создать',
                    style: DdtTheme.style(
                      fontSize: DdtTypography.labelSmallSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
