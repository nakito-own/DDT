import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/blocs/tasks/tasks_bloc.dart';
import 'package:ddt_frontend/models/task.dart';
import 'package:ddt_frontend/models/task_link.dart';
import 'package:ddt_frontend/models/task_ref.dart';
import 'package:ddt_frontend/models/task_status.dart';
import 'package:ddt_frontend/models/task_type.dart';
import 'package:ddt_frontend/services/tasks_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProvider, (call) async => '.');

  test(
    'created task replaces optimistic draft instead of duplicating it',
    () async {
      final bloc = TasksBloc(api: _FakeTasksApi(createdId: 42));
      addTearDown(bloc.close);

      bloc.add(TaskCreateRequested(_draft('Новая задача')));

      final settled = await bloc.stream.firstWhere(
        (state) => state.allTasks.any((task) => task.id == 42),
      );

      expect(settled.allTasks, hasLength(1));
      expect(settled.allTasks.single.id, 42);
      expect(settled.allTasks.where((task) => task.id < 0), isEmpty);
    },
  );

  test('personal and space blocs keep independent task collections', () async {
    final personalBloc = TasksBloc(api: _FakeTasksApi(createdId: 10));
    final spaceBloc = TasksBloc(
      api: _FakeTasksApi(createdId: 20, spaceKey: 'TEST', taskSpaceId: 2),
    );
    addTearDown(personalBloc.close);
    addTearDown(spaceBloc.close);

    final personalResult = personalBloc.stream.firstWhere(
      (state) => state.allTasks.any((task) => task.id == 10),
    );
    final spaceResult = spaceBloc.stream.firstWhere(
      (state) => state.allTasks.any((task) => task.id == 20),
    );

    personalBloc.add(TaskCreateRequested(_draft('Личная')));
    spaceBloc.add(TaskCreateRequested(_draft('Общая', spaceId: 2)));

    final personalState = await personalResult;
    final spaceState = await spaceResult;

    expect(personalState.allTasks.map((task) => task.id), [10]);
    expect(personalState.allTasks.single.spaceId, isNull);
    expect(spaceState.allTasks.map((task) => task.id), [20]);
    expect(spaceState.allTasks.single.spaceId, 2);
  });

  test('person filters narrow tasks and reset clears them', () async {
    final api = _BoardApi([
      _stored(
        id: 1,
        key: 'T-1',
        title: 'С автором',
        authorId: 1,
        executorId: 2,
        responsibleId: 3,
      ),
      _stored(
        id: 2,
        key: 'T-2',
        title: 'Другой автор',
        authorId: 9,
        executorId: 2,
        responsibleId: 4,
      ),
      _stored(id: 3, key: 'T-3', title: 'Без людей'),
    ]);
    final bloc = TasksBloc(api: api);
    addTearDown(bloc.close);

    bloc.add(const TasksBoardLoadRequested());
    await bloc.stream.firstWhere((state) => state.allTasks.length == 3);

    bloc.add(const TasksAuthorFilterChanged(1));
    var state = await bloc.stream.firstWhere(
      (state) => state.authorFilter == 1,
    );
    expect(state.filteredTasks.map((task) => task.id), [1]);

    bloc.add(const TasksExecutorFilterChanged(2));
    state = await bloc.stream.firstWhere((state) => state.executorFilter == 2);
    expect(state.filteredTasks.map((task) => task.id), [1]);

    bloc.add(const TasksResponsibleFilterChanged(4));
    state = await bloc.stream.firstWhere(
      (state) => state.responsibleFilter == 4,
    );
    expect(state.filteredTasks, isEmpty);

    bloc.add(const TasksFiltersReset());
    state = await bloc.stream.firstWhere(
      (state) =>
          state.authorFilter == null &&
          state.executorFilter == null &&
          state.responsibleFilter == null,
    );
    expect(state.filteredTasks.map((task) => task.id), [1, 2, 3]);
  });

  test('date filters keep tasks inside each local-day range', () async {
    final october = DateTime.utc(2026, 10, 10, 12);
    final september = DateTime.utc(2026, 9, 1, 12);
    final api = _BoardApi([
      _stored(
        id: 1,
        key: 'T-1',
        title: 'В октябре',
        timeStart: october,
        timeEnd: october,
        deadline: october,
        updatedAt: october,
      ),
      _stored(
        id: 2,
        key: 'T-2',
        title: 'В сентябре',
        timeStart: september,
        deadline: september,
        updatedAt: september,
      ),
      _stored(id: 3, key: 'T-3', title: 'Без дат'),
    ]);
    final bloc = TasksBloc(api: api);
    addTearDown(bloc.close);

    bloc.add(const TasksBoardLoadRequested());
    await bloc.stream.firstWhere((state) => state.allTasks.length == 3);

    bloc.add(
      TasksDateFilterChanged(
        TaskDateField.started,
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 31),
      ),
    );
    var state = await bloc.stream.firstWhere(
      (state) => state.dateFilters.startedStart != null,
    );
    expect(state.filteredTasks.map((task) => task.id), [1]);

    bloc.add(
      TasksDateFilterChanged(
        TaskDateField.deadline,
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 30),
      ),
    );
    state = await bloc.stream.firstWhere(
      (state) => state.dateFilters.deadlineStart != null,
    );
    expect(state.filteredTasks, isEmpty);

    bloc.add(const TasksDateFilterChanged(TaskDateField.deadline, null, null));
    bloc.add(
      TasksDateFilterChanged(
        TaskDateField.updated,
        DateTime(2026, 10, 10),
        DateTime(2026, 10, 10),
      ),
    );
    state = await bloc.stream.firstWhere(
      (state) =>
          state.dateFilters.deadlineStart == null &&
          state.dateFilters.updatedStart != null,
    );
    expect(state.filteredTasks.map((task) => task.id), [1]);

    bloc.add(const TasksFiltersReset());
    state = await bloc.stream.firstWhere(
      (state) => !state.dateFilters.isActive,
    );
    expect(
      state.filteredTasks.map((task) => task.id),
      unorderedEquals([1, 2, 3]),
    );
  });

  test('parent assignment updates the other task immediately', () async {
    final parent = _stored(id: 1, key: 'T-1', title: 'Родитель');
    final child = _stored(id: 2, key: 'T-2', title: 'Потомок');
    final api = _BoardApi([parent, child]);
    final bloc = TasksBloc(api: api);
    addTearDown(bloc.close);

    bloc.add(const TasksBoardLoadRequested());
    await bloc.stream.firstWhere((state) => state.allTasks.length == 2);

    bloc.add(
      TaskUpdateRequested(
        original: child,
        updated: child.copyWith(
          parentId: parent.id,
          parent: TaskRef(
            id: parent.id,
            key: parent.key,
            title: parent.title,
            status: parent.status,
          ),
        ),
      ),
    );

    final settled = await bloc.stream.firstWhere((state) {
      final parentTask = state.allTasks.where((task) => task.id == parent.id);
      return parentTask.isNotEmpty && parentTask.single.children.isNotEmpty;
    });

    expect(settled.allTasks.singleWhere((task) => task.id == 2).parent?.id, 1);
    expect(
      settled.allTasks.singleWhere((task) => task.id == 1).children.single.id,
      2,
    );
  });

  test('returning a task to in progress refreshes its dates', () async {
    final task = _stored(
      id: 3,
      key: 'T-3',
      title: 'Срок',
      status: TaskStatus.done,
      timeStart: DateTime.utc(2026, 1, 1),
      timeEnd: DateTime.utc(2026, 1, 2),
    );
    final api = _BoardApi([task]);
    final bloc = TasksBloc(api: api);
    addTearDown(bloc.close);

    bloc.add(const TasksBoardLoadRequested());
    await bloc.stream.firstWhere((state) => state.allTasks.length == 1);

    bloc.add(
      TaskMoveRequested(
        task: task,
        from: TaskStatus.done,
        to: TaskStatus.inProgress,
      ),
    );

    final settled = await bloc.stream.firstWhere(
      (state) =>
          state.allTasks.single.status == TaskStatus.inProgress &&
          state.allTasks.single.timeEnd == null &&
          api.lastBody.isNotEmpty,
    );
    expect(settled.allTasks.single.timeStart, isNot(task.timeStart));
    expect(api.lastBody['time_end'], isNull);
    expect(api.lastBody['time_start'], isNotNull);
  });
}

