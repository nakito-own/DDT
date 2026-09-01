import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/theme/ddt_theme.dart';
import 'package:ddt_frontend/theme/ddt_typography.dart';

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

  testWidgets('light and dark themes use the shared typography scale', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      late TextTheme textTheme;
      await tester.pumpWidget(
        _TypographyTestApp(
          brightness: brightness,
          child: Builder(
            builder: (context) {
              textTheme = Theme.of(context).textTheme;
              return const Text('DDT');
            },
          ),
        ),
      );

      expect(textTheme.bodyMedium?.fontSize, DdtTypography.bodySize);
      expect(textTheme.labelSmall?.fontSize, DdtTypography.captionSize);
      expect(textTheme.titleLarge?.fontSize, DdtTypography.sectionTitleSize);
      expect(textTheme.headlineLarge?.fontSize, DdtTypography.entityTitleSize);
      expect(textTheme.displaySmall?.fontSize, DdtTypography.displaySize);
    }
  });

  testWidgets('typography respects the inherited text scaler', (tester) async {
    const scaler = TextScaler.linear(1.5);
    await tester.pumpWidget(
      _TypographyTestApp(
        brightness: Brightness.light,
        textScaler: scaler,
        child: Builder(
          builder: (context) => Text(
            'Scaled text',
            key: const Key('scaled-text'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const Key('scaled-text')),
        matching: find.byType(RichText),
      ),
    );
    expect(
      richText.textScaler.scale(DdtTypography.bodySize),
      closeTo(DdtTypography.bodySize * 1.5, 0.001),
    );
  });
}

class _TypographyTestApp extends StatelessWidget {
  const _TypographyTestApp({
    required this.brightness,
    required this.child,
    this.textScaler = TextScaler.noScaling,
  });

  final Brightness brightness;
  final Widget child;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(size: const Size(1440, 900), textScaler: textScaler),
      child: ScreenUtilInit(
        designSize: const Size(1440, 900),
        minTextAdapt: true,
        builder: (_, _) => MaterialApp(
          theme: brightness == Brightness.light
              ? DdtTheme.light()
              : DdtTheme.dark(),
          home: Scaffold(body: child),
        ),
      ),
    );
  }
}
