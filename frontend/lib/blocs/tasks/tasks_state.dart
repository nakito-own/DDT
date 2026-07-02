part of 'tasks_bloc.dart';

final class TasksState extends Equatable {
  const TasksState({
    this.columns = const {},
    this.taskTypes = const [],
    this.isLoading = false,
    this.errorMessage,
    this.viewMode = TasksViewMode.kanban,
    this.searchQuery = '',
    this.statusFilters = const {},
    this.priorityFilter,
    this.typeFilter,
    this.sortOption = TasksSortOption.deadlineAsc,
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
  final TasksSortOption sortOption;

  List<Task> get allTasks => TaskStatus.values
      .expand((status) => columns[status] ?? const <Task>[])
      .toList();

  List<Task> get filteredTasks {
    final query = searchQuery.trim().toLowerCase();
    final filtered = allTasks.where((task) {
      if (statusFilters.isNotEmpty &&
          !statusFilters.contains(task.status)) {
        return false;
      }
      if (priorityFilter != null && task.priority != priorityFilter) {
        return false;
      }
      if (typeFilter != null && task.typeId != typeFilter) {
        return false;
      }
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
    TasksSortOption? sortOption,
  }) {
    return TasksState(
      columns: columns ?? this.columns,
      taskTypes: taskTypes ?? this.taskTypes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      viewMode: viewMode ?? this.viewMode,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilters: statusFilters ?? this.statusFilters,
      priorityFilter:
          priorityFilter != null ? priorityFilter() : this.priorityFilter,
      typeFilter: typeFilter != null ? typeFilter() : this.typeFilter,
      sortOption: sortOption ?? this.sortOption,
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
        sortOption,
      ];
}
