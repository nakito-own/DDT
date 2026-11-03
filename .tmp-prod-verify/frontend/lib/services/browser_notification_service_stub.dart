class BrowserNotificationService {
  static const unsupportedPermission = 'unsupported';

  bool get isSupported => false;

  String get permission => 'denied';

  Future<String> requestPermission() async => unsupportedPermission;

  void show({required String title, required String body}) {}
}

final browserNotificationService = BrowserNotificationService();
