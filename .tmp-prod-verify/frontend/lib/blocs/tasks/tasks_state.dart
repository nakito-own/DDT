part of 'tasks_bloc.dart';

final class TasksState extends Equatable {
  const TasksState({
    this.columns = const {},
    this.taskTypes = const [],
    this.isLoading = false,
    this.errorMessage,
    this.viewMode = TasksViewMode.list,
    this.searchQuery = '',
    this.statusFilters = const {},
    this.priorityFilter,
    this.typeFilter,
    this.authorFilter,
    this.executorFilter,
    this.responsibleFilter,
    this.dateFilters = const TaskDateRanges(),
    this.sortOption = TasksSortOption.deadlineAsc,
    this.showArchived = false,
  });

  final Map<TaskStatus, List<Task>> columns;
  final List<TaskType> taskTypes;
  final bool isLoading;
  final String? errorMessage;
  final TasksViewMode viewMode;
  final String searchQuery;
  final Set<TaskStatus> statusFilters;
  final TaskPriority? priorityFilter;
  final int? typeFilter;
  final int? authorFilter;
  final int? executorFilter;
  final int? responsibleFilter;
  final TaskDateRanges dateFilters;
  final TasksSortOption sortOption;
  final bool showArchived;

  List<Task> get allTasks => TaskStatus.values
      .expand((status) => columns[status] ?? const <Task>[])
      .toList();

