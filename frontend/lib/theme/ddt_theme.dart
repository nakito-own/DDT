import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class DdtTheme {
  DdtTheme._();

  static const double borderRadius = 16;
  static const double inputControlRadius = 8;
  static const double spacing = 16;

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightWidget = Color(0xFFFFFFFF);
  static const Color lightInputFill = Color(0xFFF1F5F9);
  static const Color lightBorderStrong = Color(0xFF64748B);

  static const double lightShellGlassBackgroundOpacity = 0.08;
  static const double lightGlassBackgroundOpacity = 0.16;
  static const double lightGlassBackgroundOpacityActive = 0.22;

  static const Color darkBackground = Color(0xFF050508);
  static const Color darkSurface = Color(0xFF0C0C10);
  static const Color darkWidget = Color(0xFF121216);
  static const Color darkInputFill = Color(0xFF0A0A0E);
  static const Color darkBorderStrong = Color(0xFF3F3F48);

  static const Color lightTextPrimary = Color(0xFF020617);
  static const Color lightTextSecondary = Color(0xFF1E293B);
  static const Color lightTextMuted = Color(0xFF334155);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFE2E8F0);
  static const Color darkTextMuted = Color(0xFF94A3B8);

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

  static BorderRadius get inputControlBorderRadius =>
      BorderRadius.circular(inputControlRadius.r);

  static const Color darkPickerSurface = Color(0xFF1C1C22);
  static const Color darkPickerInputFill = Color(0xFF141418);

  static Color inputFillColor(BuildContext context) =>
      _isDark(context) ? darkInputFill : lightInputFill;

  static Color pickerSurfaceColor(BuildContext context) =>
      _isDark(context) ? darkPickerSurface : lightSurface;

  static Color pickerInputFillColor(BuildContext context) =>
      _isDark(context) ? darkPickerInputFill : lightInputFill;

  static TextStyle inputLabelStyle(BuildContext context) => style(
        fontSize: 14.sp,
        color: textSecondary(context),
      );

  static TextStyle inputFloatingLabelStyle(BuildContext context) => style(
        fontSize: 12.sp,
        color: textMuted(context),
      );

  static TextStyle inputHintStyle(BuildContext context) => style(
        fontSize: 14.sp,
        color: textMuted(context),
      );

  static Color inputBorderColor(BuildContext context) =>
      _isDark(context) ? darkBorderStrong : lightBorderStrong;

  static MenuThemeData menuThemeData() => MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: inputControlBorderRadius),
          ),
        ),
      );

  static PopupMenuThemeData popupMenuThemeData() => PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: inputControlBorderRadius),
      );

  static DropdownMenuThemeData dropdownMenuThemeData(
    TextTheme typography,
    Brightness brightness,
  ) {
    final textColor =
        brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

    return DropdownMenuThemeData(
      textStyle: TextStyle(color: textColor),
      menuStyle: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: inputControlBorderRadius),
        ),
      ),
    );
  }

  static double shellSize(num value) => value.r;

  static double shellSizeOf(BuildContext context, num value) {
    return shellSize(value) * MediaQuery.textScalerOf(context).scale(1.0);
  }

  static EdgeInsets get edgePadding => EdgeInsets.all(shellSize(spacing));

  static SizedBox horizontalGap() => SizedBox(width: shellSize(spacing));

  static SizedBox verticalGap() => SizedBox(height: shellSize(spacing));

  static Color glassBorderColor(Brightness brightness) {
    return brightness == Brightness.dark
        ? Colors.white
        : AppColors.primary;
  }

  static double glassBorderOpacity(Brightness brightness) {
    return brightness == Brightness.dark ? 0.34 : 0.58;
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
    final isDark = brightness == Brightness.dark;

    return GlassContainer(
      type: GlassType.frosted,
      shape: GlassShape.roundedRectangle,
      radius: borderRadius.r,
      width: width,
      height: height,
      padding: padding,
      addShadow: addShadow,
      blurIntensity: 10,
      backgroundColor: isDark ? null : Colors.white,
      backgroundOpacity:
          isDark ? 0.2 : lightShellGlassBackgroundOpacity,
      borderColor: glassBorderColor(brightness),
      borderOpacity: isDark
          ? glassBorderOpacity(brightness)
          : glassBorderOpacity(brightness) * 0.72,
      child: child,
    );
  }

  static Color taskCardTextPrimary(BuildContext context) =>
      textPrimary(context);

  static Color taskCardTextSecondary(BuildContext context) =>
      textSecondary(context);

  static Color taskCardIconMuted(BuildContext context) => textMuted(context);

  static GlassContainer contextMenuGlass({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
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
      padding: padding ?? EdgeInsets.all(8.w),
      blurIntensity: blurIntensity,
      backgroundColor: isDark
          ? const Color(0xFF1C1C1E).withValues(alpha: 0.32)
          : Colors.white.withValues(alpha: 0.3),
      backgroundOpacity: isDark ? 0.2 : lightGlassBackgroundOpacity,
      borderColor: glassBorderColor(brightness),
      borderOpacity: glassBorderOpacity(brightness) * 0.65,
      borderWidth: 1,
      addShadow: true,
      shadowBlurRadius: 24,
      shadowSpreadRadius: -4,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.34 : 0.16),
      shadowOffset: const Offset(0, 8),
      child: child,
    );
  }

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
          : (isDragging
              ? lightGlassBackgroundOpacityActive
              : lightGlassBackgroundOpacity),
      borderColor: glassBorderColor(brightness),
      borderOpacity: glassBorderOpacity(brightness) * 0.65,
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
      borderOpacity: glassBorderOpacity(brightness) * 0.55,
      borderWidth: 1,
      addShadow: true,
      shadowBlurRadius: 32,
      shadowSpreadRadius: -6,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.12 : 0.14),
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
        ? Colors.white.withValues(alpha: 0.22)
        : lightBorderStrong.withValues(alpha: 0.72);
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
        floatingLabelStyle: TextStyle(color: darkTextMuted),
        hintStyle: TextStyle(color: darkTextMuted),
        fillColor: darkInputFill,
      ),
      dropdownMenuTheme: dropdownMenuThemeData(theme.textTheme, Brightness.dark),
      menuTheme: menuThemeData(),
      popupMenuTheme: popupMenuThemeData(),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: BorderSide(color: darkBorderStrong),
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

  static const Duration selectionAnimationDuration = Duration(milliseconds: 220);
  static const Curve selectionAnimationCurve = Curves.easeOutCubic;

  static const WidgetStateProperty<Color> _transparentOverlay =
      WidgetStatePropertyAll(Colors.transparent);

  static ButtonStyle _withoutMaterialOverlay(ButtonStyle? style) {
    return (style ?? const ButtonStyle()).copyWith(
      overlayColor: _transparentOverlay,
      splashFactory: NoSplash.splashFactory,
    );
  }

  static ThemeData _applyInteractionTheme(ThemeData theme) {
    return theme.copyWith(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      iconButtonTheme: IconButtonThemeData(
        style: _withoutMaterialOverlay(
          IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        enableFeedback: false,
      ),
      checkboxTheme: theme.checkboxTheme.copyWith(
        splashRadius: 0,
        overlayColor: _transparentOverlay,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _withoutMaterialOverlay(theme.elevatedButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _withoutMaterialOverlay(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _withoutMaterialOverlay(theme.textButtonTheme.style),
      ),
    );
  }

  static ThemeData light() {
    final theme = AppTheme.lightTheme();
    final typography = textTheme(Brightness.light);
    final shape = roundedShape;

    return _applyInteractionTheme(
      theme.copyWith(
      textTheme: typography,
      primaryTextTheme: typography,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: theme.colorScheme.copyWith(
        surface: lightSurface,
        onSurface: lightTextPrimary,
        onSurfaceVariant: lightTextSecondary,
        outline: lightBorderStrong,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: GoogleFonts.nunitoSans(
          textStyle: typography.titleLarge,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        shape: shape,
        backgroundColor: lightSurface,
      ),
      cardTheme: theme.cardTheme.copyWith(
        color: lightSurface,
        shape: shape,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.10),
      ),
      dividerTheme: DividerThemeData(
        color: lightBorderStrong.withValues(alpha: 0.55),
        thickness: 1,
      ),
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
          side: BorderSide(color: AppColors.primary, width: 1.5),
          shape: shape,
          padding: EdgeInsets.symmetric(horizontal: spacing.w, vertical: 12.h),
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: lightInputFill,
        labelStyle: TextStyle(color: lightTextSecondary),
        floatingLabelStyle: TextStyle(color: lightTextMuted),
        hintStyle: TextStyle(color: lightTextMuted),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: lightBorderStrong, width: 1.25),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: lightBorderStrong, width: 1.25),
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
            color: lightBorderStrong.withValues(alpha: 0.55),
          ),
        ),
      ),
      dropdownMenuTheme: dropdownMenuThemeData(typography, Brightness.light),
      menuTheme: menuThemeData(),
      popupMenuTheme: popupMenuThemeData(),
      ),
    );
  }

  static ThemeData dark() {
    final theme = AppTheme.darkTheme();
    final typography = textTheme(Brightness.dark);
    final shape = roundedShape;

    return _applyInteractionTheme(
      theme.copyWith(
      textTheme: typography,
      primaryTextTheme: typography,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: theme.colorScheme.copyWith(
        surface: darkSurface,
        onSurface: darkTextPrimary,
        onSurfaceVariant: darkTextSecondary,
        outline: darkBorderStrong,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: GoogleFonts.nunitoSans(
          textStyle: typography.titleLarge,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        shape: shape,
        backgroundColor: darkSurface,
      ),
      cardTheme: theme.cardTheme.copyWith(
        color: darkWidget,
        shape: shape,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.16),
        thickness: 1,
      ),
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
          side: BorderSide(color: AppColors.primary, width: 1.5),
          shape: shape,
          padding: EdgeInsets.symmetric(horizontal: spacing.w, vertical: 12.h),
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: darkInputFill,
        labelStyle: TextStyle(color: darkTextSecondary),
        floatingLabelStyle: TextStyle(color: darkTextMuted),
        hintStyle: TextStyle(color: darkTextMuted),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: darkBorderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: darkBorderStrong),
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
            color: darkBorderStrong.withValues(alpha: 0.45),
          ),
        ),
      ),
      dropdownMenuTheme: dropdownMenuThemeData(typography, Brightness.dark),
      menuTheme: menuThemeData(),
      popupMenuTheme: popupMenuThemeData(),
      ),
    );
  }

  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
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
