import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/calendar/calendar_bloc.dart';
import 'blocs/mail/mail_bloc.dart';
import 'blocs/notifications/notifications_bloc.dart';
import 'blocs/tasks/tasks_bloc.dart';
import 'blocs/theme/theme_bloc.dart';
import 'models/app_notification.dart';
import 'router/app_router.dart';
import 'services/session_token_storage.dart';
import 'theme/ddt_theme.dart';
import 'utils/browser_page_zoom.dart';
import 'utils/ddt_date_time_picker.dart';

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

class DdtApp extends StatefulWidget {
  const DdtApp({super.key});

  @override
  State<DdtApp> createState() => _DdtAppState();
}

class _DdtAppState extends State<DdtApp> {
  // AuthBloc создаётся здесь, чтобы один и тот же экземпляр мог быть
  // передан одновременно в GoRouter (для redirect) и в BlocProvider
  // (для доступа из виджетного дерева). Это исключает рассинхронизацию
  // состояния между роутером и UI.
  late final AuthBloc _authBloc;
  late final GoRouterHolder _routerHolder;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc()..add(const AuthSessionRestoreRequested());
    _routerHolder = GoRouterHolder(createAppRouter(_authBloc));
  }

  @override
  void dispose() {
    _authBloc.close();
    _routerHolder.router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ThemeBloc(storage: GetStorage(_themeStorageBox))
            ..add(const ThemeLoadRequested()),
        ),
        BlocProvider(create: (_) => NotificationsBloc()),
        // BlocProvider.value — не создаём новый блок, используем _authBloc
        // из initState, который уже передан в GoRouter.
        BlocProvider.value(value: _authBloc),
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
        child: ScreenUtilInit(
          designSize: const Size(1440, 900),
          minTextAdapt: true,
          splitScreenMode: true,
          rebuildFactor: (old, data) =>
              old.size != data.size ||
              old.devicePixelRatio != data.devicePixelRatio ||
              old.textScaler != data.textScaler,
          builder: (context, child) => FlutterViewportSyncScope(
            child: BlocBuilder<ThemeBloc, ThemeState>(
              buildWhen: (previous, current) =>
                  previous.mode != current.mode,
              builder: (context, themeState) => MaterialApp.router(
                routerConfig: _routerHolder.router,
                title: 'DDT',
                locale: ddtPickerLocale,
                supportedLocales: const [ddtPickerLocale],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
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
                debugShowCheckedModeBanner: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Простой контейнер для [GoRouter], чтобы явно управлять его временем жизни.
class GoRouterHolder {
  const GoRouterHolder(this.router);
  final GoRouter router;
}
