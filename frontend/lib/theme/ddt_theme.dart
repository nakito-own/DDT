import 'dart:math' as math;
import 'dart:ui';

import 'package:bolt_ui_kit/bolt_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ddt_typography.dart';

class DdtTheme {
  DdtTheme._();

  static const double borderRadius = 12;
  static const double inputControlRadius = 8;
  static const double badgeRadius = 6;
  static const double inputControlHeight = 44;
  static const double compactInputControlHeight = 36;
  static const double inputHorizontalPadding = 12;
  static const double inputVerticalPadding = 10;
  static const double spacing = 16;
  static const double scrollbarThickness = 6;
  static const double scrollbarCrossAxisMargin = 2;
  static const double scrollbarMainAxisMargin = 4;

  /// Clear space between content and the scrollbar thumb.
  static const double scrollbarGap = 8;

  /// Reserved space between scrollable content and the scrollbar track.
  /// Thumb thickness, its margin, and [scrollbarGap] so the bar sits
  /// to the right of cards instead of on top of them.
  static const double scrollbarGutter =
      scrollbarThickness + scrollbarCrossAxisMargin + scrollbarGap;

  /// Viewport width below which the shell switches to the phone layout.
  static const double compactLayoutWidth = 1040;

  static bool isCompactLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compactLayoutWidth;
  }

  // Refined Muted Slate-Blue & Sage/Amber/Coral Palette (calm, non-caustic, high legibility)
  static const Color primaryColor = Color(0xFF5279C7);
  static const Color primaryHoverColor = Color(0xFF4267B2);
  static const Color accentColor = Color(0xFF8AA8E6);
  static const Color successColor = Color(0xFF3E9B74);
  static const Color warningColor = Color(0xFFD4943A);
  static const Color dangerColor = Color(0xFFD65C5C);
  static const Color infoColor = Color(0xFF4A90C2);

  // Light Mode Surfaces (Soft Frosted Slate & Pearl Hierarchy)
  static const Color lightBackground = Color(0xFFEEF2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightWidget = Color(0xFFFFFFFF);
  static const Color lightSurfaceSubtle = Color(0xFFF6F8FC);
  static const Color lightInputFill = Color(0xB8FFFFFF);
  static const Color lightBorderSubtle = Color(0xFFDCE3EE);
  static const Color lightBorderStrong = Color(0xFFC4CFE0);

  static const double lightShellGlassBackgroundOpacity = 0.72;
  static const double lightGlassBackgroundOpacity = 0.78;
  static const double lightGlassBackgroundOpacityActive = 0.92;

  // Dark Mode Surfaces (near-black with a cool slate tint)
  static const Color darkBackground = Color(0xFF080A10);
  static const Color darkSurface = Color(0xFF10131A);
  static const Color darkWidget = Color(0xFF171B24);
  static const Color darkSurfaceSubtle = Color(0xFF0C0E14);
  static const Color darkInputFill = Color(0xB812151E);
  static const Color darkBorderSubtle = Color(0xFF262B38);
  static const Color darkBorderStrong = Color(0xFF363D4E);

  static const Color lightTextPrimary = Color(0xFF182232);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF64748B);

  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color scaffoldBackground(BuildContext context) =>
      _isDark(context) ? darkBackground : lightBackground;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      _isDark(context) ? darkTextMuted : lightTextMuted;

  static Color surfaceSubtle(BuildContext context) =>
      _isDark(context) ? darkSurfaceSubtle : lightSurfaceSubtle;

  static Color borderSubtle(BuildContext context) =>
      _isDark(context) ? darkBorderSubtle : lightBorderSubtle;

  static Color borderStrong(BuildContext context) =>
      _isDark(context) ? darkBorderStrong : lightBorderStrong;

  static Color loginTitleColor(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : lightTextPrimary;

  static BorderRadius get radius => BorderRadius.circular(borderRadius.r);

  static BorderRadius get inputControlBorderRadius =>
      BorderRadius.circular(inputControlRadius);

  static BorderRadius get badgeBorderRadius =>
      BorderRadius.circular(badgeRadius.r);

  static const Color darkPickerSurface = Color(0xFF141822);
  static const Color darkPickerInputFill = Color(0xFF0E1118);

  static Color inputFillColor(BuildContext context) =>
      _isDark(context) ? darkInputFill : lightInputFill;

  static Color pickerSurfaceColor(BuildContext context) =>
      _isDark(context) ? darkPickerSurface : lightSurface;

  /// High-contrast tooltip surface for charts and desktop hover hints.
  static Color chartTooltipBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1A1F2B) : const Color(0xFF1E293B);

  static Color chartTooltipForeground(BuildContext context) =>
      const Color(0xFFF8FAFC);

  static TextStyle chartTooltipTextStyle(BuildContext context) => style(
    fontSize: DdtTypography.labelSmallSize,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: chartTooltipForeground(context),
  );

  static TooltipThemeData tooltipThemeData(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF141822).withValues(alpha: 0.96)
            : const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: style(
        fontSize: DdtTypography.captionSize,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFF8FAFC),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 350),
    );
  }

  static Color pickerInputFillColor(BuildContext context) =>
      _isDark(context) ? darkPickerInputFill : lightInputFill;

  static TextStyle inputLabelStyle(BuildContext context) =>
      style(fontSize: DdtTypography.bodySize, color: textSecondary(context));

  static TextStyle inputFloatingLabelStyle(BuildContext context) =>
      style(fontSize: DdtTypography.labelSmallSize, color: textMuted(context));

  static TextStyle inputHintStyle(BuildContext context) => style(
    fontSize: DdtTypography.bodySize,
    color: textMuted(context).withValues(alpha: 0.72),
  );

  static Color inputBorderColor(BuildContext context) =>
      _isDark(context) ? darkBorderStrong : lightBorderStrong;

  static Color inputFillColorHover(BuildContext context) =>
      _isDark(context) ? const Color(0xD6181C28) : const Color(0xD9FFFFFF);

  static Color inputFillColorFocused(BuildContext context) =>
      _isDark(context) ? const Color(0xEB1A1F2C) : const Color(0xF5FFFFFF);

  static List<BoxShadow> inputFocusShadow(BuildContext context) {
    final isDark = _isDark(context);
    return [
      BoxShadow(
        color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.16),
        blurRadius: 0,
        spreadRadius: 2.5,
      ),
    ];
  }

  static EdgeInsetsGeometry inputContentPadding({
    bool compact = false,
    bool multiline = false,
  }) {
    if (compact) {
      return const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
    }
    return EdgeInsets.symmetric(
      horizontal: inputHorizontalPadding,
      vertical: multiline ? 12 : inputVerticalPadding,
    );
  }

  static OutlineInputBorder _outlineBorder({
    required BorderRadius borderRadius,
    required Color color,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static OutlineInputBorder inputOutlineBorder(
    BuildContext context, {
    Color? color,
    double width = 1,
    BorderRadius? borderRadius,
  }) {
    return _outlineBorder(
      borderRadius: borderRadius ?? inputControlBorderRadius,
      color: color ?? inputBorderColor(context).withValues(alpha: 0.75),
      width: width,
    );
  }

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
    final textColor = brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;

    return DropdownMenuThemeData(
      textStyle: typography.bodyMedium?.copyWith(color: textColor),
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
    return brightness == Brightness.dark ? darkBorderStrong : lightBorderSubtle;
  }

  static double glassBorderOpacity(Brightness brightness) {
    return brightness == Brightness.dark ? 0.85 : 1.0;
  }

  static Color shellSurfaceColor(BuildContext context) => _isDark(context)
      ? darkSurface.withValues(alpha: 0.88)
      : lightSurface.withValues(alpha: 0.74);

  static Color shellSurfaceBorderColor(BuildContext context) {
    return _isDark(context)
        ? Colors.white.withValues(alpha: 0.11)
        : Colors.white.withValues(alpha: 0.85);
  }

  static BoxDecoration shellSurfaceDecoration(
    BuildContext context, {
    bool addShadow = true,
    double? radius,
    bool showBorder = true,
  }) {
    final isDark = _isDark(context);

    return BoxDecoration(
      color: shellSurfaceColor(context),
      borderRadius: BorderRadius.circular(radius ?? borderRadius.r),
      border: showBorder
          ? Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.11)
                  : lightBorderSubtle.withValues(alpha: 0.9),
            )
          : null,
      boxShadow: addShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.045),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ]
          : null,
    );
  }

  /// Shell panels (navigation rail, analytics panels, settings cards) use a frosted glass surface.
  static Widget glass({
    required BuildContext context,
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    bool addShadow = true,
    bool showBorder = true,
    double blurSigma = 18,
  }) {
    final isDark = _isDark(context);
    final resolvedRadius = BorderRadius.circular(borderRadius.r);
    final fill = isDark
        ? darkSurface.withValues(alpha: 0.86)
        : lightSurface.withValues(alpha: 0.74);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.11)
        : lightBorderSubtle.withValues(alpha: 0.92);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        boxShadow: addShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: resolvedRadius,
              border: showBorder ? Border.all(color: borderColor) : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Floating app bar: frosted acrylic desktop bar with crisp specular border and subtle shadow.
  static Widget shellAppBarGlass({
    required BuildContext context,
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    double blurSigma = 22,
  }) {
    final isDark = _isDark(context);
    final borderRadiusGeometry = radius;
    final frostTint = isDark
        ? darkSurface.withValues(alpha: 0.84)
        : lightSurface.withValues(alpha: 0.72);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : lightBorderSubtle.withValues(alpha: 0.92);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadiusGeometry,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadiusGeometry,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadiusGeometry,
              color: frostTint,
              border: Border.all(color: borderColor),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  static Color taskCardTextPrimary(BuildContext context) =>
      textPrimary(context);

  static Color taskCardTextSecondary(BuildContext context) =>
      textSecondary(context);

  static Color taskCardIconMuted(BuildContext context) => textMuted(context);

  static Widget contextMenuGlass({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    double blurIntensity = 22,
    double? cornerRadius,
  }) {
    final isDark = _isDark(context);
    final resolvedRadius = BorderRadius.circular(
      cornerRadius ?? borderRadius.r,
    );
    final effectivePadding = padding ?? EdgeInsets.all(6.w);
    final bgColor = isDark
        ? darkPickerSurface.withValues(alpha: 0.92)
        : lightSurface.withValues(alpha: 0.84);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : lightBorderSubtle;

    return Container(
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurIntensity,
            sigmaY: blurIntensity,
          ),
          child: Container(
            padding: effectivePadding,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: resolvedRadius,
              border: Border.all(color: borderColor),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  static Widget taskCardGlass({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    VoidCallback? onTap,
    bool isDragging = false,
    double blurIntensity = 14,
    double? cornerRadius,
  }) {
    final isDark = _isDark(context);
    final resolvedRadius = BorderRadius.circular(
      cornerRadius ?? borderRadius.r,
    );
    final effectivePadding = padding ?? EdgeInsets.all(spacing.w);

    return _DdtInteractiveCardSurface(
      borderRadius: resolvedRadius,
      padding: effectivePadding,
      onTap: onTap,
      isDragging: isDragging,
      isDark: isDark,
      blurIntensity: blurIntensity,
      child: child,
    );
  }

  static Widget calendarEventGlass({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    VoidCallback? onTap,
    double blurIntensity = 10,
    double? cornerRadius,
    bool confirmed = true,
    Color? accent,
  }) {
    final isDark = _isDark(context);
    final resolvedRadius = BorderRadius.circular(cornerRadius ?? 6.r);
    final effectiveAccent = accent ?? primaryColor;
    final baseNeutral = isDark ? darkWidget : lightSurface;
    final fill = confirmed
        ? Color.lerp(
            baseNeutral,
            effectiveAccent,
            isDark ? 0.28 : 0.15,
          )!.withValues(alpha: isDark ? 0.82 : 0.86)
        : (isDark
              ? darkSurfaceSubtle.withValues(alpha: 0.72)
              : lightSurfaceSubtle.withValues(alpha: 0.78));
    final borderColor = confirmed
        ? effectiveAccent.withValues(alpha: isDark ? 0.48 : 0.32)
        : (isDark ? Colors.white.withValues(alpha: 0.10) : lightBorderSubtle);

    Widget content = ClipRRect(
      borderRadius: resolvedRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurIntensity, sigmaY: blurIntensity),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: resolvedRadius,
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }

  static Color sidePanelSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? darkSurface.withValues(alpha: 0.90)
        : lightSurface.withValues(alpha: 0.92);
  }

  static Widget sidePanelGlass({
    required BuildContext context,
    required Widget child,
    double blurSigma = 24,
  }) {
    final isDark = _isDark(context);
    final resolvedRadius = BorderRadius.circular(borderRadius.r);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.13)
        : lightBorderSubtle;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 36,
            spreadRadius: -4,
            offset: const Offset(-8, 0),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: resolvedRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: sidePanelSurfaceColor(context),
              borderRadius: resolvedRadius,
              border: Border.all(color: borderColor),
            ),
            child: child,
          ),
        ),
      ),
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
    // The panel is inset from the right edge, so it can never be wider than the
    // viewport minus that inset. The bound matters at high browser zoom, where
    // the logical viewport can shrink below the preferred panel width.
    final available = math.max(screenWidth - spacing, 0.0);
    final limit = math.min(maxWidth ?? 676, available);
    final percentage = screenWidth * 0.494;

    return percentage.clamp(math.min(416.0, limit), limit);
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
        ? darkBorderSubtle
        : lightBorderSubtle;
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
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: darkTextSecondary,
        ),
        floatingLabelStyle: theme.textTheme.bodySmall?.copyWith(
          color: darkTextMuted,
        ),
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: darkTextMuted),
        fillColor: darkInputFill,
      ),
      dropdownMenuTheme: dropdownMenuThemeData(
        theme.textTheme,
        Brightness.dark,
      ),
      menuTheme: menuThemeData(),
      popupMenuTheme: popupMenuThemeData(),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorderStrong),
          shape: RoundedRectangleBorder(borderRadius: inputControlBorderRadius),
          padding: EdgeInsets.symmetric(horizontal: spacing.w, vertical: 10.h),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
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

    var theme = DdtTypography.textTheme(base);

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

  static const Duration selectionAnimationDuration = Duration(
    milliseconds: 180,
  );
  static const Curve selectionAnimationCurve = Curves.easeOutCubic;
  static const Duration refreshContentDuration = Duration(milliseconds: 260);
  static const Duration refreshShimmerDuration = Duration(milliseconds: 1400);

  static const WidgetStateProperty<Color> _transparentOverlay =
      WidgetStatePropertyAll(Colors.transparent);

  static ButtonStyle _withoutMaterialOverlay(ButtonStyle? style) {
    return (style ?? const ButtonStyle()).copyWith(
      overlayColor: _transparentOverlay,
      splashFactory: NoSplash.splashFactory,
    );
  }

  static ScrollbarThemeData scrollbarThemeData() {
    return ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(scrollbarThickness),
      radius: const Radius.circular(8),
      crossAxisMargin: scrollbarCrossAxisMargin,
      mainAxisMargin: scrollbarMainAxisMargin,
      minThumbLength: 32,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.dragged)) {
          return const Color(0xFF94A3B8).withValues(alpha: 0.65);
        }
        return const Color(0xFF94A3B8).withValues(alpha: 0.35);
      }),
    );
  }

  static EdgeInsets scrollbarContentGutter(
    BuildContext context,
    AxisDirection direction,
  ) {
    // Only vertical scrollables reserve a gutter. Horizontal ones (calendar
    // day headers, kanban) often have a tight max height, and a bottom inset
    // overflows their inner layout.
    final isVertical =
        direction == AxisDirection.down || direction == AxisDirection.up;
    if (!isVertical) {
      return EdgeInsets.zero;
    }

    // Phone layout has no reserved track. A right-only gutter there shifts
    // cards off center.
    if (isCompactLayout(context)) return EdgeInsets.zero;

    final gap = shellSizeOf(context, scrollbarGutter);
    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return isRtl ? EdgeInsets.only(left: gap) : EdgeInsets.only(right: gap);
  }

  static ThemeData _applyInteractionTheme(ThemeData theme) {
    return theme.copyWith(
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      scrollbarTheme: scrollbarThemeData(),
      iconButtonTheme: IconButtonThemeData(
        style: _withoutMaterialOverlay(
          IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ),
      ),
      listTileTheme: const ListTileThemeData(enableFeedback: false),
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

  static void _ensureBoltPalette() {
    AppColors.initialize(primary: primaryColor, accent: accentColor);
    AppTheme.initialize(primary: primaryColor, accent: accentColor);
  }

  static ThemeData light() {
    _ensureBoltPalette();
    final theme = AppTheme.lightTheme();
    final typography = textTheme(Brightness.light);
    final shape = roundedShape;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: inputControlBorderRadius,
    );

    return _applyInteractionTheme(
      theme.copyWith(
        primaryColor: primaryColor,
        iconTheme: const IconThemeData(size: 20, color: lightTextSecondary),
        textTheme: typography,
        primaryTextTheme: typography,
        scaffoldBackgroundColor: lightBackground,
        colorScheme: theme.colorScheme.copyWith(
          primary: primaryColor,
          secondary: accentColor,
          error: dangerColor,
          surface: lightSurface,
          onSurface: lightTextPrimary,
          onSurfaceVariant: lightTextSecondary,
          outline: lightBorderStrong,
          outlineVariant: lightBorderSubtle,
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: GoogleFonts.golosText(
            textStyle: typography.titleLarge,
            color: lightTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        dialogTheme: theme.dialogTheme.copyWith(
          shape: shape,
          backgroundColor: lightSurface,
        ),
        cardTheme: theme.cardTheme.copyWith(
          color: lightSurface,
          shape: shape,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.05),
        ),
        dividerTheme: const DividerThemeData(
          color: lightBorderSubtle,
          thickness: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: typography.labelLarge,
            shape: buttonShape,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.w,
              vertical: 10.h,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: lightTextPrimary,
            backgroundColor: lightSurface,
            textStyle: typography.labelLarge,
            side: const BorderSide(color: lightBorderStrong, width: 1),
            shape: buttonShape,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.w,
              vertical: 10.h,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            textStyle: typography.labelLarge,
            shape: buttonShape,
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: lightInputFill,
          constraints: const BoxConstraints(minHeight: inputControlHeight),
          contentPadding: inputContentPadding(),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          labelStyle: typography.bodyMedium?.copyWith(
            color: lightTextSecondary,
          ),
          floatingLabelStyle: typography.bodySmall?.copyWith(
            color: lightTextMuted,
          ),
          hintStyle: typography.bodyMedium?.copyWith(
            color: lightTextMuted.withValues(alpha: 0.72),
          ),
          border: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: lightBorderSubtle,
          ),
          enabledBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: lightBorderSubtle,
          ),
          focusedBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: primaryColor,
          ),
          errorBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: dangerColor,
          ),
          focusedErrorBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: dangerColor,
          ),
          disabledBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: lightBorderSubtle.withValues(alpha: 0.6),
          ),
        ),
        dropdownMenuTheme: dropdownMenuThemeData(typography, Brightness.light),
        menuTheme: menuThemeData(),
        popupMenuTheme: popupMenuThemeData(),
        tooltipTheme: tooltipThemeData(Brightness.light),
      ),
    );
  }

  static ThemeData dark() {
    _ensureBoltPalette();
    final theme = AppTheme.darkTheme();
    final typography = textTheme(Brightness.dark);
    final shape = roundedShape;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: inputControlBorderRadius,
    );

    return _applyInteractionTheme(
      theme.copyWith(
        primaryColor: primaryColor,
        iconTheme: const IconThemeData(size: 20, color: darkTextSecondary),
        textTheme: typography,
        primaryTextTheme: typography,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: theme.colorScheme.copyWith(
          primary: primaryColor,
          secondary: accentColor,
          error: dangerColor,
          surface: darkSurface,
          surfaceDim: darkBackground,
          surfaceBright: const Color(0xFF1E2430),
          surfaceContainerLowest: darkBackground,
          surfaceContainerLow: darkSurfaceSubtle,
          surfaceContainer: darkSurface,
          surfaceContainerHigh: darkWidget,
          surfaceContainerHighest: const Color(0xFF1E2430),
          onSurface: darkTextPrimary,
          onSurfaceVariant: darkTextSecondary,
          outline: darkBorderStrong,
          outlineVariant: darkBorderSubtle,
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: darkSurface,
          titleTextStyle: GoogleFonts.golosText(
            textStyle: typography.titleLarge,
            color: darkTextPrimary,
            fontWeight: FontWeight.w600,
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
        dividerTheme: const DividerThemeData(
          color: darkBorderSubtle,
          thickness: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: typography.labelLarge,
            shape: buttonShape,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.w,
              vertical: 10.h,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkTextPrimary,
            backgroundColor: darkWidget,
            textStyle: typography.labelLarge,
            side: const BorderSide(color: darkBorderStrong, width: 1),
            shape: buttonShape,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.w,
              vertical: 10.h,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
            textStyle: typography.labelLarge,
            shape: buttonShape,
          ),
        ),
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: darkInputFill,
          constraints: const BoxConstraints(minHeight: inputControlHeight),
          contentPadding: inputContentPadding(),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          labelStyle: typography.bodyMedium?.copyWith(color: darkTextSecondary),
          floatingLabelStyle: typography.bodySmall?.copyWith(
            color: darkTextMuted,
          ),
          hintStyle: typography.bodyMedium?.copyWith(
            color: darkTextMuted.withValues(alpha: 0.72),
          ),
          border: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: darkBorderSubtle,
          ),
          enabledBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: darkBorderSubtle,
          ),
          focusedBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: primaryColor,
          ),
          errorBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: dangerColor,
          ),
          focusedErrorBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: dangerColor,
          ),
          disabledBorder: _outlineBorder(
            borderRadius: inputControlBorderRadius,
            color: darkBorderSubtle.withValues(alpha: 0.6),
          ),
        ),
        dropdownMenuTheme: dropdownMenuThemeData(typography, Brightness.dark),
        menuTheme: menuThemeData(),
        popupMenuTheme: popupMenuThemeData(),
        tooltipTheme: tooltipThemeData(Brightness.dark),
      ),
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
    bool compact = false,
    BorderRadius? borderRadius,
  }) {
    final radiusValue = borderRadius ?? inputControlBorderRadius;

    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: radiusValue,
          borderSide: BorderSide(color: color, width: width),
        );

    final subtleColor = borderSubtle(context);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: inputFillColor(context),
      isDense: compact,
      constraints: BoxConstraints(
        minHeight: compact ? compactInputControlHeight : inputControlHeight,
      ),
      contentPadding: inputContentPadding(compact: compact),
      labelStyle: inputLabelStyle(context),
      floatingLabelStyle: inputFloatingLabelStyle(context),
      hintStyle: inputHintStyle(context),
      border: border(subtleColor),
      enabledBorder: border(subtleColor),
      focusedBorder: border(primaryColor),
      errorBorder: border(dangerColor),
      focusedErrorBorder: border(dangerColor),
      disabledBorder: border(subtleColor.withValues(alpha: 0.55)),
    );
  }

  static TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    return DdtTypography.style(
      size: fontSize ?? DdtTypography.bodySize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }
}

