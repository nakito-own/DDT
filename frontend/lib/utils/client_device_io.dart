import 'dart:io';

import 'client_device_info.dart';

export 'client_device_info.dart';

ClientDevice readClientDevice() {
  final hostname = Platform.localHostname.trim();
  final os = _osLabel();
  return ClientDevice(name: hostname.isEmpty ? os : hostname, os: os);
}

String _osLabel() {
  final family = switch (Platform.operatingSystem) {
    'macos' => 'macOS',
    'ios' => 'iOS',
    'windows' => 'Windows',
    'linux' => 'Linux',
    'android' => 'Android',
    _ => Platform.operatingSystem,
  };
  final match = RegExp(
    r'(\d+(?:\.\d+)?)',
  ).firstMatch(Platform.operatingSystemVersion);
  if (match == null) return family;
  return '$family ${match.group(1)}';
}
