part of 'tasks_bloc.dart';

final class TaskFieldFilter extends Equatable {
  const TaskFieldFilter({
    this.text = '',
    this.options = const {},
    this.userId,
    this.checked,
  });

  final String text;
  final Set<String> options;
  final int? userId;
  final bool? checked;

  bool get isActive =>
      text.trim().isNotEmpty ||
      options.isNotEmpty ||
      userId != null ||
      checked != null;

  TaskFieldFilter copyWith({
    String? text,
    Set<String>? options,
    int? Function()? userId,
    bool? Function()? checked,
  }) {
    return TaskFieldFilter(
      text: text ?? this.text,
      options: options ?? this.options,
      userId: userId != null ? userId() : this.userId,
      checked: checked != null ? checked() : this.checked,
    );
  }

  @override
  List<Object?> get props => [text, options, userId, checked];
}

final class TasksState extends Equatable {
  const TasksState({
    this.columns = const {},
    this.statuses = TaskStatus.values,
    this.taskTypes = const [],
    this.queueFields = const [],
    this.queueComponents = const [],
    this.isLoading = false,
    this.errorMessage,
    this.viewMode = TasksViewMode.list,
    this.spaceViewMode = TasksViewMode.list,
    this.activeSpaceKey,
    this.searchQuery = '',
    this.statusFilters = const {},
    this.priorityFilter,
    this.typeFilter,
    this.componentFilters = const {},
    this.fieldFilters = const {},
    this.authorFilter,
    this.executorFilter,
    this.responsibleFilter,
    this.dateFilters = const TaskDateRanges(),
    this.sortOption = TasksSortOption.deadlineAsc,
    this.showArchived = false,
  });

  final Map<TaskStatus, List<Task>> columns;
  final List<TaskStatus> statuses;
  final List<TaskType> taskTypes;
  final List<QueueField> queueFields;
  final List<QueueComponent> queueComponents;
  final bool isLoading;
  final String? errorMessage;
  final TasksViewMode viewMode;

  /// Вид доски пространства. Живёт в корневом блоке: блок пространства
  /// пересоздаётся, когда пользователь уходит в другой раздел.
  final TasksViewMode spaceViewMode;

  /// Последнее открытое пространство. Вместе с [spaceViewMode] возвращает
  /// пользователя на ту же доску.
  final String? activeSpaceKey;

  final String searchQuery;
  final Set<TaskStatus> statusFilters;
  final TaskPriority? priorityFilter;
  final int? typeFilter;
  final Set<int> componentFilters;
  final Map<int, TaskFieldFilter> fieldFilters;
  final int? authorFilter;
  final int? executorFilter;
  final int? responsibleFilter;
  final TaskDateRanges dateFilters;
  final TasksSortOption sortOption;
  final bool showArchived;

  List<TaskStatus> get boardStatuses =>
      statuses.isEmpty ? TaskStatus.values : statuses;

  List<Task> get allTasks => [
    for (final status in boardStatuses) ...columns[status] ?? const <Task>[],
  ];

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
      if (componentFilters.isNotEmpty) {
        final ids = task.components.map((item) => item.id).toSet();
        if (!componentFilters.any(ids.contains)) return false;
      }
      for (final field in queueFields) {
        final id = field.id;
        if (id == null) continue;
        final filter = fieldFilters[id];
        if (filter == null || !filter.isActive) continue;
        if (!_fieldMatches(task, field, filter)) return false;
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
        return _statusRank(a.status).compareTo(_statusRank(b.status));
    }
  }

  bool _fieldMatches(Task task, QueueField field, TaskFieldFilter filter) {
    TaskFieldValue? stored;
    for (final item in task.fieldValues) {
      if (item.fieldId == field.id) {
        stored = item;
        break;
      }
    }
    switch (field.fieldType) {
      case 'checkbox':
        final enabled = stored?.value == true;
        return filter.checked == null || enabled == filter.checked;
      case 'user':
        if (filter.userId == null) return true;
        return '${stored?.value}' == '${filter.userId}';
      case 'list':
        if (filter.options.isEmpty) return true;
        final selected = stored?.value is List
            ? (stored!.value as List).map((item) => item.toString()).toSet()
            : <String>{
                if (stored?.value != null) stored!.value.toString(),
              };
        return filter.options.any(selected.contains);
      default:
        final needle = filter.text.trim().toLowerCase();
        if (needle.isEmpty) return true;
        return (stored?.displayValue.toLowerCase() ?? '').contains(needle);
    }
  }

  int _statusRank(TaskStatus status) {
    final index = boardStatuses.indexWhere((item) => item == status);
    return index < 0 ? boardStatuses.length : index;
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
    List<TaskStatus>? statuses,
    List<TaskType>? taskTypes,
    List<QueueField>? queueFields,
    List<QueueComponent>? queueComponents,
    bool? isLoading,
    String? Function()? errorMessage,
    TasksViewMode? viewMode,
    TasksViewMode? spaceViewMode,
    String? Function()? activeSpaceKey,
    String? searchQuery,
    Set<TaskStatus>? statusFilters,
    TaskPriority? Function()? priorityFilter,
    int? Function()? typeFilter,
    Set<int>? componentFilters,
    Map<int, TaskFieldFilter>? fieldFilters,
    int? Function()? authorFilter,
    int? Function()? executorFilter,
    int? Function()? responsibleFilter,
    TaskDateRanges? dateFilters,
    TasksSortOption? sortOption,
    bool? showArchived,
  }) {
    return TasksState(
      columns: columns ?? this.columns,
      statuses: statuses ?? this.statuses,
      taskTypes: taskTypes ?? this.taskTypes,
      queueFields: queueFields ?? this.queueFields,
      queueComponents: queueComponents ?? this.queueComponents,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      viewMode: viewMode ?? this.viewMode,
      spaceViewMode: spaceViewMode ?? this.spaceViewMode,
      activeSpaceKey: activeSpaceKey != null
          ? activeSpaceKey()
          : this.activeSpaceKey,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilters: statusFilters ?? this.statusFilters,
      priorityFilter: priorityFilter != null
          ? priorityFilter()
          : this.priorityFilter,
      typeFilter: typeFilter != null ? typeFilter() : this.typeFilter,
      componentFilters: componentFilters ?? this.componentFilters,
      fieldFilters: fieldFilters ?? this.fieldFilters,
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
    statuses,
    taskTypes,
    queueFields,
    queueComponents,
    isLoading,
    errorMessage,
    viewMode,
    spaceViewMode,
    activeSpaceKey,
    searchQuery,
    statusFilters,
    priorityFilter,
    typeFilter,
    componentFilters,
    fieldFilters,
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
