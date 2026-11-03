import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../blocs/calendar/calendar_bloc.dart';
import '../blocs/mail/mail_bloc.dart';
import '../blocs/notifications/notifications_bloc.dart';
import '../models/app_notification.dart';
import '../router/route_paths.dart';

/// Сигнал из системного уведомления браузера: оболочка ещё в дереве и
/// откроет связанный объект.
final ValueNotifier<AppNotification?> notificationLaunchRequest =
    ValueNotifier<AppNotification?>(null);

void requestNotificationLaunch(AppNotification item) {
  if (!item.opensObject) return;
  notificationLaunchRequest.value = item;
}

void openAppNotification(BuildContext context, AppNotification item) {
  context.read<NotificationsBloc>().add(NotificationsMarkReadRequested(item.id));
  switch (item.target) {
    case AppNotificationTarget.mail:
      final messageId = item.itemId;
      context.go(RoutePaths.mail);
      if (messageId == null || messageId.isEmpty) return;
      context.read<MailBloc>().add(
        MailOpenByIdRequested(messageId: messageId, subject: item.matchSubject),
      );
    case AppNotificationTarget.calendar:
      context.go(RoutePaths.calendar);
      context.read<CalendarBloc>().add(
        CalendarEventOpenRequested(
          eventId: item.itemId,
          subject: item.matchSubject,
          start: item.focusAt,
        ),
      );
    case AppNotificationTarget.task:
      final taskKey = item.taskKey ?? item.itemId;
      if (taskKey == null || taskKey.isEmpty) return;
      context.go(
        RoutePaths.forTask(
          taskKey: taskKey,
          spaceKey: item.spaceKey,
        ),
      );
    case AppNotificationTarget.none:
      return;
  }
}

/// Слушает клик по системному уведомлению и открывает объект.
class NotificationLaunchListener extends StatefulWidget {
  const NotificationLaunchListener({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationLaunchListener> createState() =>
      _NotificationLaunchListenerState();
}

class _NotificationLaunchListenerState extends State<NotificationLaunchListener> {
  @override
  void initState() {
    super.initState();
    notificationLaunchRequest.addListener(_onLaunch);
  }

  @override
  void dispose() {
    notificationLaunchRequest.removeListener(_onLaunch);
    super.dispose();
  }

  void _onLaunch() {
    final item = notificationLaunchRequest.value;
    if (item == null) return;
    notificationLaunchRequest.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openAppNotification(context, item);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
