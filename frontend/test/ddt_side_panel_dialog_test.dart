import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/theme/ddt_scale.dart';
import 'package:ddt_frontend/theme/ddt_theme.dart';
import 'package:ddt_frontend/utils/ddt_date_time_picker.dart';
import 'package:ddt_frontend/widgets/ddt_side_panel.dart';

void main() {
  setUpAll(() {
    AppColors.initialize(
      primary: const Color(0xFF1976D2),
      accent: const Color(0xFF64B5F6),
    );
    AppTheme.initialize(
      primary: const Color(0xFF1976D2),
      accent: const Color(0xFF64B5F6),
    );
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1440, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('a stacked dialog resolves with the popped value',
      (tester) async {
    String? result;

    await tester.pumpWidget(
      _DialogTestApp(
        onPressed: (context) async {
          result = await showDdtSidePanelDialog<String>(
            context,
            builder: (dialogContext) => TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('ok'),
              child: const Text('confirm'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('confirm'));
    await tester.pumpAndSettle();

    expect(result, 'ok');
  });

  testWidgets('the date/time picker returns the chosen moment', (tester) async {
    DateTime? result;

    await tester.pumpWidget(
      _DialogTestApp(
        onPressed: (context) async {
          result = await showDdtDateTimePicker(
            context: context,
            initialDateTime: DateTime(2026, 9, 1, 10, 30),
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 9, 1, 10, 30));
  });

  testWidgets('dismissing the picker resolves with null', (tester) async {
    DateTime? result = DateTime(2020);

    await tester.pumpWidget(
      _DialogTestApp(
        onPressed: (context) async {
          result = await showDdtDateTimePicker(
            context: context,
            initialDateTime: DateTime(2026, 9, 1, 10, 30),
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}

class _DialogTestApp extends StatelessWidget {
  const _DialogTestApp({required this.onPressed});

  final Future<void> Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1440, 2400)),
      child: DdtScaleScope(
        builder: (_, _) => MaterialApp(
          theme: DdtTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (inner) => Center(
                child: TextButton(
                  onPressed: () => onPressed(inner),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
