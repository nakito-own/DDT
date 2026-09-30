import 'package:flutter/material.dart';

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
        return Scrollbar(
          controller: details.controller,
          child: paddedChild,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}
