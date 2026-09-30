import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/blocs/auth/auth_bloc.dart';
import 'package:ddt_frontend/blocs/tasks/tasks_bloc.dart';
import 'package:ddt_frontend/models/task.dart';
import 'package:ddt_frontend/models/task_ref.dart';
import 'package:ddt_frontend/models/task_status.dart';
import 'package:ddt_frontend/theme/ddt_scale.dart';
import 'package:ddt_frontend/theme/ddt_theme.dart';
import 'package:ddt_frontend/widgets/task_side_panel.dart';

Task _task(int id, String key) {
  return Task(
    id: id,
    key: key,
    title: 'Task $key',
    status: TaskStatus.todo,
    timeSet: DateTime(2026, 9, 1, 10),
  );
}

void main() {
  setUpAll(() {
    AppColors.initialize(
      primary: const Color(0xFF1976D2),
      accent: const Color(0xFF64B5F6),
    );
    AppTheme.initialize(
      primary: const Color(0xFF1976D2),
      accent: const Color(0xFF64B5F6),
    );
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1440, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('a picked deadline is kept on the saved task', (tester) async {
    final target = _task(1, 'a-1');
    Task? saved;

    await tester.pumpWidget(
      _Harness(
        onPressed: (context) async {
          saved = await showTaskSidePanel(
            context,
            mode: TaskSidePanelMode.view,
            task: target,
            taskTypes: const [],
            relatedTasks: [target],
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Начало / Окончание / Дедлайн are the three unset date controls.
    await tester.tap(find.text('Не указано').at(2));
    await tester.pumpAndSettle();
    expect(find.text('Выберите дату и время'), findsOneWidget);

    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();
    expect(find.text('Не указано'), findsNWidgets(2));

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved?.deadline, isNotNull);
  });

  testWidgets('picking a child task keeps the dropdown usable', (tester) async {
    final target = _task(1, 'a-1');
    Task? saved;

    await tester.pumpWidget(
      _Harness(
        onPressed: (context) async {
          saved = await showTaskSidePanel(
            context,
            mode: TaskSidePanelMode.view,
            task: target,
            taskTypes: const [],
            relatedTasks: [target, _task(2, 'a-2'), _task(3, 'a-3')],
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить задачу'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a-2 · Task a-2').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The picker resets so another child can be added right away.
    expect(find.text('Добавить задачу'), findsOneWidget);

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved?.children.map((child) => child.key).toList(), ['a-2']);
  });

  testWidgets('a parent outside the loaded tasks stays selected',
      (tester) async {
    final parent = TaskRef(
      id: 9,
      key: 'a-9',
      title: 'Parent',
      status: TaskStatus.todo,
    );
    final target = Task(
      id: 1,
      key: 'a-1',
      title: 'Task a-1',
      status: TaskStatus.todo,
      timeSet: DateTime(2026, 9, 1, 10),
      parent: parent,
      parentId: parent.id,
    );
    Task? saved;

    await tester.pumpWidget(
      _Harness(
        onPressed: (context) async {
          saved = await showTaskSidePanel(
            context,
            mode: TaskSidePanelMode.view,
            task: target,
            taskTypes: const [],
            relatedTasks: [target, _task(2, 'a-2')],
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('a-9 · Parent'), findsOneWidget);

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved?.parent?.key, 'a-9');
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.onPressed});

  final Future<void> Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
        BlocProvider(create: (_) => TasksBloc()),
      ],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1440, 2400)),
        child: DdtScaleScope(
          builder: (_, _) => MaterialApp(
            theme: DdtTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (inner) => Center(
                  child: TextButton(
                    onPressed: () => onPressed(inner),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
