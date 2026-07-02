import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/calendar/calendar_bloc.dart';
import 'blocs/mail/mail_bloc.dart';
import 'blocs/notifications/notifications_bloc.dart';
import 'blocs/tasks/tasks_bloc.dart';
import 'blocs/theme/theme_bloc.dart';
import 'models/app_notification.dart';
import 'services/session_token_storage.dart';
import 'screens/main_shell_page.dart';
import 'theme/ddt_theme.dart';
import 'widgets/ews_auth_gate.dart';

const _themeStorageBox = 'ddt_storage';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BoltKit.initialize(
    primaryColor: const Color(0xFF1976D2),
    accentColor: const Color(0xFF64B5F6),
  );

  await GetStorage.init(_themeStorageBox);
  await SessionTokenStorage.prepare();

  runApp(const DdtApp());
}

class DdtApp extends StatelessWidget {
  const DdtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ThemeBloc(storage: GetStorage(_themeStorageBox))
            ..add(const ThemeLoadRequested()),
        ),
        BlocProvider(create: (_) => NotificationsBloc()),
        BlocProvider(
          create: (_) => AuthBloc()
            ..add(const AuthSessionRestoreRequested()),
        ),
        BlocProvider(create: (_) => TasksBloc()),
        BlocProvider(create: (_) => MailBloc()),
        BlocProvider(
          create: (_) => CalendarBloc()
            ..add(const CalendarEventsLoadRequested()),
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          // Auth → Notifications
          BlocListener<AuthBloc, AuthState>(
            listener: (context, authState) {
              final notif = context.read<NotificationsBloc>();
              if (authState is AuthAuthenticated) {
                notif.add(const NotificationsConnectRequested());
                context
                    .read<MailBloc>()
                    .add(const MailInboxLoadRequested());
                context
                    .read<CalendarBloc>()
                    .add(const CalendarEventsLoadRequested());
              } else if (authState is AuthUnauthenticated) {
                notif.add(const NotificationsDisconnectRequested());
                notif.add(const NotificationsClearAllRequested());
              }
            },
          ),
          // Auth → Tasks
          BlocListener<AuthBloc, AuthState>(
            listener: (context, authState) {
              if (authState is AuthAuthenticated) {
                context
                    .read<TasksBloc>()
                    .add(const TasksBoardLoadRequested());
              } else if (authState is AuthUnauthenticated) {
                context
                    .read<TasksBloc>()
                    .add(const TasksBoardCleared());
              }
            },
          ),
          // Notifications → Mail / Calendar
          BlocListener<NotificationsBloc, NotificationsState>(
            listenWhen: (previous, current) =>
                previous.items.length != current.items.length,
            listener: (context, notifState) {
              if (notifState.items.isEmpty) return;
              final latest = notifState.items.first;
              switch (latest.category) {
                case AppNotificationCategory.newMail:
                case AppNotificationCategory.mailUpdated:
                  context
                      .read<MailBloc>()
                      .add(const MailInboxRefreshRequested());
                case AppNotificationCategory.calendarUpdated:
                  context
                      .read<CalendarBloc>()
                      .add(const CalendarEventsRefreshRequested());
                case AppNotificationCategory.system:
                  break;
              }
            },
          ),
        ],
        child: BoltKit.builder(
          designSize: const Size(1440, 900),
          builder: () => BlocBuilder<ThemeBloc, ThemeState>(
            buildWhen: (previous, current) =>
                previous.mode != current.mode,
            builder: (context, themeState) => MaterialApp(
              title: 'DDT',
              theme: DdtTheme.light(),
              darkTheme: DdtTheme.dark(),
              themeMode: themeState.mode,
              builder: (context, child) {
                return Material(
                  type: MaterialType.transparency,
                  child: DefaultTextStyle(
                    style: DdtTheme.style(
                        color: DdtTheme.textPrimary(context)),
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              home: const EwsAuthGate(child: MainShellPage()),
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      ),
    );
  }
}
