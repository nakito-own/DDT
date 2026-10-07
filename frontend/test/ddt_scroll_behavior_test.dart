import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/theme/ddt_scroll_behavior.dart';

void main() {
  test('calendar scroll behavior keeps mouse out of drag devices', () {
    const behavior = DdtWheelOnlyScrollBehavior();
    final copied = behavior.copyWith(
      dragDevices: PointerDeviceKind.values.toSet(),
    );

    expect(behavior.dragDevices.contains(PointerDeviceKind.mouse), isFalse);
    expect(copied.dragDevices.contains(PointerDeviceKind.mouse), isFalse);
    expect(copied.dragDevices.contains(PointerDeviceKind.trackpad), isTrue);
  });
}
