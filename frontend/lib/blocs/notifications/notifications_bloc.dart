import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/app_notification.dart';
import '../../services/browser_notification_service.dart';
import '../../services/notification_ws_client.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({
    NotificationWsClient? client,
    BrowserNotificationService? browserNotifications,
  }) : _client = client ?? NotificationWsClient(),
       _browserNotifications =
           browserNotifications ?? browserNotificationService,
       super(
         NotificationsState(
           browserPermission:
               (browserNotifications ?? browserNotificationService).permission,
         ),
       ) {
    on<NotificationsConnectRequested>(_onConnectRequested);
    on<NotificationsDisconnectRequested>(_onDisconnectRequested);
    on<NotificationsMessageReceived>(_onMessageReceived);
    on<NotificationsReconnectScheduled>(_onReconnectScheduled);
    on<NotificationsMarkReadRequested>(_onMarkReadRequested);
    on<NotificationsMarkAllReadRequested>(_onMarkAllReadRequested);
    on<NotificationsClearAllRequested>(_onClearAllRequested);
    on<NotificationsBrowserPermissionRequested>(_onBrowserPermissionRequested);

    _client.onMessage = (msg) => add(NotificationsMessageReceived(msg));
    _client.onDisconnected = () => add(const NotificationsReconnectScheduled());
  }

  final NotificationWsClient _client;
  final BrowserNotificationService _browserNotifications;

  // Callback для внешних Bloc-ов, которые хотят реагировать на уведомления.
  // Убирается на Этапе 6 после миграции MailBloc и CalendarBloc.
  void Function(AppNotification)? onNotificationReceived;

  @override
  Future<void> close() {
    _client.onMessage = null;
    _client.onDisconnected = null;
    _client.disconnect();
    return super.close();
  }

  Future<void> _onConnectRequested(
    NotificationsConnectRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(reconnecting: false));
    await _client.connect();
    emit(state.copyWith(connected: _client.isConnected));
  }

  Future<void> _onDisconnectRequested(
    NotificationsDisconnectRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(state.copyWith(reconnecting: false));
    await _client.disconnect();
    emit(state.copyWith(connected: false));
  }

  Future<void> _onMessageReceived(
    NotificationsMessageReceived event,
    Emitter<NotificationsState> emit,
  ) async {
    final message = event.message;
    final msgEvent = message['event'] as String? ?? '';

    if (msgEvent == 'connected') {
      emit(state.copyWith(connected: true, reconnecting: false));
      return;
    }

    if (msgEvent == 'ping') return;
    if (msgEvent != 'notification') return;

    final data = message['data'];
    if (data is! Map<String, dynamic>) return;

    final notification = AppNotification.fromJson(data);
    final updated = [notification, ...state.items];
    final trimmed = updated.length > 50 ? updated.sublist(0, 50) : updated;

    emit(state.copyWith(items: trimmed));

    _browserNotifications.show(
      title: notification.title,
      body: notification.body,
    );

    onNotificationReceived?.call(notification);
  }

  Future<void> _onReconnectScheduled(
    NotificationsReconnectScheduled event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state.reconnecting) return;

    emit(state.copyWith(connected: false, reconnecting: true));
    await Future<void>.delayed(const Duration(seconds: 5));

    if (!state.reconnecting) return;

    await _client.connect();
    if (_client.isConnected) {
      emit(state.copyWith(connected: true, reconnecting: false));
    } else {
      emit(state.copyWith(reconnecting: false));
      add(const NotificationsReconnectScheduled());
    }
  }

  void _onMarkReadRequested(
    NotificationsMarkReadRequested event,
    Emitter<NotificationsState> emit,
  ) {
    final index = state.items.indexWhere((item) => item.id == event.id);
    if (index == -1) return;

    final updated = List<AppNotification>.of(state.items);
    updated[index] = updated[index].markRead();
    emit(state.copyWith(items: updated));
  }

  void _onMarkAllReadRequested(
    NotificationsMarkAllReadRequested event,
    Emitter<NotificationsState> emit,
  ) {
    final updated = state.items.map((item) => item.markRead()).toList();
    emit(state.copyWith(items: updated));
  }

  void _onClearAllRequested(
    NotificationsClearAllRequested event,
    Emitter<NotificationsState> emit,
  ) {
    emit(state.copyWith(items: []));
  }

  Future<void> _onBrowserPermissionRequested(
    NotificationsBrowserPermissionRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final permission = await _browserNotifications.requestPermission();
    emit(state.copyWith(browserPermission: () => permission));
  }
}
