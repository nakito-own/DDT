part of 'tasks_bloc.dart';

sealed class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить доску при открытии раздела задач.
final class TasksBoardLoadRequested extends TasksEvent {
  const TasksBoardLoadRequested();
}

/// Очистить доску при логауте / истечении сессии.
final class TasksBoardCleared extends TasksEvent {
  const TasksBoardCleared();
}

/// Переключить режим отображения (kanban / list / gantt).
final class TasksViewModeChanged extends TasksEvent {
  const TasksViewModeChanged(this.mode);

  final TasksViewMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Изменить строку поиска.
final class TasksSearchQueryChanged extends TasksEvent {
  const TasksSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Включить/выключить фильтр по статусу.
final class TasksStatusFilterToggled extends TasksEvent {
  const TasksStatusFilterToggled(this.status);

  final TaskStatus status;

  @override
  List<Object?> get props => [status];
}

/// Установить фильтр по приоритету (null = сбросить).
final class TasksPriorityFilterChanged extends TasksEvent {
  const TasksPriorityFilterChanged(this.priority);

  final TaskPriority? priority;

  @override
  List<Object?> get props => [priority];
}

/// Установить фильтр по типу задачи (null = сбросить).
final class TasksTypeFilterChanged extends TasksEvent {
  const TasksTypeFilterChanged(this.typeId);

  final int? typeId;

  @override
  List<Object?> get props => [typeId];
}

/// Изменить вариант сортировки.
final class TasksSortOptionChanged extends TasksEvent {
  const TasksSortOptionChanged(this.option);

  final TasksSortOption option;

  @override
  List<Object?> get props => [option];
}

/// Сбросить все фильтры и сортировку.
final class TasksFiltersReset extends TasksEvent {
  const TasksFiltersReset();
}

/// Создать новую задачу.
final class TaskCreateRequested extends TasksEvent {
  const TaskCreateRequested(this.draft);

  final Task draft;

  @override
  List<Object?> get props => [draft];
}

/// Обновить существующую задачу.
final class TaskUpdateRequested extends TasksEvent {
  const TaskUpdateRequested({required this.original, required this.updated});

  final Task original;
  final Task updated;

  @override
  List<Object?> get props => [original, updated];
}

/// Синхронизировать задачу с уже сохранённым серверным состоянием.
final class TaskServerSnapshotReceived extends TasksEvent {
  const TaskServerSnapshotReceived(this.task);

  final Task task;

  @override
  List<Object?> get props => [task];
}

/// Переместить задачу между колонками (optimistic move).
final class TaskMoveRequested extends TasksEvent {
  const TaskMoveRequested({
    required this.task,
    required this.from,
    required this.to,
  });

  final Task task;
  final TaskStatus from;
  final TaskStatus to;

  @override
  List<Object?> get props => [task, from, to];
}

/// Удалить задачу.
final class TaskDeleteRequested extends TasksEvent {
  const TaskDeleteRequested({required this.task, required this.status});

  final Task task;
  final TaskStatus status;

  @override
  List<Object?> get props => [task, status];
}
