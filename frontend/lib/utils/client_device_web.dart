import 'package:web/web.dart' as web;

import 'client_device_info.dart';
import 'client_device_label.dart';

export 'client_device_info.dart';

ClientDevice readClientDevice() {
  return clientDeviceFromUserAgent(web.window.navigator.userAgent);
}
