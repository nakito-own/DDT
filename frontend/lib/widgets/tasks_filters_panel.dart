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
import 'ddt_panel_primary_button.dart';
import 'ddt_section_sidebar.dart';

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
          if (state.priorityFilter != null) state.priorityFilter!.value else '',
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

        return DdtSectionSidebarScroll(
          child: ListView(
            clipBehavior: Clip.none,
            padding: DdtSectionSidebar.scrollContentPadding(),
            children: [
              if (widget.onCreatePressed != null) ...[
                DdtSectionSidebarField(
                  gapAbove: false,
                  child: DdtPanelPrimaryButton(
                    label: 'Создать',
                    icon: DdtIcons.add,
                    onPressed: widget.onCreatePressed!,
                  ),
                ),
                SizedBox(height: DdtSectionSidebar.afterPrimaryButtonGap),
              ],
              const DdtSectionSidebarTitle(),
              SizedBox(height: DdtSectionSidebar.afterTitleGap),
              DdtSectionSidebarField(
                label: 'Поиск',
                gapAbove: false,
                child: DdtAppInput(
                  hint: 'Поиск по названию',
                  controller: _searchController,
                  type: InputType.search,
                  variant: DdtInputVariant.compact,
                  prefixIcon: DdtIcons.search,
                  borderRadius: DdtTheme.radius,
                ),
              ),
              DdtSectionSidebarField(
                label: 'Статус',
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
              DdtSectionSidebarField(
                label: 'Приоритет',
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
              if (state.taskTypes.isNotEmpty)
                DdtSectionSidebarField(
                  label: 'Тип',
                  child: DdtSearchableFilterDropdown(
                    summary:
                        state.taskTypes
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
              DdtSectionSidebarField(
                label: 'Сортировка',
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
              SizedBox(height: DdtSectionSidebar.blockGap),
              Divider(height: 1, thickness: 1, color: dividerColor),
              SizedBox(height: DdtSectionSidebar.afterDividerGap),
              DdtSectionSidebarField(
                gapAbove: false,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
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
              if (_hasActiveFilters(state))
                DdtSectionSidebarField(
                  child: Button(
                    text: 'Сбросить фильтры',
                    type: ButtonType.outlined,
                    width: double.infinity,
                    onPressed: () => context.read<TasksBloc>().add(
                      const TasksFiltersReset(),
                    ),
                    borderRadius: DdtTheme.radius,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
