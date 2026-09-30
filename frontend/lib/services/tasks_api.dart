import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../models/task_comment.dart';
import '../models/task_link.dart';
import '../models/task_status.dart';
import '../models/task_type.dart';
import 'api_client.dart';

class TasksApi {
  TasksApi({ApiClient? client, this.spaceKey}) : _client = client ?? apiClient;

  final ApiClient _client;
  final String? spaceKey;

  String get _tasksPath =>
      spaceKey == null ? '/api/tasks' : '/api/spaces/$spaceKey/tasks';

  String _itemPath(String taskRef) => '/api/tasks/$taskRef';

  Future<List<TaskType>> fetchTaskTypes() async {
    final response = await _client.get('/api/task-types');
    _ensureSuccess(response);
    return ApiClient.decodeList(response).map(TaskType.fromJson).toList();
  }

  Future<List<Task>> fetchTasks() async {
    final response = await _client.get(_tasksPath);
    _ensureSuccess(response);
    return ApiClient.decodeList(response).map(Task.fromJson).toList();
  }

  Future<Task> fetchTask(String taskRef) async {
    final response = await _client.get(_itemPath(taskRef));
    _ensureSuccess(response);
    return Task.fromJson(ApiClient.decodeMap(response));
  }

  Future<Task> createTask({
    required String title,
    required TaskStatus status,
    int? typeId,
    String description = '',
    int? executorId,
    int? responsibleId,
    DateTime? timeSet,
    DateTime? timeStart,
    DateTime? timeEnd,
    DateTime? deadline,
    String? priority,
    List<TaskLink>? links,
    String? initialComment,
    String? parentKey,
    List<String>? childKeys,
  }) async {
    final response = await _client.post(
      _tasksPath,
      body: {
        'title': title,
        'status': status.value,
        if (typeId != null) 'type_id': typeId,
        'description': description,
        if (executorId != null) 'executor_id': executorId,
        if (responsibleId != null) 'responsible_id': responsibleId,
        if (timeSet != null) 'time_set': timeSet.toUtc().toIso8601String(),
        if (timeStart != null)
          'time_start': timeStart.toUtc().toIso8601String(),
        if (timeEnd != null) 'time_end': timeEnd.toUtc().toIso8601String(),
        if (deadline != null) 'deadline': deadline.toUtc().toIso8601String(),
        if (priority != null) 'priority': priority,
        if (links != null && links.isNotEmpty)
          'links': links
              .map(
                (link) => {
                  'url': link.url,
                  if (link.title != null) 'title': link.title,
                },
              )
              .toList(),
        if (initialComment != null && initialComment.trim().isNotEmpty)
          'initial_comment': initialComment.trim(),
        if (parentKey != null && parentKey.isNotEmpty) 'parent_key': parentKey,
        if (childKeys != null && childKeys.isNotEmpty) 'child_keys': childKeys,
      },
    );
    _ensureSuccess(response, expectedStatus: 201);
    return Task.fromJson(ApiClient.decodeMap(response));
  }

  Future<Task> updateTask(String taskRef, Map<String, dynamic> body) async {
    final response = await _client.put(_itemPath(taskRef), body: body);
    _ensureSuccess(response);
    return Task.fromJson(ApiClient.decodeMap(response));
  }

  Future<Task> updateTaskStatus(String taskRef, TaskStatus status) async {
    final response = await _client.patch(
      '${_itemPath(taskRef)}/status',
      body: {'status': status.value},
    );
    _ensureSuccess(response);
    return Task.fromJson(ApiClient.decodeMap(response));
  }

  Future<TaskComment> addComment(String taskRef, String text) async {
    final response = await _client.post(
      '${_itemPath(taskRef)}/comments',
      body: {'text': text},
    );
    _ensureSuccess(response, expectedStatus: 201);
    return TaskComment.fromJson(ApiClient.decodeMap(response));
  }

  Future<void> deleteTask(String taskRef) async {
    final response = await _client.delete(_itemPath(taskRef));
    _ensureSuccess(response, expectedStatus: 204);
  }

  void _ensureSuccess(http.Response response, {int expectedStatus = 200}) {
    if (response.statusCode == expectedStatus ||
        (expectedStatus == 200 &&
            response.statusCode >= 200 &&
            response.statusCode < 300)) {
      return;
    }
    throw Exception(_readError(response) ?? 'Ошибка запроса к API задач');
  }

  String? _readError(http.Response response) {
    try {
      final data = ApiClient.decodeMap(response);
      return data['detail']?.toString();
    } catch (_) {
      return null;
    }
  }
}

final tasksApi = TasksApi();
