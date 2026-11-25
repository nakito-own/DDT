import 'package:ddt_frontend/utils/client_device_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads browser, device and OS from a desktop user agent', () {
    const ua =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    final device = clientDeviceFromUserAgent(ua);

    expect(device.name, 'Chrome, Mac');
    expect(device.os, 'macOS 10.15.7');
  });

  test('reads a phone model separately from the OS', () {
    const ua =
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

    final device = clientDeviceFromUserAgent(ua);

    expect(device.name, 'Chrome, Pixel 8');
    expect(device.os, 'Android 14');
  });
}
