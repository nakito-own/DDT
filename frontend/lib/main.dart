import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/ews_auth_controller.dart';
import 'controllers/tasks_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/session_token_storage.dart';
import 'screens/main_shell_page.dart';
import 'theme/ddt_theme.dart';
import 'widgets/ews_auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BoltKit.initialize(
    primaryColor: const Color(0xFF1976D2),
    accentColor: const Color(0xFF64B5F6),
  );

  await ThemeController.prepareStorage();
  await SessionTokenStorage.prepare();
  Get.put(ThemeController());
  Get.put(EwsAuthController());
  Get.put(TasksController());

  runApp(const DdtApp());
}

class DdtApp extends StatelessWidget {
  const DdtApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return BoltKit.builder(
      designSize: const Size(1440, 900),
      builder: () => Obx(
        () => GetMaterialApp(
          title: 'DDT Kanban',
          theme: DdtTheme.light(),
          darkTheme: DdtTheme.dark(),
          themeMode: themeController.themeMode,
          builder: (context, child) {
            return DefaultTextStyle(
              style: DdtTheme.style(color: DdtTheme.textPrimary(context)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const EwsAuthGate(child: MainShellPage()),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
