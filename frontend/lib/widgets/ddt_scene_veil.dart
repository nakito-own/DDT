import 'package:flutter/material.dart';

/// Light dim over whatever is already on screen. 0 leaves the page unchanged.
class DdtSceneVeil extends StatelessWidget {
  const DdtSceneVeil({super.key, required this.t, required this.dimOpacity});

  final double t;
  final double dimOpacity;

  @override
  Widget build(BuildContext context) {
    final amount = t.clamp(0.0, 1.0);
    // ColoredBox without a child takes the smallest constraint. On web the
    // barrier sits in a loose stack inside PointerInterceptor, so that
    // collapses to 0×0 and the dim never appears.
    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: dimOpacity * amount),
      ),
    );
  }
}
