import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';

import '../theme/ddt_theme.dart';
import '../theme/ddt_typography.dart';

abstract final class DdtToast {
  static void show({
    required String message,
    required ToastType type,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    final accentColor = switch (type) {
      ToastType.success => const Color(0xFF16A467),
      ToastType.error => const Color(0xFFE04F5F),
      ToastType.info => const Color(0xFF3B82F6),
      ToastType.warning => const Color(0xFFE1A11A),
    };
    final icon = switch (type) {
      ToastType.success => Icons.check_circle_outline,
      ToastType.error => Icons.error_outline,
      ToastType.info => Icons.info_outline,
      ToastType.warning => Icons.warning_amber_rounded,
    };

    toastification.showCustom(
      alignment: Alignment.topRight,
      autoCloseDuration: duration,
      builder: (context, item) => MouseRegion(
        onEnter: (_) => item.pause(),
        onExit: (_) => item.start(),
        child: Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: DdtTheme.radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.34
                        : 0.14,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: DdtTheme.taskCardGlass(
              context: context,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Semantics(
                liveRegion: true,
                label: [title, message].whereType<String>().join('. '),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36.r,
                      height: 36.r,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(icon, color: accentColor, size: 21.r),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 1.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null) ...[
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: DdtTheme.style(
                                  fontSize: DdtTypography.bodySize,
                                  fontWeight: FontWeight.w700,
                                  color: DdtTheme.taskCardTextPrimary(context),
                                ),
                              ),
                              SizedBox(height: 3.h),
                            ],
                            Text(
                              message,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: DdtTheme.style(
                                fontSize: DdtTypography.labelSize,
                                height: 1.35,
                                color: title == null
                                    ? DdtTheme.taskCardTextPrimary(context)
                                    : DdtTheme.taskCardTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    IconButton(
                      tooltip: 'Закрыть',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints.tightFor(
                        width: 28.r,
                        height: 28.r,
                      ),
                      onPressed: () => toastification.dismissById(item.id),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18.r,
                        color: DdtTheme.taskCardIconMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
