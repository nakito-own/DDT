part of 'notifications_bloc.dart';

sealed class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

/// Подключиться к WebSocket (вызывается после успешного логина).
final class NotificationsConnectRequested extends NotificationsEvent {
  const NotificationsConnectRequested();
}

/// Отключиться от WebSocket (вызывается при логауте).
final class NotificationsDisconnectRequested extends NotificationsEvent {
  const NotificationsDisconnectRequested();
}

/// WebSocket получил сообщение.
final class NotificationsMessageReceived extends NotificationsEvent {
  const NotificationsMessageReceived(this.message);

  final Map<String, dynamic> message;

  @override
  List<Object?> get props => [message];
}

/// WebSocket-соединение разорвано — запустить переподключение.
final class NotificationsReconnectScheduled extends NotificationsEvent {
  const NotificationsReconnectScheduled();
}

/// Пользователь прочитал одно уведомление.
final class NotificationsMarkReadRequested extends NotificationsEvent {
  const NotificationsMarkReadRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Пользователь прочитал все уведомления.
final class NotificationsMarkAllReadRequested extends NotificationsEvent {
  const NotificationsMarkAllReadRequested();
}

/// Очистить все уведомления (вызывается при логауте).
final class NotificationsClearAllRequested extends NotificationsEvent {
  const NotificationsClearAllRequested();
}

/// Запросить разрешение браузера на push-уведомления.
final class NotificationsBrowserPermissionRequested extends NotificationsEvent {
  const NotificationsBrowserPermissionRequested();
}
