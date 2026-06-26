import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ddt_frontend/theme/ddt_theme.dart';
import 'package:ddt_frontend/controllers/theme_controller.dart';
import 'package:ddt_frontend/screens/kanban_board_page.dart';

void main() {
  setUp(() {
    Get.reset();
    AppColors.initialize(
      primary: const Color(0xFF1976D2),
      accent: const Color(0xFF64B5F6),
    );
    AppTheme.initialize(
      primary: const Color(0xFF1976D2),
      accent: const Color(0xFF64B5F6),
    );
    Get.put(ThemeController());
  });

  testWidgets('Kanban board renders columns', (WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1440, 900),
        builder: (_, child) => GetMaterialApp(
          theme: DdtTheme.light(),
          builder: (context, child) {
            return DefaultTextStyle(
              style: DdtTheme.style(),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: child,
        ),
        child: const KanbanBoardPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Запланировано'), findsOneWidget);
    expect(find.text('В работе'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('Настроить проект'), findsOneWidget);
    expect(find.text('Блокер'), findsOneWidget);
  });

  testWidgets('Create task side panel opens without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1440, 900),
        builder: (_, child) => GetMaterialApp(
          theme: DdtTheme.light(),
          builder: (context, child) {
            return DefaultTextStyle(
              style: DdtTheme.style(),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: child,
        ),
        child: const KanbanBoardPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Добавить задачу').first);
    await tester.pumpAndSettle();

    expect(find.text('Новая задача'), findsOneWidget);
    expect(find.text('Создать'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
