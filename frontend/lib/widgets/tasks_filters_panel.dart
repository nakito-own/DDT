import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../blocs/tasks/tasks_bloc.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';
import '../theme/ddt_theme.dart';

class TasksFiltersPanel extends StatelessWidget {
  const TasksFiltersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimary = DdtTheme.taskCardTextPrimary(context);
    final textSecondary = DdtTheme.taskCardTextSecondary(context);

    return DdtTheme.glass(
      context: context,
      padding: EdgeInsets.all(16.w),
      child: BlocBuilder<TasksBloc, TasksState>(
        builder: (context, state) => ListView(
          children: [
            Text(
              'Фильтры',
              style: DdtTheme.style(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              onChanged: (value) => context
                  .read<TasksBloc>()
                  .add(TasksSearchQueryChanged(value)),
              decoration: InputDecoration(
                hintText: 'Поиск по названию',
                prefixIcon: Icon(
                  CupertinoIcons.search,
                  size: 18.sp,
                  color: textSecondary,
                ),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 10.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: DdtTheme.radius,
                  borderSide: BorderSide(
                    color: DdtTheme.glassBorderColor(
                      Theme.of(context).brightness,
                    ).withValues(
                      alpha: DdtTheme.glassBorderOpacity(
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ),
              ),
              style: DdtTheme.style(fontSize: 13.sp, color: textPrimary),
            ),
            SizedBox(height: 20.h),
            _FilterSection(
              title: 'Статус',
              child: Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  for (final status in TaskStatus.values)
                    FilterChip(
                      label: Text(status.label),
                      selected: state.statusFilters.contains(status),
                      onSelected: (_) => context
                          .read<TasksBloc>()
                          .add(TasksStatusFilterToggled(status)),
                      labelStyle: DdtTheme.style(fontSize: 12.sp),
                      visualDensity: VisualDensity.compact,
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
                  FilterChip(
                    label: const Text('Все'),
                    selected: state.priorityFilter == null,
                    onSelected: (_) => context
                        .read<TasksBloc>()
                        .add(const TasksPriorityFilterChanged(null)),
                    labelStyle: DdtTheme.style(fontSize: 12.sp),
                    visualDensity: VisualDensity.compact,
                  ),
                  for (final priority in TaskPriority.values)
                    FilterChip(
                      label: Text(priority.label),
                      selected: state.priorityFilter == priority,
                      onSelected: (_) => context
                          .read<TasksBloc>()
                          .add(TasksPriorityFilterChanged(priority)),
                      labelStyle: DdtTheme.style(fontSize: 12.sp),
                      visualDensity: VisualDensity.compact,
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
                    FilterChip(
                      label: const Text('Все'),
                      selected: state.typeFilter == null,
                      onSelected: (_) => context
                          .read<TasksBloc>()
                          .add(const TasksTypeFilterChanged(null)),
                      labelStyle: DdtTheme.style(fontSize: 12.sp),
                      visualDensity: VisualDensity.compact,
                    ),
                    for (final type in state.taskTypes)
                      FilterChip(
                        label: Text(type.name),
                        selected: state.typeFilter == type.id,
                        onSelected: (_) => context
                            .read<TasksBloc>()
                            .add(TasksTypeFilterChanged(type.id)),
                        labelStyle: DdtTheme.style(fontSize: 12.sp),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 16.h),
            _FilterSection(
              title: 'Сортировка',
              child: DropdownButtonFormField<TasksSortOption>(
                key: ValueKey(state.sortOption),
                initialValue: state.sortOption,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: DdtTheme.radius,
                  ),
                ),
                items: [
                  for (final option in TasksSortOption.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(
                        option.label,
                        style: DdtTheme.style(fontSize: 13.sp),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    context
                        .read<TasksBloc>()
                        .add(TasksSortOptionChanged(value));
                  }
                },
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Найдено: ${state.filteredTasks.length}',
              style: DdtTheme.style(
                fontSize: 12.sp,
                color: textSecondary,
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
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.child,
  });

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
            fontSize: 13.sp,
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
