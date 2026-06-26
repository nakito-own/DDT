import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../theme/ddt_theme.dart';

class DdtGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DdtGlassAppBar({
    super.key,
    required this.title,
  });

  final String title;

  static const double barHeight = 56;

  @override
  Size get preferredSize => Size.fromHeight(DdtTheme.shellSize(barHeight));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : AppColors.primary;
    final height = DdtTheme.shellSizeOf(context, barHeight);

    return RepaintBoundary(
      child: DdtTheme.glass(
        context: context,
        height: height,
        width: double.infinity,
        child: Row(
        children: [
          SizedBox(width: DdtTheme.shellSizeOf(context, 48)),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: DdtTheme.style(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Профиль',
            icon: Icon(
              CupertinoIcons.person,
              color: foregroundColor,
              size: DdtTheme.shellSizeOf(context, 24),
            ),
            onPressed: () {},
          ),
          IconButton(
            tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
            icon: Icon(
              isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon,
              color: foregroundColor,
              size: DdtTheme.shellSizeOf(context, 24),
            ),
            onPressed: () => Get.find<ThemeController>().toggleTheme(),
          ),
        ],
        ),
      ),
    );
  }
}
