part of 'notifications_bloc.dart';

final class NotificationsState extends Equatable {
  const NotificationsState({
    this.items = const [],
    this.lastIncoming,
    this.connected = false,
    this.reconnecting = false,
    this.browserPermission,
  });

  final List<AppNotification> items;
  final AppNotification? lastIncoming;
  final bool connected;
  final bool reconnecting;
  final String? browserPermission;

  int get unreadCount => items.where((item) => !item.read).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    AppNotification? Function()? lastIncoming,
    bool? connected,
    bool? reconnecting,
    String? Function()? browserPermission,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      lastIncoming: lastIncoming != null ? lastIncoming() : this.lastIncoming,
      connected: connected ?? this.connected,
      reconnecting: reconnecting ?? this.reconnecting,
      browserPermission: browserPermission != null
          ? browserPermission()
          : this.browserPermission,
    );
  }

  @override
  List<Object?> get props => [
    items,
    lastIncoming,
    connected,
    reconnecting,
    browserPermission,
  ];
}
