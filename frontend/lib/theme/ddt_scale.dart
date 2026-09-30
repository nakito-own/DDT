import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Root sizing scope of the application.
///
/// Design pixels map 1:1 to logical pixels. On the web a logical pixel is a
/// CSS pixel, and page zoom works by changing how large a CSS pixel is drawn:
/// zooming to 150% shrinks the viewport to 2/3 of its logical width while
/// magnifying every logical pixel by 1.5.
///
/// ScreenUtil's default behaviour multiplies every size by
/// `viewportWidth / designWidth`, which on the web divides by exactly the
/// factor the browser multiplies by. The two cancel out, the layout is rebuilt
/// on every zoom step and nothing visibly changes. [ScreenUtil.enableScale] is
/// therefore turned off here: sizing goes back to the browser, so page zoom
/// behaves as users expect and different screen sizes are handled by the
/// layout itself (`MediaQuery`, `LayoutBuilder`, `Flexible`) rather than by
/// stretching every control uniformly.
///
/// [ScreenUtilInit] is still installed because `bolt_ui_kit` and a few local
/// widgets read the global [ScreenUtil] instance through the `.w`/`.h`/`.r`/
/// `.sp` extensions; with the scale factors off they resolve to identity.
///
/// See `test/ddt_scale_test.dart`, which pins this behaviour across the common
/// desktop zoom levels.
class DdtScaleScope extends StatelessWidget {
  const DdtScaleScope({super.key, required this.builder, this.child});

  /// Reference viewport the interface is designed against.
  static const Size designSize = Size(1440, 900);

  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      enableScaleWH: () => false,
      enableScaleText: () => false,
      rebuildFactor: (old, data) =>
          old.size != data.size ||
          old.devicePixelRatio != data.devicePixelRatio ||
          old.textScaler != data.textScaler,
      builder: builder,
      child: child,
    );
  }
}
