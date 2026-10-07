import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ddt_theme.dart';

/// Desktop/web scrollbars overlay content by default. This behavior keeps a
/// small gutter so list items sit clear of the scrollbar track.
class DdtScrollBehavior extends MaterialScrollBehavior {
  const DdtScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        final gutter = DdtTheme.scrollbarContentGutter(
          context,
          details.direction,
        );
        final paddedChild = gutter == EdgeInsets.zero
            ? child
            : Padding(padding: gutter, child: child);
        return Scrollbar(controller: details.controller, child: paddedChild);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}

/// Keeps wheel/trackpad scrolling and drops click-and-drag, even when a child
/// [ScrollConfiguration.copyWith] tries to enable every pointer kind.
class DdtWheelOnlyScrollBehavior extends MaterialScrollBehavior {
  const DdtWheelOnlyScrollBehavior();

  static const Set<PointerDeviceKind> _dragDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  @override
  Set<PointerDeviceKind> get dragDevices => _dragDevices;

  @override
  ScrollBehavior copyWith({
    bool? scrollbars,
    bool? overscroll,
    Set<PointerDeviceKind>? dragDevices,
    MultitouchDragStrategy? multitouchDragStrategy,
    Set<LogicalKeyboardKey>? pointerAxisModifiers,
    ScrollPhysics? physics,
    TargetPlatform? platform,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
  }) {
    return super.copyWith(
      scrollbars: scrollbars,
      overscroll: overscroll,
      dragDevices: _dragDevices,
      multitouchDragStrategy: multitouchDragStrategy,
      pointerAxisModifiers: pointerAxisModifiers,
      physics: physics,
      platform: platform,
      keyboardDismissBehavior: keyboardDismissBehavior,
    );
  }
}
