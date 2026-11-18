import 'package:ddt_frontend/widgets/ddt_fullscreen_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new screen fades in without filters', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: DdtFullscreenTransition.duration,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DdtFullscreenTransition(
          animation: controller,
          secondaryAnimation: const AlwaysStoppedAnimation<double>(0),
          child: const Text('Задача'),
        ),
      ),
    );

    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(Opacity), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    final slides = tester.widgetList<FractionalTranslation>(
      find.descendant(
        of: find.byType(DdtFullscreenTransition),
        matching: find.byType(FractionalTranslation),
      ),
    );
    expect(
      slides.map((slide) => slide.translation.dx),
      contains(DdtFullscreenTransition.enterTravel),
    );

    controller.value = 1;
    await tester.pump();

    expect(find.byType(Opacity), findsNothing);
    expect(find.text('Задача'), findsOneWidget);
  });

  testWidgets('screen underneath fades out while covered', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: DdtFullscreenTransition.duration,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DdtCoveredFade(
          animation: controller,
          child: const Text('Список'),
        ),
      ),
    );

    expect(find.byType(Opacity), findsNothing);

    controller.value = 0.4;
    await tester.pump();

    final mid = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));

    controller.value = 1;
    await tester.pump();

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    expect(find.text('Список'), findsOneWidget);
  });
}
