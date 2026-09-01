import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';
import '../theme/ddt_theme.dart';
import 'ddt_app_input.dart';
import '../utils/task_formatters.dart';
import '../theme/ddt_typography.dart';

class TasksFiltersPanel extends StatefulWidget {
  const TasksFiltersPanel({super.key});

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

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final textSecondary = DdtTheme.taskCardTextSecondary(context);
    final dividerColor = DdtTheme.sidePanelDivider(context);

    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(16.w),
      child: BlocConsumer<TasksBloc, TasksState>(
        listenWhen: (previous, current) =>
            previous.searchQuery != current.searchQuery,
        listener: (context, state) => _syncSearchFromBloc(state.searchQuery),
        buildWhen: (previous, current) =>
            previous.searchQuery != current.searchQuery ||
            previous.statusFilters != current.statusFilters ||
            previous.priorityFilter != current.priorityFilter ||
            previous.typeFilter != current.typeFilter ||
            previous.sortOption != current.sortOption,
        builder: (context, state) {
          return ListView(
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
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
              SizedBox(height: 16.h),
              DdtAppInput(
                label: 'Поиск',
                hint: 'Поиск по названию',
                controller: _searchController,
                type: InputType.search,
                prefixIcon: Icons.search,
              ),
              SizedBox(height: 20.h),
              Divider(height: 1, thickness: 1, color: dividerColor),
              SizedBox(height: 16.h),
              _FilterSection(
                title: 'Статус',
                child: Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    for (final status in TaskStatus.values)
                      _FilterChip(
                        label: status.label,
                        selected: state.statusFilters.contains(status),
                        accentColor: statusColumnColor(status),
                        onTap: () => context.read<TasksBloc>().add(
                          TasksStatusFilterToggled(status),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _FilterSection(
                title: 'Приоритет',
                child: Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    _FilterChip(
                      label: 'Все',
                      selected: state.priorityFilter == null,
                      onTap: () => context.read<TasksBloc>().add(
                        const TasksPriorityFilterChanged(null),
                      ),
                    ),
                    for (final priority in TaskPriority.values)
                      _FilterChip(
                        label: priority.label,
                        selected: state.priorityFilter == priority,
                        accentColor: priorityColor(priority),
                        onTap: () => context.read<TasksBloc>().add(
                          TasksPriorityFilterChanged(priority),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.taskTypes.isNotEmpty) ...[
                SizedBox(height: 16.h),
                _FilterSection(
                  title: 'Тип',
                  child: Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      _FilterChip(
                        label: 'Все',
                        selected: state.typeFilter == null,
                        onTap: () => context.read<TasksBloc>().add(
                          const TasksTypeFilterChanged(null),
                        ),
                      ),
                      for (final type in state.taskTypes)
                        _FilterChip(
                          label: type.name,
                          selected: state.typeFilter == type.id,
                          onTap: () => context.read<TasksBloc>().add(
                            TasksTypeFilterChanged(type.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 16.h),
              _FilterSection(
                title: 'Сортировка',
                child: Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    for (final option in TasksSortOption.values)
                      _FilterChip(
                        label: option.label,
                        selected: state.sortOption == option,
                        onTap: () => context.read<TasksBloc>().add(
                          TasksSortOptionChanged(option),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Divider(height: 1, thickness: 1, color: dividerColor),
              SizedBox(height: 16.h),
              Container(
                width: double.infinity,
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
              SizedBox(height: 12.h),
              Button(
                text: 'Сбросить фильтры',
                type: ButtonType.outlined,
                onPressed: () =>
                    context.read<TasksBloc>().add(const TasksFiltersReset()),
                borderRadius: DdtTheme.radius,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: DdtTheme.style(
            fontSize: DdtTypography.labelSize,
            fontWeight: FontWeight.w600,
            color: DdtTheme.taskCardTextPrimary(context),
          ),
        ),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? AppColors.primary;
    final borderBase = DdtTheme.glassBorderColor(Theme.of(context).brightness);
    final borderAlpha = DdtTheme.glassBorderOpacity(
      Theme.of(context).brightness,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DdtTheme.selectionAnimationDuration,
        curve: DdtTheme.selectionAnimationCurve,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.primary.withValues(alpha: 0.04)),
          borderRadius: DdtTheme.radius,
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.45 : 0.32)
                : borderBase.withValues(alpha: borderAlpha * 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: DdtTheme.selectionAnimationDuration,
              curve: DdtTheme.selectionAnimationCurve,
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              child: selected
                  ? Row(
                      key: const ValueKey('check-visible'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedCheckmark(
                          color: accent.withValues(alpha: 0.95),
                        ),
                        SizedBox(width: 4.w),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('check-hidden')),
            ),
            Text(
              label,
              style: DdtTheme.style(
                fontSize: DdtTypography.labelSmallSize,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? accent.withValues(alpha: 0.95)
                    : DdtTheme.taskCardTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCheckmark extends StatelessWidget {
  const _AnimatedCheckmark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: DdtTheme.selectionAnimationDuration,
      curve: DdtTheme.selectionAnimationCurve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Icon(CupertinoIcons.checkmark, size: 12.sp, color: color),
    );
  }
}