Task _draft(String title, {int? spaceId}) {
  return Task(
    id: 0,
    title: title,
    status: TaskStatus.todo,
    timeSet: DateTime.utc(2026, 8, 18),
    spaceId: spaceId,
  );
}

Task _stored({
  required int id,
  required String key,
  required String title,
  TaskStatus status = TaskStatus.todo,
  DateTime? timeStart,
  DateTime? timeEnd,
  DateTime? deadline,
  DateTime? updatedAt,
  int? authorId,
  int? executorId,
  int? responsibleId,
}) {
  return Task(
    id: id,
    key: key,
    title: title,
    status: status,
    timeSet: DateTime.utc(2026, 8, 18),
    timeStart: timeStart,
    timeEnd: timeEnd,
    deadline: deadline,
    updatedAt: updatedAt,
    authorId: authorId,
    executorId: executorId,
    responsibleId: responsibleId,
  );
}

class _BoardApi extends TasksApi {
  _BoardApi(this.tasks);

  final List<Task> tasks;
  Map<String, dynamic> lastBody = const {};

  @override
  Future<List<TaskType>> fetchTaskTypes() async => const [];

  @override
  Future<List<Task>> fetchTasks() async => tasks;

  @override
  Future<Task> updateTask(String taskRef, Map<String, dynamic> body) async {
    lastBody = body;
    final task = tasks.firstWhere((item) => item.apiRef == taskRef);
    final parentKey = body['parent_key'] as String?;
    TaskRef? parent;
    if (parentKey != null && parentKey.isNotEmpty) {
      final found = tasks.firstWhere((item) => item.key == parentKey);
      parent = TaskRef(
        id: found.id,
        key: found.key,
        title: found.title,
        status: found.status,
      );
    }
    final status = body['status'] is String
        ? TaskStatus.fromValue(body['status'] as String)
        : task.status;
    return task.copyWith(
      status: status,
      parent: parent,
      parentId: parent?.id,
      clearParent: body.containsKey('parent_key') && parent == null,
      timeStart: body['time_start'] is String
          ? DateTime.parse(body['time_start'] as String)
          : null,
      clearTimeStart:
          body.containsKey('time_start') && body['time_start'] == null,
      timeEnd: body['time_end'] is String
          ? DateTime.parse(body['time_end'] as String)
          : null,
      clearTimeEnd: body.containsKey('time_end') && body['time_end'] == null,
    );
  }
}

class _FakeTasksApi extends TasksApi {
  _FakeTasksApi({required this.createdId, super.spaceKey, this.taskSpaceId});

  final int createdId;
  final int? taskSpaceId;

  @override
  Future<List<TaskType>> fetchTaskTypes() async => const [];

  @override
  Future<List<Task>> fetchTasks() async => const [];

  @override
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
    return Task(
      id: createdId,
      key: spaceKey == null ? 'user-$createdId' : '$spaceKey-$createdId',
      title: title,
      status: status,
      typeId: typeId,
      description: description,
      executorId: executorId,
      responsibleId: responsibleId,
      timeSet: timeSet ?? DateTime.now(),
      timeStart: timeStart,
      timeEnd: timeEnd,
      deadline: deadline,
      links: links,
      spaceId: taskSpaceId,
    );
  }
}
