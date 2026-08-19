import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/blocs/tasks/tasks_bloc.dart';
import 'package:ddt_frontend/models/task.dart';
import 'package:ddt_frontend/models/task_link.dart';
import 'package:ddt_frontend/models/task_status.dart';
import 'package:ddt_frontend/models/task_type.dart';
import 'package:ddt_frontend/services/tasks_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    final spaceBloc = TasksBloc(api: _FakeTasksApi(createdId: 20, spaceId: 2));
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

class _FakeTasksApi extends TasksApi {
  _FakeTasksApi({required this.createdId, super.spaceId});

  final int createdId;

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
  }) async {
    return Task(
      id: createdId,
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
      spaceId: spaceId,
    );
  }
}
