import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class BrowserNotificationService {
  /// iOS Safari only exposes `Notification` in a Home Screen web app.
  /// A normal tab has no such global, and reading `.permission` throws.
  static const unsupportedPermission = 'unsupported';

  bool get isSupported {
    if (!globalContext.has('Notification')) return false;
    return globalContext['Notification'] != null;
  }

  String get permission {
    if (!isSupported) return unsupportedPermission;
    return web.Notification.permission;
  }

  Future<String> requestPermission() async {
    if (!isSupported) return unsupportedPermission;
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart;
  }

  void show({required String title, required String body}) {
    if (!isSupported || web.Notification.permission != 'granted') return;
    web.Notification(title, web.NotificationOptions(body: body));
  }
}

final browserNotificationService = BrowserNotificationService();
