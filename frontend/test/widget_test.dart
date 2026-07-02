import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ddt_frontend/blocs/theme/theme_bloc.dart';
import 'package:ddt_frontend/theme/ddt_theme.dart';
import 'package:ddt_frontend/screens/kanban_board_page.dart';

void main() {
  setUp(() async {
    Get.reset();
    await GetStorage.init('test_storage');
    AppColors.initialize(
      primary: const Color(0xFF1976D2),
      accent: const Color(0xFF64B5F6),
    );
    AppTheme.initialize(
      primary: const Color(0xFF1976D2),
      accent: const Color(0xFF64B5F6),
    );
  });

  Widget _buildTestApp(Widget child) {
    return BlocProvider(
      create: (_) => ThemeBloc(storage: GetStorage('test_storage')),
      child: ScreenUtilInit(
        designSize: const Size(1440, 900),
        builder: (_, wrappedChild) => GetMaterialApp(
          theme: DdtTheme.light(),
          builder: (context, appChild) {
            return DefaultTextStyle(
              style: DdtTheme.style(),
              child: appChild ?? const SizedBox.shrink(),
            );
          },
          home: wrappedChild,
        ),
        child: child,
      ),
    );
  }

  testWidgets('Kanban board renders columns', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const KanbanBoardPage()));
    await tester.pumpAndSettle();

    expect(find.text('Запланировано'), findsOneWidget);
    expect(find.text('В работе'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('Настроить проект'), findsOneWidget);
    expect(find.text('Блокер'), findsOneWidget);
  });

  testWidgets('Create task side panel opens without errors', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const KanbanBoardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Добавить задачу').first);
    await tester.pumpAndSettle();

    expect(find.text('Новая задача'), findsOneWidget);
    expect(find.text('Создать'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
