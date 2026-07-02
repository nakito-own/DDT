import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class BrowserNotificationService {
  bool get isSupported => kIsWeb;

  String get permission {
    if (!kIsWeb) {
      return 'denied';
    }
    return web.Notification.permission;
  }

  Future<String> requestPermission() async {
    if (!kIsWeb) {
      return 'denied';
    }
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart;
  }

  void show({
    required String title,
    required String body,
  }) {
    if (!kIsWeb || web.Notification.permission != 'granted') {
      return;
    }

    web.Notification(
      title,
      web.NotificationOptions(body: body),
    );
  }
}

final browserNotificationService = BrowserNotificationService();
