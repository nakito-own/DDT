import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/theme/ddt_scale.dart';
import 'package:ddt_frontend/theme/ddt_theme.dart';
import 'package:ddt_frontend/widgets/ddt_dialog.dart';

void main() {
  setUpAll(() {
    AppColors.initialize(
      primary: const Color(0xFF5279C7),
      accent: const Color(0xFF8AA8E6),
    );
    AppTheme.initialize(
      primary: const Color(0xFF5279C7),
      accent: const Color(0xFF8AA8E6),
    );
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1440, 900);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('confirm dialog keeps a fixed size and returns the choice', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      _DialogTestApp(
        onPressed: (context) async {
          result = await showDdtConfirm(
            context,
            title: 'Удалить доску?',
            message: 'Доска исчезнет из общего списка.',
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final card = tester.getSize(find.text('Удалить доску?'));
    expect(card.width, lessThan(DdtDialog.width));
    expect(tester.getSize(find.byType(DdtDialog)).width, DdtDialog.width);
    expect(tester.getSize(find.byType(DdtDialog)).height, DdtDialog.height);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('text prompt returns the trimmed title', (tester) async {
    String? result;

    await tester.pumpWidget(
      _DialogTestApp(
        onPressed: (context) async {
          result = await showDdtTextPrompt(
            context,
            title: 'Новая папка',
            confirmLabel: 'Создать',
          );
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Черновик  ');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(result, 'Черновик');
  });
}

class _DialogTestApp extends StatelessWidget {
  const _DialogTestApp({required this.onPressed});

  final Future<void> Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1440, 900)),
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
