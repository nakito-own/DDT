import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:toastification/toastification.dart';

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
import 'theme/ddt_typography.dart';
import 'utils/browser_page_zoom.dart';
import 'utils/ddt_date_time_picker.dart';
import 'utils/ddt_toast.dart';

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
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc()..add(const AuthSessionRestoreRequested());
    _appRouter = createAppRouter(_authBloc);
  }

  @override
  void dispose() {
    _appRouter.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              ThemeBloc(storage: GetStorage(_themeStorageBox))
                ..add(const ThemeLoadRequested()),
        ),
        BlocProvider(create: (_) => NotificationsBloc()),
        // BlocProvider.value — не создаём новый блок, используем _authBloc
        // из initState, который уже передан в GoRouter.
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => TasksBloc()),
        BlocProvider(create: (_) => MailBloc()),
        BlocProvider(create: (_) => CalendarBloc()),
      ],
      child: MultiBlocListener(
        listeners: [
          // Auth управляет временем жизни персональных данных и подключений.
          BlocListener<AuthBloc, AuthState>(
            listenWhen: (previous, current) =>
                (current is AuthAuthenticated &&
                    previous is! AuthAuthenticated) ||
                (current is AuthUnauthenticated &&
                    previous is! AuthUnauthenticated),
            listener: (context, authState) {
              final notif = context.read<NotificationsBloc>();
              if (authState is AuthAuthenticated) {
                notif.add(const NotificationsConnectRequested());
                context.read<MailBloc>().add(const MailInboxLoadRequested());
                context.read<CalendarBloc>().add(
                  const CalendarEventsLoadRequested(),
                );
              } else if (authState is AuthUnauthenticated) {
                notif.add(const NotificationsDisconnectRequested());
                notif.add(const NotificationsClearAllRequested());
                context.read<TasksBloc>().add(const TasksBoardCleared());
                context.read<MailBloc>().add(const MailSessionCleared());
                context.read<CalendarBloc>().add(
                  const CalendarSessionCleared(),
                );
              }
            },
          ),
          // Notifications → Mail / Calendar
          BlocListener<NotificationsBloc, NotificationsState>(
            listenWhen: (previous, current) =>
                current.items.isNotEmpty &&
                (previous.items.isEmpty ||
                    previous.items.first.id != current.items.first.id),
            listener: (context, notifState) {
              if (notifState.items.isEmpty) return;
              final latest = notifState.items.first;
              DdtToast.show(
                title: latest.title,
                message: latest.body,
                type: ToastType.info,
                duration: const Duration(seconds: 5),
              );
              switch (latest.category) {
                case AppNotificationCategory.newMail:
                case AppNotificationCategory.mailUpdated:
                  context.read<MailBloc>().add(
                    const MailInboxRefreshRequested(),
                  );
                case AppNotificationCategory.calendarUpdated:
                  context.read<CalendarBloc>().add(
                    const CalendarEventsRefreshRequested(),
                  );
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
              buildWhen: (previous, current) => previous.mode != current.mode,
              builder: (context, themeState) => ToastificationWrapper(
                config: ToastificationConfig(
                  alignment: Alignment.topRight,
                  itemWidth: 380,
                  maxToastLimit: 5,
                  animationDuration: const Duration(milliseconds: 320),
                  marginBuilder: (context, alignment) => EdgeInsets.only(
                    top:
                        MediaQuery.paddingOf(context).top +
                        DdtTheme.shellSizeOf(context, 88),
                    right: DdtTheme.shellSizeOf(context, DdtTheme.spacing),
                  ),
                ),
                child: MaterialApp.router(
                  routerConfig: _appRouter.router,
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
                        style: DdtTypography.style(
                          size: DdtTypography.bodySize,
                          color: DdtTheme.textPrimary(context),
                        ),
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
      ),
    );
  }
}