class _DdtInteractiveCardSurface extends StatefulWidget {
  const _DdtInteractiveCardSurface({
    required this.borderRadius,
    required this.padding,
    required this.onTap,
    required this.isDragging,
    required this.isDark,
    required this.blurIntensity,
    required this.child,
  });

  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isDragging;
  final bool isDark;
  final double blurIntensity;
  final Widget child;

  @override
  State<_DdtInteractiveCardSurface> createState() =>
      _DdtInteractiveCardSurfaceState();
}

class _DdtInteractiveCardSurfaceState
    extends State<_DdtInteractiveCardSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final interactive = widget.onTap != null;
    final activeHover = interactive && _hovered && !widget.isDragging;

    final backgroundColor = isDark
        ? (widget.isDragging
              ? const Color(0xE6202636)
              : activeHover
              ? const Color(0xCC1C2230)
              : DdtTheme.darkWidget.withValues(alpha: 0.88))
        : (widget.isDragging
              ? DdtTheme.lightSurface.withValues(alpha: 0.94)
              : activeHover
              ? DdtTheme.lightSurface.withValues(alpha: 0.88)
              : DdtTheme.lightSurface.withValues(alpha: 0.76));

    final borderColor = widget.isDragging
        ? DdtTheme.accentColor.withValues(alpha: isDark ? 0.65 : 0.55)
        : activeHover
        ? (isDark
              ? DdtTheme.accentColor.withValues(alpha: 0.45)
              : DdtTheme.primaryColor.withValues(alpha: 0.35))
        : (isDark
              ? Colors.white.withValues(alpha: 0.11)
              : DdtTheme.lightBorderSubtle.withValues(alpha: 0.90));

    final shadows = widget.isDragging
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark
                    ? (activeHover ? 0.30 : 0.20)
                    : (activeHover ? 0.06 : 0.03),
              ),
              blurRadius: activeHover ? 14 : 8,
              offset: Offset(0, activeHover ? 4 : 2),
            ),
          ];

    Widget card = Container(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurIntensity,
            sigmaY: widget.blurIntensity,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: widget.borderRadius,
              border: Border.all(color: borderColor),
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    if (interactive) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: card,
        ),
      );
    }

    return card;
  }
}
