import 'package:flutter/material.dart';

/// На мобильных и десктопе картинка рисуется самим Flutter.
class LoginBackgroundHost {
  static final ValueNotifier<String?> failedUrl = ValueNotifier<String?>(null);

  static void preload(String url) {}

  static void sync({
    required String? url,
    required double blurSigma,
    required double scale,
  }) {}
}

class WebBackgroundSurface extends StatelessWidget {
  const WebBackgroundSurface({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
