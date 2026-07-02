import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/task.dart';
import '../../models/task_priority.dart';
import '../../models/task_status.dart';
import '../../models/task_type.dart';
import '../../models/tasks_view_mode.dart';
import '../../services/tasks_api.dart';

part 'tasks_event.dart';
part 'tasks_state.dart';

enum TasksSortOption {
  deadlineAsc('Дедлайн ↑'),
  deadlineDesc('Дедлайн ↓'),
  priorityDesc('Приоритет ↓'),
  titleAsc('Название А–Я'),
  status('Статус');

  const TasksSortOption(this.label);

  final String label;
}

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc({TasksApi? api})
      : _api = api ?? tasksApi,
        super(TasksState(
          columns: {for (final s in TaskStatus.values) s: <Task>[]},
          statusFilters: Set.of(TaskStatus.values),
        )) {
    on<TasksBoardLoadRequested>(_onBoardLoadRequested);
    on<TasksBoardCleared>(_onBoardCleared);
    on<TasksViewModeChanged>(_onViewModeChanged);
    on<TasksSearchQueryChanged>(_onSearchQueryChanged);
    on<TasksStatusFilterToggled>(_onStatusFilterToggled);
    on<TasksPriorityFilterChanged>(_onPriorityFilterChanged);
    on<TasksTypeFilterChanged>(_onTypeFilterChanged);
    on<TasksSortOptionChanged>(_onSortOptionChanged);
    on<TasksFiltersReset>(_onFiltersReset);
    on<TaskCreateRequested>(_onTaskCreateRequested);
    on<TaskUpdateRequested>(_onTaskUpdateRequested);
    on<TaskMoveRequested>(_onTaskMoveRequested);
    on<TaskDeleteRequested>(_onTaskDeleteRequested);
  }

  final TasksApi _api;

  // ─── Board load / clear ───────────────────────────────────────────────────

  Future<void> _onBoardLoadRequested(
    TasksBoardLoadRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: () => null));

    try {
      final types = await _api.fetchTaskTypes();
      final tasks = await _api.fetchTasks();

      final columns = {for (final s in TaskStatus.values) s: <Task>[]};
      for (final task in tasks) {
        columns[task.status]?.add(task);
      }
      emit(state.copyWith(
        isLoading: false,
        taskTypes: types,
        columns: columns,
        errorMessage: () => null,
      ));
    } catch (error) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void _onBoardCleared(TasksBoardCleared event, Emitter<TasksState> emit) {
    emit(state.copyWith(
      columns: {for (final s in TaskStatus.values) s: <Task>[]},
      taskTypes: [],
      errorMessage: () => null,
    ));
  }

  // ─── View & filters ───────────────────────────────────────────────────────

  void _onViewModeChanged(
    TasksViewModeChanged event,
    Emitter<TasksState> emit,
  ) {
    emit(state.copyWith(viewMode: event.mode));
  }

  void _onSearchQueryChanged(
    TasksSearchQueryChanged event,
    Emitter<TasksState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onStatusFilterToggled(
    TasksStatusFilterToggled event,
    Emitter<TasksState> emit,
  ) {
    final current = Set<TaskStatus>.from(state.statusFilters);
    if (current.contains(event.status)) {
      if (current.length == 1) return;
      current.remove(event.status);
    } else {
      current.add(event.status);
    }
    emit(state.copyWith(statusFilters: current));
  }

  void _onPriorityFilterChanged(
    TasksPriorityFilterChanged event,
    Emitter<TasksState> emit,
  ) {
    emit(state.copyWith(priorityFilter: () => event.priority));
  }

  void _onTypeFilterChanged(
    TasksTypeFilterChanged event,
    Emitter<TasksState> emit,
  ) {
    emit(state.copyWith(typeFilter: () => event.typeId));
  }

  void _onSortOptionChanged(
    TasksSortOptionChanged event,
    Emitter<TasksState> emit,
  ) {
    emit(state.copyWith(sortOption: event.option));
  }

  void _onFiltersReset(TasksFiltersReset event, Emitter<TasksState> emit) {
    emit(state.copyWith(
      searchQuery: '',
      statusFilters: Set.of(TaskStatus.values),
      priorityFilter: () => null,
      typeFilter: () => null,
      sortOption: TasksSortOption.deadlineAsc,
    ));
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> _onTaskCreateRequested(
    TaskCreateRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final created = await _api.createTask(
        title: event.draft.title,
        status: event.draft.status,
        typeId: event.draft.typeId,
        description: event.draft.description,
        executorId: event.draft.executorId,
        responsibleId: event.draft.responsibleId,
        timeSet: event.draft.timeSet,
        timeStart: event.draft.timeStart,
        timeEnd: event.draft.timeEnd,
        deadline: event.draft.deadline,
        priority: event.draft.priority?.value,
        links: event.draft.links,
      );
      final columns = _copyColumns(state.columns);
      columns[created.status] = [...(columns[created.status] ?? []), created];
      emit(state.copyWith(columns: columns));
    } catch (error) {
      emit(state.copyWith(
        errorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onTaskUpdateRequested(
    TaskUpdateRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final saved = await _api.updateTask(
        event.original.id,
        _buildUpdatePayload(event.original, event.updated),
      );
      final columns = _replaceTaskInColumns(
        state.columns,
        original: event.original,
        saved: saved,
      );
      emit(state.copyWith(columns: columns));
    } catch (error) {
      emit(state.copyWith(
        errorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onTaskMoveRequested(
    TaskMoveRequested event,
    Emitter<TasksState> emit,
  ) async {
    final updatedLocal = _updatedTaskForColumn(event.task, event.to);
    // Optimistic local update
    final optimisticColumns = _applyMoveToColumns(
      state.columns,
      task: event.task,
      from: event.from,
      to: event.to,
      updated: updatedLocal,
    );
    emit(state.copyWith(columns: optimisticColumns));

    try {
      final saved = await _api.updateTask(
        event.task.id,
        {
          'status': event.to.value,
          if (updatedLocal.timeStart != null)
            'time_start':
                updatedLocal.timeStart!.toUtc().toIso8601String(),
          if (updatedLocal.timeEnd != null)
            'time_end': updatedLocal.timeEnd!.toUtc().toIso8601String(),
        },
      );
      final columns = _replaceTaskInColumns(
        state.columns,
        original: updatedLocal,
        saved: saved,
      );
      emit(state.copyWith(columns: columns));
    } catch (error) {
      // Revert on failure
      final reverted = _applyMoveToColumns(
        state.columns,
        task: updatedLocal,
        from: event.to,
        to: event.from,
        updated: event.task,
      );
      emit(state.copyWith(
        columns: reverted,
        errorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onTaskDeleteRequested(
    TaskDeleteRequested event,
    Emitter<TasksState> emit,
  ) async {
    final column = state.columns[event.status];
    if (column == null) return;

    final index = column.indexWhere((item) => item.id == event.task.id);
    if (index < 0) return;

    // Optimistic local delete
    final optimisticColumns = _copyColumns(state.columns);
    optimisticColumns[event.status] = [...column]..removeAt(index);
    emit(state.copyWith(columns: optimisticColumns));

    try {
      await _api.deleteTask(event.task.id);
    } catch (error) {
      // Revert on failure
      final reverted = _copyColumns(state.columns);
      reverted[event.status] = [...(reverted[event.status] ?? [])]
        ..insert(index, event.task);
      emit(state.copyWith(
        columns: reverted,
        errorMessage: () =>
            error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Map<TaskStatus, List<Task>> _copyColumns(
    Map<TaskStatus, List<Task>> source,
  ) {
    return {for (final e in source.entries) e.key: List.of(e.value)};
  }

  Map<TaskStatus, List<Task>> _applyMoveToColumns(
    Map<TaskStatus, List<Task>> source, {
    required Task task,
    required TaskStatus from,
    required TaskStatus to,
    required Task updated,
  }) {
    final columns = _copyColumns(source);
    columns[from]?.removeWhere((item) => item.id == task.id);
    columns[to] = [...(columns[to] ?? []), updated];
    return columns;
  }

  Map<TaskStatus, List<Task>> _replaceTaskInColumns(
    Map<TaskStatus, List<Task>> source, {
    required Task original,
    required Task saved,
  }) {
    final columns = _copyColumns(source);
    final oldStatus = original.status;
    final newStatus = saved.status;

    columns[oldStatus]?.removeWhere((item) => item.id == original.id);

    if (oldStatus == newStatus) {
      final column = columns[newStatus];
      if (column == null) return columns;
      final index = column.indexWhere((item) => item.id == saved.id);
      if (index >= 0) {
        column[index] = saved;
      } else {
        column.add(saved);
      }
    } else {
      columns[newStatus] = [...(columns[newStatus] ?? []), saved];
    }
    return columns;
  }

  Task _updatedTaskForColumn(Task task, TaskStatus to) {
    var updated = task.copyWith(status: to);
    if (to == TaskStatus.inProgress && updated.timeStart == null) {
      updated = updated.copyWith(timeStart: DateTime.now());
    }
    if (to == TaskStatus.done && updated.timeEnd == null) {
      updated = updated.copyWith(timeEnd: DateTime.now());
    }
    return updated;
  }

  Map<String, dynamic> _buildUpdatePayload(Task original, Task updated) {
    final payload = <String, dynamic>{};

    void putIfChanged(String key, Object? value, Object? previous) {
      if (value != previous) payload[key] = value;
    }

    putIfChanged('title', updated.title, original.title);
    putIfChanged('status', updated.status.value, original.status.value);
    putIfChanged('type_id', updated.typeId, original.typeId);
    putIfChanged('description', updated.description, original.description);
    putIfChanged('executor_id', updated.executorId, original.executorId);
    putIfChanged(
        'responsible_id', updated.responsibleId, original.responsibleId);
    putIfChanged(
      'time_set',
      updated.timeSet.toUtc().toIso8601String(),
      original.timeSet.toUtc().toIso8601String(),
    );
    putIfChanged(
      'time_start',
      updated.timeStart?.toUtc().toIso8601String(),
      original.timeStart?.toUtc().toIso8601String(),
    );
    putIfChanged(
      'time_end',
      updated.timeEnd?.toUtc().toIso8601String(),
      original.timeEnd?.toUtc().toIso8601String(),
    );
    putIfChanged(
      'deadline',
      updated.deadline?.toUtc().toIso8601String(),
      original.deadline?.toUtc().toIso8601String(),
    );
    putIfChanged(
        'priority', updated.priority?.value, original.priority?.value);

    if (updated.links != null) {
      payload['links'] = updated.links!
          .map((link) => {
                'url': link.url,
                if (link.title != null) 'title': link.title,
              })
          .toList();
    }

    return payload;
  }
}
