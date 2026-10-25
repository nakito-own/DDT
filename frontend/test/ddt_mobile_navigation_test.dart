import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_native/liquid_glass_native.dart';

import 'package:ddt_frontend/models/app_section.dart';
import 'package:ddt_frontend/widgets/ddt_adaptive.dart';
import 'package:ddt_frontend/widgets/ddt_mobile_navigation_bar.dart';

void main() {
  test('phone tabs keep the extra sections under Дополнения', () {
    expect(AppSection.fromRoute('/more'), AppSection.more);
    expect(DdtMobileNavigationBar.indexOf(AppSection.contacts), 4);
    expect(DdtMobileNavigationBar.indexOf(AppSection.settings), 4);
    expect(DdtMobileNavigationBar.indexOf(AppSection.notes), 3);
  });

  testWidgets('android phone uses a Material bar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    expect(DdtAdaptive.usesLiquidGlassNavigation, isFalse);
    expect(
      DdtAdaptive.materialBottomNavigation(
        web: false,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );

    AppSection? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DdtMobileNavigationBar(
            selectedSection: AppSection.tasks,
            onSectionSelected: (section) => selected = section,
          ),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Задачи'), findsOneWidget);
    expect(find.text('Почта'), findsOneWidget);
    expect(find.text('Календарь'), findsOneWidget);
    expect(find.text('Заметки'), findsOneWidget);
    expect(find.text('Дополнения'), findsOneWidget);

    await tester.tap(find.text('Дополнения'));
    await tester.pump();
    expect(selected, AppSection.more);

    await tester.tap(find.text('Задачи'));
    await tester.pump();
    expect(selected, AppSection.more);
  });

  testWidgets('iphone uses the native glass tab bar', (tester) async {
    expect(DdtAdaptive.usesLiquidGlassNavigation, isTrue);
    expect(
      DdtAdaptive.materialBottomNavigation(
        web: false,
        platform: TargetPlatform.iOS,
      ),
      isFalse,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DdtMobileNavigationBar(
          selectedSection: AppSection.mail,
          onSectionSelected: (_) {},
        ),
      ),
    );

    expect(find.byType(LiquidGlassTabBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('narrow desktop app keeps the drawer decision', (tester) async {
    expect(DdtAdaptive.usesLiquidGlassNavigation, isFalse);
    expect(
      DdtAdaptive.materialBottomNavigation(
        web: false,
        platform: TargetPlatform.macOS,
      ),
      isFalse,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  test('narrow web uses the material bar instead of the drawer', () {
    expect(
      DdtAdaptive.materialBottomNavigation(
        web: true,
        platform: TargetPlatform.macOS,
      ),
      isTrue,
    );
    expect(
      DdtAdaptive.materialBottomNavigation(
        web: true,
        platform: TargetPlatform.iOS,
      ),
      isTrue,
    );
    expect(
      DdtAdaptive.liquidGlassNavigation(
        web: true,
        platform: TargetPlatform.iOS,
      ),
      isFalse,
    );
  });
}
