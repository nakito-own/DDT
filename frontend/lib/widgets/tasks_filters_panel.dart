import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/ddt_icons.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';
import '../models/user_profile.dart';
import '../services/directory_users.dart';
import '../theme/ddt_theme.dart';
import '../utils/task_formatters.dart';
import 'analytics_period_calendar.dart';
import 'ddt_app_input.dart';
import '../theme/ddt_typography.dart';
import 'ddt_filter_dropdown.dart';
import 'ddt_panel_primary_button.dart';
import 'ddt_section_sidebar.dart';
import 'ddt_switch.dart';
import 'ddt_user_chip.dart';

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
        state.authorFilter != null ||
        state.executorFilter != null ||
        state.responsibleFilter != null ||
        state.dateFilters.isActive ||
        state.sortOption != TasksSortOption.deadlineAsc ||
        state.showArchived;
  }

  @override
  Widget build(BuildContext context) {
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
          previous.authorFilter != current.authorFilter ||
          previous.executorFilter != current.executorFilter ||
          previous.responsibleFilter != current.responsibleFilter ||
          previous.dateFilters != current.dateFilters ||
          previous.sortOption != current.sortOption ||
          previous.showArchived != current.showArchived ||
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

        final inSpace = context.read<TasksBloc>().spaceKey?.isNotEmpty ?? false;

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
                  borderRadius: DdtTheme.inputControlBorderRadius,
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
              if (inSpace) ...[
                _PersonFilterField(
                  label: 'Автор',
                  emptyLabel: 'Все авторы',
                  userId: state.authorFilter,
                  onChanged: (userId) => context.read<TasksBloc>().add(
                    TasksAuthorFilterChanged(userId),
                  ),
                ),
                _PersonFilterField(
                  label: 'Исполнитель',
                  emptyLabel: 'Все исполнители',
                  userId: state.executorFilter,
                  onChanged: (userId) => context.read<TasksBloc>().add(
                    TasksExecutorFilterChanged(userId),
                  ),
                ),
                _PersonFilterField(
                  label: 'Ответственный',
                  emptyLabel: 'Все ответственные',
                  userId: state.responsibleFilter,
                  onChanged: (userId) => context.read<TasksBloc>().add(
                    TasksResponsibleFilterChanged(userId),
                  ),
                ),
                for (final field in TaskDateField.values)
                  _DateFilterField(
                    field: field,
                    start: state.dateFilters.bounds(field).$1,
                    end: state.dateFilters.bounds(field).$2,
                  ),
              ],
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
              if (!context.read<TasksBloc>().archivedOnly) ...[
                SizedBox(height: DdtSectionSidebar.fieldGap),
                _ShowArchivedSwitch(enabled: state.showArchived),
              ],
              SizedBox(height: DdtSectionSidebar.blockGap),
              Divider(height: 1, thickness: 1, color: dividerColor),
              SizedBox(height: DdtSectionSidebar.afterDividerGap),
              DdtSectionSidebarField(
                gapAbove: false,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 9.h,
                  ),
                  decoration: BoxDecoration(
                    color: DdtTheme.inputFillColor(context),
                    borderRadius: DdtTheme.inputControlBorderRadius,
                    border: Border.all(color: DdtTheme.borderSubtle(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Найдено задач',
                        style: DdtTheme.style(
                          fontSize: DdtTypography.labelSmallSize,
                          fontWeight: FontWeight.w500,
                          color: DdtTheme.textMuted(context),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: DdtTheme.primaryColor.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.20
                                : 0.10,
                          ),
                          borderRadius: DdtTheme.badgeBorderRadius,
                        ),
                        child: Text(
                          '${state.filteredTasks.length}',
                          style: DdtTheme.style(
                            fontSize: DdtTypography.captionSize,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? DdtTheme.accentColor
                                : DdtTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
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
                    borderRadius: DdtTheme.inputControlBorderRadius,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PersonFilterField extends StatelessWidget {
  const _PersonFilterField({
    required this.label,
    required this.emptyLabel,
    required this.userId,
    required this.onChanged,
  });

  final String label;
  final String emptyLabel;
  final int? userId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: loadDirectoryUsers(),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <UserProfile>[];
        final selected = directoryUserById(users, userId);
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            users.isEmpty;
        final summary = userId == null
            ? emptyLabel
            : (selected?.label ?? (loading ? 'Загрузка…' : 'Пользователь'));

        return DdtSectionSidebarField(
          label: label,
          child: DdtSearchableFilterDropdown(
            summary: summary,
            active: userId != null,
            options: [
              DdtFilterOption(key: '', label: emptyLabel),
              for (final user in users)
                DdtFilterOption(
                  key: '${user.id}',
                  label: user.label,
                  searchText: '${user.label} ${user.email}',
                  content: (context) =>
                      DdtUserChip(name: user.label, userId: user.id),
                ),
            ],
            selected: {if (userId != null) '$userId' else ''},
            multi: false,
            emptyLabel: loading ? 'Загрузка…' : 'Нет пользователей',
            onSelected: (key) =>
                onChanged(key.isEmpty ? null : int.tryParse(key)),
          ),
        );
      },
    );
  }
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    required this.field,
    required this.start,
    required this.end,
  });

  final TaskDateField field;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    return DdtSectionSidebarField(
      label: field.label,
      child: Builder(
        builder: (anchorContext) {
          return DdtFilterDropdownAnchor(
            label: _dateFilterLabel(start, end),
            active: start != null,
            icon: DdtIcons.calendar,
            onTap: () {
              final today = DateTime.now();
              showAnalyticsPeriodCalendar(
                context: context,
                anchorContext: anchorContext,
                start: start,
                end: end,
                firstDate: DateTime(today.year - 5),
                lastDate: DateTime(today.year, today.month, today.day),
                onApply: (nextStart, nextEnd) {
                  context.read<TasksBloc>().add(
                    TasksDateFilterChanged(field, nextStart, nextEnd),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

String _dateFilterLabel(DateTime? start, DateTime? end) {
  if (start == null) return 'Все даты';
  final from = formatTaskDate(start);
  if (end == null ||
      (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day)) {
    return from;
  }
  return '$from — ${formatTaskDate(end)}';
}

class _ShowArchivedSwitch extends StatelessWidget {
  const _ShowArchivedSwitch({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: DdtTheme.inputFillColor(context),
        borderRadius: DdtTheme.inputControlBorderRadius,
        border: Border.all(color: DdtTheme.borderSubtle(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Показывать архивные',
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSize,
                fontWeight: FontWeight.w500,
                color: DdtTheme.taskCardTextPrimary(context),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          DdtSwitch(
            value: enabled,
            onChanged: (value) =>
                context.read<TasksBloc>().add(TasksShowArchivedChanged(value)),
          ),
        ],
      ),
    );
  }
}
