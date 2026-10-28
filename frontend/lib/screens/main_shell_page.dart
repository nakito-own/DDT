import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/mail/mail_bloc.dart';
import '../models/app_section.dart';
import '../models/tasks_view_mode.dart';
import '../utils/ddt_toast.dart';
import '../widgets/ddt_shell_layout.dart';

/// Оболочка основного приложения: навигационный рейл + аппбар + контент.
///
/// Является shell-виджетом для внешнего [ShellRoute] в GoRouter.
/// Активная секция определяется из URL через [selectedSection],
/// который вычисляется в [app_router.dart] по [GoRouterState.matchedLocation].
///
/// Переходы между секциями выполняются через [context.go],
/// что обновляет URL и историю браузера.
class MainShellPage extends StatelessWidget {
  const MainShellPage({
    super.key,
    required this.selectedSection,
    required this.child,
  });

  final AppSection selectedSection;
  final Widget child;

  /// Kanban drops the shell top inset and inserts its own spacer.
  /// A task opened from that board has no board segment in the URL, so the
  /// shell keeps the kanban slot — flipping the inset would jump the page.
  /// Other sections must not inherit it: their own top padding would collapse,
  /// and anything still measured from the bar reserve would stack on the spacer.
  static bool padsContentFor(AppSection section, String location) {
    final tasksShell =
        section == AppSection.tasks || section == AppSection.space;
    if (!tasksShell) return true;
    return TasksViewMode.fromRoute(location) != TasksViewMode.kanban;
  }

  @override
  Widget build(BuildContext context) {
    // uri.path is the open page. matchedLocation can stay on the shell prefix.
    final location = GoRouterState.of(context).uri.path;

    return BlocListener<MailBloc, MailState>(
      listenWhen: (previous, current) =>
          previous.isSending && !current.isSending,
      listener: (context, state) {
        final error = state.errorMessage;
        if (error != null && error.isNotEmpty) {
          DdtToast.show(
            message: error,
            type: ToastType.error,
            title: 'Письмо не отправлено',
            duration: const Duration(seconds: 4),
          );
          return;
        }
        DdtToast.show(message: 'Письмо отправлено', type: ToastType.success);
      },
      child: DdtShellLayout(
        title: selectedSection.label,
        selectedSection: selectedSection,
        onSectionSelected: (section) => context.go(section.routePath),
        padContent: padsContentFor(selectedSection, location),
        child: child,
      ),
    );
  }
}
