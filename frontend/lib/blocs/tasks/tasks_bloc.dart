import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/task.dart';
import '../../models/task_priority.dart';
import '../../models/task_ref.dart';
import '../../models/task_status.dart';
import '../../models/task_type.dart';
import '../../models/tasks_view_mode.dart';
import '../../services/tasks_api.dart';
import '../../utils/task_status_dates.dart';

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
  TasksBloc({TasksApi? api, this.archivedOnly = false, bool beginLoading = false})
    : _api = api ?? tasksApi,
      super(
        TasksState(
          columns: {for (final s in TaskStatus.values) s: <Task>[]},
          statusFilters: Set.of(TaskStatus.values),
          isLoading: beginLoading,
        ),
      ) {
    on<TasksBoardLoadRequested>(_onBoardLoadRequested);
    on<TasksBoardCleared>(_onBoardCleared);
    on<TasksViewModeChanged>(_onViewModeChanged);
    on<TasksSearchQueryChanged>(_onSearchQueryChanged);
    on<TasksStatusFilterToggled>(_onStatusFilterToggled);
    on<TasksPriorityFilterChanged>(_onPriorityFilterChanged);
    on<TasksTypeFilterChanged>(_onTypeFilterChanged);
    on<TasksSortOptionChanged>(_onSortOptionChanged);
    on<TasksFiltersReset>(_onFiltersReset);
    on<TasksShowArchivedChanged>(_onShowArchivedChanged);
    on<TaskCreateRequested>(_onTaskCreateRequested);
    on<TaskUpdateRequested>(_onTaskUpdateRequested);
    on<TaskServerSnapshotReceived>(_onTaskServerSnapshotReceived);
    on<TaskMoveRequested>(_onTaskMoveRequested);
    on<TaskArchiveRequested>(_onTaskArchiveRequested);
  }

  TasksApi _api;
  final bool archivedOnly;
  int _nextDraftId = -1;
  int _archivedRequest = 0;
  int _boardRequest = 0;
  String? get spaceKey => _api.spaceKey;

  /// Сменить пространство, не пересоздавая блок и экран.
  void switchSpace(String spaceKey) {
    if (_api.spaceKey == spaceKey) return;
    _api = TasksApi(spaceKey: spaceKey);
    add(const TasksBoardLoadRequested(reset: true));
  }

  // ─── Board load / clear ───────────────────────────────────────────────────

  Future<void> _onBoardLoadRequested(
    TasksBoardLoadRequested event,
    Emitter<TasksState> emit,
  ) async {
    final request = ++_boardRequest;
    final requestedSpace = _api.spaceKey;
    emit(
      state.copyWith(
        isLoading: true,
        errorMessage: () => null,
        columns: event.reset
            ? {for (final status in TaskStatus.values) status: <Task>[]}
            : null,
        taskTypes: event.reset ? const [] : null,
      ),
    );

    try {
      final types = await _api.fetchTaskTypes();
      if (request != _boardRequest || requestedSpace != _api.spaceKey) return;
      final includeArchived = archivedOnly || state.showArchived;
      final tasks = archivedOnly
          ? await _api.fetchArchivedTasks()
          : await _api.fetchTasks();
      if (request != _boardRequest || requestedSpace != _api.spaceKey) return;
      final archived = !archivedOnly && includeArchived
          ? await _api.fetchArchivedTasks()
          : const <Task>[];
      if (request != _boardRequest || requestedSpace != _api.spaceKey) return;

      final columns = _groupTasks(
        [...tasks, ...archived],
        includeArchived: includeArchived,
      );
      emit(
        state.copyWith(
          isLoading: false,
          taskTypes: types,
          columns: columns,
          errorMessage: () => null,
        ),
      );
    } catch (error) {
      if (request != _boardRequest || requestedSpace != _api.spaceKey) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _onBoardCleared(TasksBoardCleared event, Emitter<TasksState> emit) {
    emit(
      state.copyWith(
        columns: {for (final s in TaskStatus.values) s: <Task>[]},
        taskTypes: [],
        errorMessage: () => null,
      ),
    );
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
    _archivedRequest++;
    emit(
      state.copyWith(
        searchQuery: '',
        statusFilters: Set.of(TaskStatus.values),
        priorityFilter: () => null,
        typeFilter: () => null,
        sortOption: TasksSortOption.deadlineAsc,
        showArchived: false,
        columns: state.showArchived
            ? _withoutArchived(state.columns)
            : state.columns,
      ),
    );
  }

  Future<void> _onShowArchivedChanged(
    TasksShowArchivedChanged event,
    Emitter<TasksState> emit,
  ) async {
    if (archivedOnly) return;

    if (!event.enabled) {
      _archivedRequest++;
      emit(
        state.copyWith(
          showArchived: false,
          columns: _withoutArchived(state.columns),
        ),
      );
      return;
    }

    final request = ++_archivedRequest;
    emit(state.copyWith(showArchived: true, errorMessage: () => null));
    try {
      final archived = await _api.fetchArchivedTasks();
      if (request != _archivedRequest || !state.showArchived) return;
      emit(state.copyWith(columns: _mergeTasks(state.columns, archived)));
    } catch (error) {
      if (request != _archivedRequest) return;
      emit(
        state.copyWith(
          showArchived: false,
          columns: _withoutArchived(state.columns),
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> _onTaskCreateRequested(
    TaskCreateRequested event,
    Emitter<TasksState> emit,
  ) async {
    final draft = event.draft.copyWith(id: _nextDraftId--);
    final optimisticColumns = _copyColumns(state.columns);
    optimisticColumns[draft.status] = [
      ...(optimisticColumns[draft.status] ?? []),
      draft,
    ];
    emit(state.copyWith(columns: optimisticColumns, errorMessage: () => null));

    try {
      final created = await _api.createTask(
        title: draft.title,
        status: draft.status,
        typeId: draft.typeId,
        description: draft.description,
        executorId: draft.executorId,
        responsibleId: draft.responsibleId,
        timeSet: draft.timeSet,
        timeStart: draft.timeStart,
        timeEnd: draft.timeEnd,
        deadline: draft.deadline,
        priority: draft.priority?.value,
        links: draft.links,
        initialComment: draft.comments.isEmpty
            ? null
            : draft.comments.first.text,
        parentKey: draft.parent?.key,
        childKeys: draft.children.map((child) => child.key).toList(),
      );
      final columns = _syncTaskRelations(
        _replaceTaskInColumns(state.columns, original: draft, saved: created),
        created,
      );
      emit(state.copyWith(columns: columns));
    } catch (error) {
      final columns = _copyColumns(state.columns);
      columns[draft.status]?.removeWhere((task) => task.id == draft.id);
      emit(
        state.copyWith(
          columns: columns,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onTaskUpdateRequested(
    TaskUpdateRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      final saved = await _api.updateTask(
        event.original.apiRef,
        _buildUpdatePayload(event.original, event.updated),
      );
      final columns = _syncTaskRelations(
        _replaceTaskInColumns(
          state.columns,
          original: event.original,
          saved: saved,
        ),
        saved,
      );
      emit(state.copyWith(columns: columns));
    } catch (error) {
      emit(
        state.copyWith(
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _onTaskServerSnapshotReceived(
    TaskServerSnapshotReceived event,
    Emitter<TasksState> emit,
  ) {
    final tasks = state.allTasks;
    final index = tasks.indexWhere((task) => task.id == event.task.id);
    if (index < 0) return;
    final existing = tasks[index];

    emit(
      state.copyWith(
        columns: _syncTaskRelations(
          _replaceTaskInColumns(
            state.columns,
            original: existing,
            saved: event.task,
          ),
          event.task,
        ),
      ),
    );
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
      toIndex: event.toIndex,
    );
    emit(state.copyWith(columns: optimisticColumns));

    if (event.from == event.to) {
      return;
    }

    try {
      final saved = await _api.updateTask(event.task.apiRef, {
        'status': event.to.value,
        ..._statusDatePayload(event.task, updatedLocal),
      });
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
        toIndex: event.from == event.to ? event.toIndex : null,
      );
      emit(
        state.copyWith(
          columns: reverted,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onTaskArchiveRequested(
    TaskArchiveRequested event,
    Emitter<TasksState> emit,
  ) async {
    final column = state.columns[event.status];
    if (column == null) return;

    final index = column.indexWhere((item) => item.id == event.task.id);
    if (index < 0) return;

    final keepVisible = archivedOnly || state.showArchived;
    final optimisticColumns = _copyColumns(state.columns);
    final optimisticColumn = [...column];
    if (keepVisible) {
      optimisticColumn[index] = event.task.copyWith(archive: true);
    } else {
      optimisticColumn.removeAt(index);
    }
    optimisticColumns[event.status] = optimisticColumn;
    emit(state.copyWith(columns: optimisticColumns));

    try {
      final saved = await _api.archiveTask(event.task.apiRef);
      if (!keepVisible) return;
      emit(
        state.copyWith(
          columns: _replaceTaskInColumns(
            state.columns,
            original: event.task,
            saved: saved,
          ),
        ),
      );
    } catch (error) {
      final reverted = _copyColumns(state.columns);
      final column = [...(reverted[event.status] ?? <Task>[])];
      final currentIndex = column.indexWhere((item) => item.id == event.task.id);
      if (keepVisible && currentIndex >= 0) {
        column[currentIndex] = event.task;
      } else if (currentIndex < 0) {
        column.insert(index.clamp(0, column.length), event.task);
      }
      reverted[event.status] = column;
      emit(
        state.copyWith(
          columns: reverted,
          errorMessage: () => error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Map<TaskStatus, List<Task>> _groupTasks(
    Iterable<Task> tasks, {
    required bool includeArchived,
  }) {
    final columns = {for (final status in TaskStatus.values) status: <Task>[]};
    final seen = <int>{};
    for (final task in tasks) {
      if (task.deleted || !seen.add(task.id)) continue;
      if (task.archive && !includeArchived) continue;
      columns[task.status]?.add(task);
    }
    return columns;
  }

  Map<TaskStatus, List<Task>> _withoutArchived(
    Map<TaskStatus, List<Task>> source,
  ) {
    return {
      for (final entry in source.entries)
        entry.key: [
          for (final task in entry.value)
            if (!task.archive) task,
        ],
    };
  }

  Map<TaskStatus, List<Task>> _mergeTasks(
    Map<TaskStatus, List<Task>> source,
    List<Task> extra,
  ) {
    final columns = _copyColumns(source);
    final seen = {
      for (final task in columns.values.expand((column) => column)) task.id,
    };
    for (final task in extra) {
      if (task.deleted || !seen.add(task.id)) continue;
      columns[task.status]?.add(task);
    }
    return columns;
  }

  Map<TaskStatus, List<Task>> _copyColumns(Map<TaskStatus, List<Task>> source) {
    return {for (final e in source.entries) e.key: List.of(e.value)};
  }

  Map<TaskStatus, List<Task>> _applyMoveToColumns(
    Map<TaskStatus, List<Task>> source, {
    required Task task,
    required TaskStatus from,
    required TaskStatus to,
    required Task updated,
    int? toIndex,
  }) {
    final columns = _copyColumns(source);
    columns[from]?.removeWhere((item) => item.id == task.id);
    if (from != to) {
      columns[to]?.removeWhere((item) => item.id == task.id);
    }
    final dest = columns[to] ?? <Task>[];
    final index = (toIndex ?? dest.length).clamp(0, dest.length);
    dest.insert(index, updated);
    columns[to] = dest;
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

    if (oldStatus == newStatus) {
      final column = columns[newStatus];
      if (column == null) return columns;
      final index = column.indexWhere((item) => item.id == original.id);
      if (index >= 0) {
        column[index] = saved;
      } else {
        final savedIndex = column.indexWhere((item) => item.id == saved.id);
        if (savedIndex >= 0) {
          column[savedIndex] = saved;
                    } else if (original.id < 0) {
                      column.add(saved);
                    }
      }
    } else {
      final existed =
          columns[oldStatus]?.any((item) => item.id == original.id) ?? false;
      columns[oldStatus]?.removeWhere((item) => item.id == original.id);
      if (existed || original.id < 0) {
        columns[newStatus] = [...(columns[newStatus] ?? []), saved];
      }
    }
    return columns;
  }

  Task _updatedTaskForColumn(Task task, TaskStatus to) {
    return applyTaskStatusDates(task, to);
  }

  Map<String, dynamic> _statusDatePayload(Task original, Task updated) {
    final payload = <String, dynamic>{};
    final nextStart = updated.timeStart?.toUtc().toIso8601String();
    final prevStart = original.timeStart?.toUtc().toIso8601String();
    if (nextStart != prevStart) payload['time_start'] = nextStart;
    final nextEnd = updated.timeEnd?.toUtc().toIso8601String();
    final prevEnd = original.timeEnd?.toUtc().toIso8601String();
    if (nextEnd != prevEnd) payload['time_end'] = nextEnd;
    return payload;
  }

  Map<TaskStatus, List<Task>> _syncTaskRelations(
    Map<TaskStatus, List<Task>> source,
    Task focal,
  ) {
    return {
      for (final entry in source.entries)
        entry.key: [
          for (final task in entry.value) _alignTaskRelation(task, focal),
        ],
    };
  }

  Task _alignTaskRelation(Task task, Task focal) {
    if (task.id == focal.id) return focal;

    final focalRef = TaskRef(
      id: focal.id,
      key: focal.key,
      title: focal.title,
      status: focal.status,
    );
    final childIds = focal.children.map((child) => child.id).toSet();
    var next = task;

    if (childIds.contains(task.id)) {
      next = next.copyWith(parentId: focal.id, parent: focalRef);
    } else if (task.parent?.id == focal.id) {
      next = next.copyWith(clearParent: true);
    }

    final listsFocal = next.children.any((child) => child.id == focal.id);
    final shouldListFocal = focal.parent?.id == task.id;
    if (shouldListFocal && !listsFocal) {
      next = next.copyWith(children: [...next.children, focalRef]);
    } else if (!shouldListFocal && listsFocal) {
      next = next.copyWith(
        children: [
          for (final child in next.children)
            if (child.id != focal.id) child,
        ],
      );
    }

    if (childIds.isEmpty || next.id == focal.id) return next;
    final cleaned = [
      for (final child in next.children)
        if (!childIds.contains(child.id)) child,
    ];
    if (cleaned.length == next.children.length) return next;
    return next.copyWith(children: cleaned);
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
      'responsible_id',
      updated.responsibleId,
      original.responsibleId,
    );
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
    putIfChanged('priority', updated.priority?.value, original.priority?.value);
    putIfChanged(
      'parent_key',
      updated.parent?.key ?? '',
      original.parent?.key ?? '',
    );

    final originalChildKeys = original.children.map((child) => child.key).toList()
      ..sort();
    final updatedChildKeys = updated.children.map((child) => child.key).toList()
      ..sort();
    if (originalChildKeys.join(',') != updatedChildKeys.join(',')) {
      payload['child_keys'] = updated.children.map((child) => child.key).toList();
    }

    if (updated.links != null) {
      payload['links'] = updated.links!
          .map(
            (link) => {
              'url': link.url,
              if (link.title != null) 'title': link.title,
            },
          )
          .toList();
    }

    return payload;
  }
}
