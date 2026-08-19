import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/blocs/tasks/tasks_bloc.dart';
import 'package:ddt_frontend/models/task.dart';
import 'package:ddt_frontend/models/task_status.dart';
import 'package:ddt_frontend/models/task_type.dart';
import 'package:ddt_frontend/screens/kanban_board_page.dart';
import 'package:ddt_frontend/services/tasks_api.dart';
import 'package:ddt_frontend/theme/ddt_theme.dart';

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

  Widget buildTestApp() {
    return BlocProvider(
      create: (_) =>
          TasksBloc(api: _WidgetTestTasksApi())
            ..add(const TasksBoardLoadRequested()),
      child: ScreenUtilInit(
        designSize: const Size(1440, 900),
        builder: (_, child) =>
            MaterialApp(theme: DdtTheme.light(), home: child),
        child: const Scaffold(body: KanbanBoardPage()),
      ),
    );
  }

  testWidgets('Kanban board renders columns', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Запланировано'), findsOneWidget);
    expect(find.text('В работе'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('Тестовая задача'), findsOneWidget);
  });
}

class _WidgetTestTasksApi extends TasksApi {
  @override
  Future<List<TaskType>> fetchTaskTypes() async => const [];

  @override
  Future<List<Task>> fetchTasks() async => [
    Task(
      id: 1,
      title: 'Тестовая задача',
      status: TaskStatus.todo,
      timeSet: DateTime.utc(2026, 8, 18),
    ),
  ];
}
