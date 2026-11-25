class AppSessionDevice {
  const AppSessionDevice({
    required this.id,
    required this.deviceName,
    required this.osName,
    required this.ipCountry,
    required this.loggedInAt,
    required this.isCurrent,
  });

  final int id;
  final String? deviceName;
  final String? osName;
  final String? ipCountry;
  final DateTime loggedInAt;
  final bool isCurrent;

  factory AppSessionDevice.fromJson(Map<String, dynamic> json) {
    return AppSessionDevice(
      id: json['id'] as int,
      deviceName: _text(json['device_name']),
      osName: _text(json['os_name']),
      ipCountry: _text(json['ip_country']),
      loggedInAt: DateTime.parse(json['logged_in_at'] as String),
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}
