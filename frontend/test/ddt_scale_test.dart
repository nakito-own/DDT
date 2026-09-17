import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ddt_frontend/theme/ddt_scale.dart';
import 'package:ddt_frontend/theme/ddt_theme.dart';
import 'package:ddt_frontend/theme/ddt_typography.dart';

/// Browser page zoom levels the desktop interface has to support.
const _zoomLevels = <double>[0.8, 0.9, 1.0, 1.1, 1.25, 1.5];

void main() {
  /// Simulates a browser window of [windowSize] device pixels displayed at
  /// [zoom] page zoom on a display with [baseDevicePixelRatio].
  ///
  /// Page zoom does not resize the window: it multiplies the device pixel ratio
  /// and therefore shrinks the logical (CSS pixel) viewport by the same factor.
  Future<BuildContext> pumpAtZoom(
    WidgetTester tester, {
    required double zoom,
    Size windowSize = const Size(1440, 900),
    double baseDevicePixelRatio = 1,
  }) async {
    late BuildContext capturedContext;

    tester.view.physicalSize = windowSize;
    tester.view.devicePixelRatio = baseDevicePixelRatio * zoom;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      DdtScaleScope(
        builder: (_, _) => MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: const Key('gap'),
                  width: DdtTheme.shellSize(DdtTheme.spacing),
                  height: DdtTheme.shellSize(DdtTheme.spacing),
                ),
              );
            },
          ),
        ),
      ),
    );

    return capturedContext;
  }

  group('browser page zoom', () {
    // Design pixels must stay constant in logical pixels at every zoom level.
    // The browser magnifies a logical pixel by the zoom factor, so constant
    // logical sizes are exactly what makes the interface grow and shrink.
    // Scaling sizes by `viewportWidth / designWidth` instead would divide by
    // the same factor the browser multiplies by, and zoom would do nothing.
    for (final zoom in _zoomLevels) {
      final percent = (zoom * 100).round();

      testWidgets('design tokens stay in logical pixels at $percent%', (
        tester,
      ) async {
        final context = await pumpAtZoom(tester, zoom: zoom);

        expect(ScreenUtil().scaleWidth, 1);
        expect(ScreenUtil().scaleHeight, 1);
        expect(ScreenUtil().scaleText, 1);

        expect(16.w, 16);
        expect(16.h, 16);
        expect(16.r, 16);
        expect(14.sp, 14);

        expect(DdtTypography.bodySize, DdtTypography.body);
        expect(DdtTheme.shellSize(DdtTheme.spacing), DdtTheme.spacing);
        expect(
          tester.getSize(find.byKey(const Key('gap'))).width,
          DdtTheme.spacing,
        );

        // The viewport really did change; only the sizing stayed put.
        expect(MediaQuery.sizeOf(context).width, closeTo(1440 / zoom, 0.001));
        expect(MediaQuery.devicePixelRatioOf(context), closeTo(zoom, 0.001));
      });
    }

    testWidgets('zoom is independent of the display device pixel ratio', (
      tester,
    ) async {
      await pumpAtZoom(
        tester,
        zoom: 1.25,
        windowSize: const Size(2880, 1800),
        baseDevicePixelRatio: 2,
      );

      expect(ScreenUtil().scaleWidth, 1);
      expect(14.sp, 14);
      expect(DdtTheme.shellSize(DdtTheme.spacing), DdtTheme.spacing);
    });
  });

  group('responsive layout', () {
    testWidgets('side panel never outgrows the viewport', (tester) async {
      for (final zoom in _zoomLevels) {
        for (final windowSize in const [
          Size(1024, 768),
          Size(1440, 900),
          Size(1920, 1080),
        ]) {
          final context = await pumpAtZoom(
            tester,
            zoom: zoom,
            windowSize: windowSize,
          );
          final viewportWidth = MediaQuery.sizeOf(context).width;
          final width = DdtTheme.sidePanelWidth(context);

          expect(
            width,
            lessThanOrEqualTo(viewportWidth),
            reason: 'panel width at $windowSize / $zoom zoom',
          );
          expect(width, greaterThan(0));
        }
      }
    });

    testWidgets('side panel keeps its design width on a desktop viewport', (
      tester,
    ) async {
      final context = await pumpAtZoom(tester, zoom: 1);

      // 49.4% of a 1440px viewport exceeds the default cap, so the cap wins.
      expect(DdtTheme.sidePanelWidth(context), 676);
      expect(DdtTheme.sidePanelWidth(context, maxWidth: 500), 500);
    });
  });
}
