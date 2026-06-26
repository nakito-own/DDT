import 'package:get/get.dart';

import '../models/task.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import '../services/tasks_api.dart';

class TasksController extends GetxController {
  TasksController({TasksApi? api}) : _api = api ?? tasksApi;

  final TasksApi _api;

  final RxMap<TaskStatus, List<Task>> columns = RxMap<TaskStatus, List<Task>>({
    for (final status in TaskStatus.values) status: <Task>[],
  });
  final RxList<TaskType> taskTypes = <TaskType>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  List<Task> get allTasks => TaskStatus.values
      .expand((status) => columns[status] ?? const <Task>[])
      .toList();

  void clearBoard() {
    for (final status in TaskStatus.values) {
      columns[status] = [];
    }
    taskTypes.clear();
    columns.refresh();
  }

  Future<void> loadBoard() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final typesFuture = _api.fetchTaskTypes();
      final tasksFuture = _api.fetchTasks();
      final types = await typesFuture;
      final tasks = await tasksFuture;

      taskTypes.assignAll(types);
      _setColumnsFromTasks(tasks);
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  void _setColumnsFromTasks(List<Task> tasks) {
    for (final status in TaskStatus.values) {
      columns[status] = tasks.where((task) => task.status == status).toList();
    }
    columns.refresh();
  }

  Future<Task?> createTask(Task draft) async {
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
      );
      columns[created.status] = [...(columns[created.status] ?? []), created];
      columns.refresh();
      return created;
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  Future<Task?> updateTask(Task original, Task updated) async {
    try {
      final saved = await _api.updateTask(
        original.id,
        _buildUpdatePayload(original, updated),
      );
      _replaceTaskLocally(original, saved);
      return saved;
    } catch (error) {
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  Future<Task?> persistTaskMove(Task task, TaskStatus from, TaskStatus to) async {
    final updatedLocal = _updatedTaskForColumn(task, to);

    try {
      final saved = await _api.updateTask(
        task.id,
        {
          'status': to.value,
          if (updatedLocal.timeStart != null)
            'time_start': updatedLocal.timeStart!.toUtc().toIso8601String(),
          if (updatedLocal.timeEnd != null)
            'time_end': updatedLocal.timeEnd!.toUtc().toIso8601String(),
        },
      );
      _replaceTaskLocally(task, saved);
      return saved;
    } catch (error) {
      _applyMoveLocally(updatedLocal, to, from, task);
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  Future<Task?> persistMove(
    Task task,
    TaskStatus from,
    TaskStatus to,
    Task updatedLocal,
  ) async {
    try {
      final saved = await _api.updateTask(
        task.id,
        {
          'status': to.value,
          if (updatedLocal.timeStart != null)
            'time_start': updatedLocal.timeStart!.toUtc().toIso8601String(),
          if (updatedLocal.timeEnd != null)
            'time_end': updatedLocal.timeEnd!.toUtc().toIso8601String(),
        },
      );
      _replaceTaskLocally(updatedLocal, saved);
      return saved;
    } catch (error) {
      _applyMoveLocally(updatedLocal, to, from, task);
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  Future<Task?> moveTask(Task task, TaskStatus from, TaskStatus to) async {
    final updatedLocal = _updatedTaskForColumn(task, to);
    _applyMoveLocally(task, from, to, updatedLocal);

    try {
      final saved = await _api.updateTask(
        task.id,
        {
          'status': to.value,
          if (updatedLocal.timeStart != null)
            'time_start': updatedLocal.timeStart!.toUtc().toIso8601String(),
          if (updatedLocal.timeEnd != null)
            'time_end': updatedLocal.timeEnd!.toUtc().toIso8601String(),
        },
      );
      _replaceTaskLocally(updatedLocal, saved);
      return saved;
    } catch (error) {
      _applyMoveLocally(updatedLocal, to, from, task);
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  Future<bool> deleteTask(Task task, TaskStatus status) async {
    final column = columns[status];
    if (column == null) return false;

    final index = column.indexWhere((item) => item.id == task.id);
    if (index < 0) return false;

    final backup = column[index];
    column.removeAt(index);
    columns.refresh();

    try {
      await _api.deleteTask(task.id);
      return true;
    } catch (error) {
      column.insert(index, backup);
      columns.refresh();
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  Map<String, dynamic> _buildUpdatePayload(Task original, Task updated) {
    final payload = <String, dynamic>{};

    void putIfChanged(String key, Object? value, Object? previous) {
      if (value != previous) {
        payload[key] = value;
      }
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
    putIfChanged(
      'priority',
      updated.priority?.value,
      original.priority?.value,
    );

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

  void _applyMoveLocally(
    Task task,
    TaskStatus from,
    TaskStatus to,
    Task updated,
  ) {
    columns[from]?.removeWhere((item) => item.id == task.id);
    columns[to] = [...(columns[to] ?? []), updated];
    columns.refresh();
  }

  void _replaceTaskLocally(Task original, Task saved) {
    final oldStatus = original.status;
    final newStatus = saved.status;

    columns[oldStatus]?.removeWhere((item) => item.id == original.id);

    if (oldStatus == newStatus) {
      final column = columns[newStatus];
      if (column == null) return;
      final index = column.indexWhere((item) => item.id == saved.id);
      if (index >= 0) {
        column[index] = saved;
      } else {
        column.add(saved);
      }
    } else {
      columns[newStatus] = [...(columns[newStatus] ?? []), saved];
    }

    columns.refresh();
  }
}
