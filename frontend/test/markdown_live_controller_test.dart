import 'package:ddt_frontend/widgets/ddt_markdown_live_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('caret before a leading newline does not crash the list toolbar', () {
    final controller = DdtMarkdownLiveController();
    addTearDown(controller.dispose);
    controller.value = const TextEditingValue(
      text: '\n\nИван:\n> Короткая цитата',
      selection: TextSelection.collapsed(offset: 0),
    );

    expect(controller.bulletListActive, isFalse);
    expect(controller.numberedListActive, isFalse);
  });
}
