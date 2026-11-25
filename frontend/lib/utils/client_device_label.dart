import 'client_device_info.dart';

ClientDevice clientDeviceFromUserAgent(String userAgent) {
  final ua = userAgent.trim();
  if (ua.isEmpty) {
    return const ClientDevice(name: 'Браузер', os: 'Неизвестно');
  }
  return ClientDevice(name: _deviceName(ua), os: _osName(ua));
}

String _browserName(String ua) {
  final lower = ua.toLowerCase();
  if (lower.contains('edg/')) return 'Edge';
  if (lower.contains('opr/') || lower.contains('opera')) return 'Opera';
  if (lower.contains('yabrowser')) return 'Яндекс Браузер';
  if (lower.contains('firefox/')) return 'Firefox';
  if (lower.contains('chrome/') || lower.contains('crios/')) return 'Chrome';
  if (lower.contains('safari/')) return 'Safari';
  return 'Браузер';
}

String _deviceName(String ua) {
  final browser = _browserName(ua);
  if (ua.contains('iPhone')) return '$browser, iPhone';
  if (ua.contains('iPad')) return '$browser, iPad';
  final android = RegExp(r'Android [^;)]*;\s*([^;)]+)').firstMatch(ua);
  if (android != null) {
    final model = android.group(1)!.trim();
    if (model.isNotEmpty && !{'linux', 'u', 'k'}.contains(model.toLowerCase())) {
      return '$browser, $model';
    }
    return '$browser, Android';
  }
  if (ua.contains('Macintosh')) return '$browser, Mac';
  if (ua.contains('Windows')) return '$browser, Windows';
  if (ua.contains('CrOS')) return '$browser, Chromebook';
  if (ua.contains('Linux')) return '$browser, Linux';
  return browser;
}

String _osName(String ua) {
  final mac = RegExp(r'Mac OS X (\d+)[_.](\d+)(?:[_.](\d+))?').firstMatch(ua);
  if (mac != null) {
    final patch = mac.group(3);
    final version = patch == null
        ? '${mac.group(1)}.${mac.group(2)}'
        : '${mac.group(1)}.${mac.group(2)}.$patch';
    return 'macOS $version';
  }
  if (ua.contains('iPhone') || ua.contains('iPad')) {
    final ios = RegExp(r'OS (\d+)[_.](\d+)').firstMatch(ua);
    if (ios != null) return 'iOS ${ios.group(1)}.${ios.group(2)}';
    return 'iOS';
  }
  final android = RegExp(r'Android (\d+(?:\.\d+)?)').firstMatch(ua);
  if (android != null) return 'Android ${android.group(1)}';
  if (ua.contains('Windows')) return 'Windows';
  if (ua.contains('CrOS')) return 'ChromeOS';
  if (ua.contains('Linux')) return 'Linux';
  if (ua.contains('Macintosh')) return 'macOS';
  return 'Неизвестно';
}
