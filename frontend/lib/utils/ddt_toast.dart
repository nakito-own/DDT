import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';

/// Корневой messenger приложения.
///
/// В отличие от `Toast` из bolt_ui_kit не зависит от глобального GetX context
/// и поэтому работает с `MaterialApp.router` и вложенными ShellRoute.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

abstract final class DdtToast {
  static void show({
    required String message,
    required ToastType type,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final color = switch (type) {
      ToastType.success => const Color(0xFF07753F),
      ToastType.error => const Color(0xFF942323),
      ToastType.info => const Color(0xFF0F5E9C),
      ToastType.warning => const Color(0xFF946B00),
    };
    final icon = switch (type) {
      ToastType.success => Icons.check_circle_outline,
      ToastType.error => Icons.error_outline,
      ToastType.info => Icons.info_outline,
      ToastType.warning => Icons.warning_amber_rounded,
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}
