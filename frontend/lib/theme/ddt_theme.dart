import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class DdtTheme {
  DdtTheme._();

  static const double borderRadius = 18;
  static const double spacing = 16;

  static const Color lightTextPrimary = Color(0xFF0A0F18);
  static const Color lightTextSecondary = Color(0xFF1C2736);
  static const Color lightTextMuted = Color(0xFF334155);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFE8EDF5);
  static const Color darkTextMuted = Color(0xFFCBD5E1);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      _isDark(context) ? darkTextMuted : lightTextMuted;

  static Color loginTitleColor(BuildContext context) => _isDark(context)
      ? darkTextPrimary
      : const Color(0xFF0D47A1);

  static BorderRadius get radius => BorderRadius.circular(borderRadius.r);

  static double shellSize(num value) => value.r;

  static double shellSizeOf(BuildContext context, num value) {
    return shellSize(value) * MediaQuery.textScalerOf(context).scale(1.0);
  }

  static EdgeInsets get edgePadding => EdgeInsets.all(shellSize(spacing));

  static SizedBox horizontalGap() => SizedBox(width: shellSize(spacing));

  static SizedBox verticalGap() => SizedBox(height: shellSize(spacing));

  static Color glassBorderColor(Brightness brightness) {
    return brightness == Brightness.dark ? Colors.white : AppColors.primary;
  }

  static double glassBorderOpacity(Brightness brightness) {
    return brightness == Brightness.dark ? 0.2 : 0.3;
  }

  static GlassContainer glass({
    required BuildContext context,
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    bool addShadow = true,
  }) {
    final brightness = Theme.of(context).brightness;

    return GlassContainer(
      type: GlassType.frosted,
      shape: GlassShape.roundedRectangle,
      radius: borderRadius.r,
      width: width,
      height: height,
      padding: padding,
      addShadow: addShadow,
      borderColor: glassBorderColor(brightness),
      borderOpacity: glassBorderOpacity(brightness),
      child: child,
    );
  }

  static Color taskCardTextPrimary(BuildContext context) =>
      textPrimary(context);

  static Color taskCardTextSecondary(BuildContext context) =>
      textSecondary(context);

  static Color taskCardIconMuted(BuildContext context) => textMuted(context);

  static GlassContainer taskCardGlass({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    VoidCallback? onTap,
    bool isDragging = false,
    double blurIntensity = 6,
    double? cornerRadius,
  }) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final radius = cornerRadius ?? borderRadius.r;

    return GlassContainer(
      type: GlassType.custom,
      shape: GlassShape.roundedRectangle,
      radius: radius,
      padding: padding ?? EdgeInsets.all(spacing.w),
      blurIntensity: blurIntensity,
      backgroundColor: isDark
          ? const Color(0xFF1C1C1E).withValues(alpha: isDragging ? 0.42 : 0.32)
          : Colors.white.withValues(alpha: isDragging ? 0.38 : 0.3),
      backgroundOpacity: isDark
          ? (isDragging ? 0.26 : 0.2)
          : (isDragging ? 0.22 : 0.16),
      borderColor: glassBorderColor(brightness),
      borderOpacity: glassBorderOpacity(brightness) * 0.55,
      borderWidth: 1,
      addShadow: false,
      onTap: onTap,
      child: child,
    );
  }

  static GlassContainer calendarEventGlass({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    VoidCallback? onTap,
    double blurIntensity = 6,
    double? cornerRadius,
    bool highlighted = false,
  }) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final radius = cornerRadius ?? 5.r;
    final baseNeutral = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final blueMix =
        highlighted ? (isDark ? 0.26 : 0.14) : (isDark ? 0.08 : 0.04);

    return GlassContainer(
      type: GlassType.custom,
      shape: GlassShape.roundedRectangle,
      radius: radius,
      padding: padding,
      blurIntensity: blurIntensity,
      backgroundColor: highlighted
          ? AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08)
          : Color.lerp(baseNeutral, AppColors.primary, blueMix)!
              .withValues(alpha: isDark ? 0.32 : 0.3),
      backgroundOpacity: highlighted ? (isDark ? 0.22 : 0.18) : (isDark ? 0.2 : 0.16),
      borderColor: highlighted ? AppColors.primary : glassBorderColor(brightness),
      borderOpacity: highlighted
          ? 0.5
          : glassBorderOpacity(brightness) * 0.55,
      borderWidth: highlighted ? 1.5 : 1,
      addShadow: false,
      onTap: onTap,
      child: child,
    );
  }

  static GlassContainer sidePanelGlass({
    required BuildContext context,
    required Widget child,
  }) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return GlassContainer(
      type: GlassType.minimal,
      shape: GlassShape.roundedRectangle,
      radius: borderRadius.r,
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.zero,
      blurIntensity: 3,
      backgroundOpacity: isDark ? 0.82 : 0.9,
      backgroundColor: isDark
          ? const Color(0xFF1C1C1E).withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.94),
      borderColor: glassBorderColor(brightness),
      borderOpacity: glassBorderOpacity(brightness) * 0.45,
      borderWidth: 1,
      addShadow: true,
      shadowBlurRadius: 32,
      shadowSpreadRadius: -6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shadowOffset: const Offset(-6, 0),
      child: child,
    );
  }

  static EdgeInsets sidePanelInsets(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);

    return EdgeInsets.fromLTRB(
      0,
      viewPadding.top + spacing.h,
      spacing.w,
      viewPadding.bottom + spacing.h,
    );
  }

  static double sidePanelWidth(BuildContext context, {double? maxWidth}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final limit = maxWidth ?? 676;
    final percentage = screenWidth * 0.494;

    return percentage.clamp(416.0, limit);
  }

  static double sidePanelHeight(BuildContext context) {
    final insets = sidePanelInsets(context);
    return MediaQuery.sizeOf(context).height - insets.top - insets.bottom;
  }

  static Color sidePanelTextPrimary(BuildContext context) =>
      textPrimary(context);

  static Color sidePanelTextSecondary(BuildContext context) =>
      textSecondary(context);

  static Color sidePanelTextMuted(BuildContext context) => textMuted(context);

  static Color sidePanelDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.grey.shade300;
  }

  static ThemeData sidePanelTheme(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) return theme;

    return theme.copyWith(
      textTheme: theme.textTheme.apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      iconTheme: theme.iconTheme.copyWith(color: darkTextSecondary),
      colorScheme: theme.colorScheme.copyWith(
        onSurface: darkTextPrimary,
        onSurfaceVariant: darkTextSecondary,
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        labelStyle: TextStyle(color: darkTextSecondary),
        floatingLabelStyle: TextStyle(color: darkTextPrimary),
        hintStyle: TextStyle(color: darkTextMuted),
      ),
      dropdownMenuTheme: theme.dropdownMenuTheme.copyWith(
        textStyle: TextStyle(color: darkTextPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: BorderSide(color: darkTextSecondary.withValues(alpha: 0.45)),
          shape: roundedShape,
          padding: EdgeInsets.symmetric(horizontal: spacing.w, vertical: 12.h),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
    );
  }

  static RoundedRectangleBorder get roundedShape =>
      RoundedRectangleBorder(borderRadius: radius);

  static ShapeBorder get shapeBorder => roundedShape;

  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    var theme = GoogleFonts.nunitoSansTextTheme(base);

    theme = theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(fontSize: 32.sp),
      displayMedium: theme.displayMedium?.copyWith(fontSize: 28.sp),
      displaySmall: theme.displaySmall?.copyWith(fontSize: 24.sp),
      headlineLarge: theme.headlineLarge?.copyWith(fontSize: 22.sp),
      headlineMedium: theme.headlineMedium?.copyWith(fontSize: 20.sp),
      headlineSmall: theme.headlineSmall?.copyWith(fontSize: 18.sp),
      titleLarge: theme.titleLarge?.copyWith(fontSize: 16.sp),
      titleMedium: theme.titleMedium?.copyWith(fontSize: 14.sp),
      titleSmall: theme.titleSmall?.copyWith(fontSize: 12.sp),
      bodyLarge: theme.bodyLarge?.copyWith(fontSize: 16.sp),
      bodyMedium: theme.bodyMedium?.copyWith(fontSize: 14.sp),
      bodySmall: theme.bodySmall?.copyWith(fontSize: 12.sp),
      labelLarge: theme.labelLarge?.copyWith(fontSize: 16.sp),
      labelMedium: theme.labelMedium?.copyWith(fontSize: 14.sp),
      labelSmall: theme.labelSmall?.copyWith(fontSize: 12.sp),
    );

    if (brightness == Brightness.dark) {
      theme = theme.apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      );
    } else {
      theme = theme.apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      );
    }

    return theme;
  }

  static ThemeData light() {
    final theme = AppTheme.lightTheme();
    final typography = textTheme(Brightness.light);
    final shape = roundedShape;

    return theme.copyWith(
      textTheme: typography,
      primaryTextTheme: typography,
      colorScheme: theme.colorScheme.copyWith(
        onSurface: lightTextPrimary,
        onSurfaceVariant: lightTextSecondary,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: GoogleFonts.nunitoSans(
          textStyle: typography.titleLarge,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      dialogTheme: theme.dialogTheme.copyWith(shape: shape),
      cardTheme: theme.cardTheme.copyWith(shape: shape),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: shape,
          padding: EdgeInsets.symmetric(horizontal: spacing.w, vertical: 12.h),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: BorderSide(color: AppColors.primary),
          shape: shape,
          padding: EdgeInsets.symmetric(horizontal: spacing.w, vertical: 12.h),
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        labelStyle: TextStyle(color: lightTextSecondary),
        floatingLabelStyle: TextStyle(color: lightTextPrimary),
        hintStyle: TextStyle(color: lightTextMuted),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: AppColors.lightBorder.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final theme = AppTheme.darkTheme();
    final typography = textTheme(Brightness.dark);
    final shape = roundedShape;

    return theme.copyWith(
      textTheme: typography,
      primaryTextTheme: typography,
      colorScheme: theme.colorScheme.copyWith(
        onSurface: darkTextPrimary,
        onSurfaceVariant: darkTextSecondary,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: GoogleFonts.nunitoSans(
          textStyle: typography.titleLarge,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      dialogTheme: theme.dialogTheme.copyWith(shape: shape),
      cardTheme: theme.cardTheme.copyWith(shape: shape),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: shape,
          padding: EdgeInsets.symmetric(horizontal: spacing.w, vertical: 12.h),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: BorderSide(color: AppColors.primary),
          shape: shape,
          padding: EdgeInsets.symmetric(horizontal: spacing.w, vertical: 12.h),
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        labelStyle: TextStyle(color: darkTextSecondary),
        floatingLabelStyle: TextStyle(color: darkTextPrimary),
        hintStyle: TextStyle(color: darkTextMuted),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: AppColors.darkBorder.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  static InputDecoration inputDecoration({
    required String labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      suffixIcon: suffixIcon,
    );
  }

  static TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.nunitoSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }
}
