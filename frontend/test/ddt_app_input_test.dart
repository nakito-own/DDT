import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/theme/ddt_theme.dart';
import 'package:ddt_frontend/widgets/ddt_app_input.dart';

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

  testWidgets('the entire input control requests text focus', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _InputTestApp(
        child: DdtAppInput(
          width: 300,
          hint: 'Введите текст',
          focusNode: focusNode,
        ),
      ),
    );

    final inputRect = tester.getRect(find.byType(AnimatedContainer));
    await tester.tapAt(inputRect.centerLeft + const Offset(2, 0));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    final editableRect = tester.getRect(find.byType(EditableText));
    expect(
      (editableRect.center.dy - inputRect.center.dy).abs(),
      lessThanOrEqualTo(4),
    );
  });

  testWidgets('disabled input does not request focus', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _InputTestApp(
        child: DdtAppInput(width: 300, focusNode: focusNode, enabled: false),
      ),
    );

    await tester.tap(find.byType(DdtAppInput));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });
}

class _InputTestApp extends StatelessWidget {
  const _InputTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1440, 900)),
      child: ScreenUtilInit(
        designSize: const Size(1440, 900),
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          theme: DdtTheme.light(),
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }
}