  List<Task> get filteredTasks {
    final query = searchQuery.trim().toLowerCase();
    final filtered = allTasks.where((task) {
      if (statusFilters.isNotEmpty && !statusFilters.contains(task.status)) {
        return false;
      }
      if (priorityFilter != null && task.priority != priorityFilter) {
        return false;
      }
      if (typeFilter != null && task.typeId != typeFilter) {
        return false;
      }
      if (authorFilter != null && task.authorId != authorFilter) {
        return false;
      }
      if (executorFilter != null && task.executorId != executorFilter) {
        return false;
      }
      if (responsibleFilter != null &&
          task.responsibleId != responsibleFilter) {
        return false;
      }
      if (!dateFilters.matches(task)) return false;
      if (query.isNotEmpty && !task.title.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort(_compareTasks);
    return filtered;
  }

  int _compareTasks(Task a, Task b) {
    switch (sortOption) {
      case TasksSortOption.deadlineAsc:
        return _compareDateTime(a.deadline, b.deadline);
      case TasksSortOption.deadlineDesc:
        return _compareDateTime(b.deadline, a.deadline);
      case TasksSortOption.priorityDesc:
        return _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
      case TasksSortOption.titleAsc:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case TasksSortOption.status:
        return a.status.index.compareTo(b.status.index);
    }
  }

  int _priorityRank(TaskPriority? priority) {
    if (priority == null) return -1;
    return TaskPriority.values.indexOf(priority);
  }

  int _compareDateTime(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  TasksState copyWith({
    Map<TaskStatus, List<Task>>? columns,
    List<TaskType>? taskTypes,
    bool? isLoading,
    String? Function()? errorMessage,
    TasksViewMode? viewMode,
    String? searchQuery,
    Set<TaskStatus>? statusFilters,
    TaskPriority? Function()? priorityFilter,
    int? Function()? typeFilter,
    int? Function()? authorFilter,
    int? Function()? executorFilter,
    int? Function()? responsibleFilter,
    TaskDateRanges? dateFilters,
    TasksSortOption? sortOption,
    bool? showArchived,
  }) {
    return TasksState(
      columns: columns ?? this.columns,
      taskTypes: taskTypes ?? this.taskTypes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      viewMode: viewMode ?? this.viewMode,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilters: statusFilters ?? this.statusFilters,
      priorityFilter: priorityFilter != null
          ? priorityFilter()
          : this.priorityFilter,
      typeFilter: typeFilter != null ? typeFilter() : this.typeFilter,
      authorFilter: authorFilter != null ? authorFilter() : this.authorFilter,
      executorFilter: executorFilter != null
          ? executorFilter()
          : this.executorFilter,
      responsibleFilter: responsibleFilter != null
          ? responsibleFilter()
          : this.responsibleFilter,
      dateFilters: dateFilters ?? this.dateFilters,
      sortOption: sortOption ?? this.sortOption,
      showArchived: showArchived ?? this.showArchived,
    );
  }

  @override
  List<Object?> get props => [
    columns,
    taskTypes,
    isLoading,
    errorMessage,
    viewMode,
    searchQuery,
    statusFilters,
    priorityFilter,
    typeFilter,
    authorFilter,
    executorFilter,
    responsibleFilter,
    dateFilters,
    sortOption,
    showArchived,
  ];
}

enum TaskDateField {
  created('Дата создания'),
  started('Дата начала работы'),
  finished('Дата окончания работы'),
  deadline('Дата дедлайна'),
  updated('Дата последнего обновления');

  const TaskDateField(this.label);

  final String label;
}

/// Inclusive local-day ranges for the space task filters.
final class TaskDateRanges extends Equatable {
  const TaskDateRanges({
    this.createdStart,
    this.createdEnd,
    this.startedStart,
    this.startedEnd,
    this.finishedStart,
    this.finishedEnd,
    this.deadlineStart,
    this.deadlineEnd,
    this.updatedStart,
    this.updatedEnd,
  });

  final DateTime? createdStart;
  final DateTime? createdEnd;
  final DateTime? startedStart;
  final DateTime? startedEnd;
  final DateTime? finishedStart;
  final DateTime? finishedEnd;
  final DateTime? deadlineStart;
  final DateTime? deadlineEnd;
  final DateTime? updatedStart;
  final DateTime? updatedEnd;

  bool get isActive =>
      createdStart != null ||
      startedStart != null ||
      finishedStart != null ||
      deadlineStart != null ||
      updatedStart != null;

  (DateTime?, DateTime?) bounds(TaskDateField field) {
    return switch (field) {
      TaskDateField.created => (createdStart, createdEnd),
      TaskDateField.started => (startedStart, startedEnd),
      TaskDateField.finished => (finishedStart, finishedEnd),
      TaskDateField.deadline => (deadlineStart, deadlineEnd),
      TaskDateField.updated => (updatedStart, updatedEnd),
    };
  }

  TaskDateRanges withRange(
    TaskDateField field,
    DateTime? start,
    DateTime? end,
  ) {
    return switch (field) {
      TaskDateField.created => copyWith(
        createdStart: () => start,
        createdEnd: () => end,
      ),
      TaskDateField.started => copyWith(
        startedStart: () => start,
        startedEnd: () => end,
      ),
      TaskDateField.finished => copyWith(
        finishedStart: () => start,
        finishedEnd: () => end,
      ),
      TaskDateField.deadline => copyWith(
        deadlineStart: () => start,
        deadlineEnd: () => end,
      ),
      TaskDateField.updated => copyWith(
        updatedStart: () => start,
        updatedEnd: () => end,
      ),
    };
  }

  bool matches(Task task) {
    return _contains(task.timeSet, createdStart, createdEnd) &&
        _contains(task.timeStart, startedStart, startedEnd) &&
        _contains(task.timeEnd, finishedStart, finishedEnd) &&
        _contains(task.deadline, deadlineStart, deadlineEnd) &&
        _contains(task.updatedAt, updatedStart, updatedEnd);
  }

  TaskDateRanges copyWith({
    DateTime? Function()? createdStart,
    DateTime? Function()? createdEnd,
    DateTime? Function()? startedStart,
    DateTime? Function()? startedEnd,
    DateTime? Function()? finishedStart,
    DateTime? Function()? finishedEnd,
    DateTime? Function()? deadlineStart,
    DateTime? Function()? deadlineEnd,
    DateTime? Function()? updatedStart,
    DateTime? Function()? updatedEnd,
  }) {
    return TaskDateRanges(
      createdStart: createdStart != null ? createdStart() : this.createdStart,
      createdEnd: createdEnd != null ? createdEnd() : this.createdEnd,
      startedStart: startedStart != null ? startedStart() : this.startedStart,
      startedEnd: startedEnd != null ? startedEnd() : this.startedEnd,
      finishedStart: finishedStart != null
          ? finishedStart()
          : this.finishedStart,
      finishedEnd: finishedEnd != null ? finishedEnd() : this.finishedEnd,
      deadlineStart: deadlineStart != null
          ? deadlineStart()
          : this.deadlineStart,
      deadlineEnd: deadlineEnd != null ? deadlineEnd() : this.deadlineEnd,
      updatedStart: updatedStart != null ? updatedStart() : this.updatedStart,
      updatedEnd: updatedEnd != null ? updatedEnd() : this.updatedEnd,
    );
  }

  static bool _contains(DateTime? value, DateTime? start, DateTime? end) {
    if (start == null && end == null) return true;
    if (value == null) return false;
    final day = _day(value.toLocal());
    final from = start == null ? null : _day(start);
    final to = end == null ? from : _day(end);
    if (from != null && day.isBefore(from)) return false;
    if (to != null && day.isAfter(to)) return false;
    return true;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  List<Object?> get props => [
    createdStart,
    createdEnd,
    startedStart,
    startedEnd,
    finishedStart,
    finishedEnd,
    deadlineStart,
    deadlineEnd,
    updatedStart,
    updatedEnd,
  ];
}
