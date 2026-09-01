import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// The single typography scale used by the DDT interface.
///
/// Values are design pixels and are scaled by ScreenUtil at the point of use.
abstract final class DdtTypography {
  static const double micro = 10;
  static const double caption = 11;
  static const double labelSmall = 12;
  static const double label = 13;
  static const double body = 14;
  static const double bodyLarge = 15;
  static const double sectionTitle = 16;
  static const double panelTitle = 18;
  static const double pageTitle = 20;
  static const double entityTitle = 22;
  static const double display = 24;

  static double get microSize => micro.sp;
  static double get captionSize => caption.sp;
  static double get labelSmallSize => labelSmall.sp;
  static double get labelSize => label.sp;
  static double get bodySize => body.sp;
  static double get bodyLargeSize => bodyLarge.sp;
  static double get sectionTitleSize => sectionTitle.sp;
  static double get panelTitleSize => panelTitle.sp;
  static double get pageTitleSize => pageTitle.sp;
  static double get entityTitleSize => entityTitle.sp;
  static double get displaySize => display.sp;

  static TextStyle style({
    required double size,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.nunitoSans(
      fontSize: size,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  static TextTheme textTheme(TextTheme base) {
    final theme = GoogleFonts.nunitoSansTextTheme(base);
    return theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(
        fontSize: displaySize,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: theme.displayMedium?.copyWith(
        fontSize: displaySize,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: theme.displaySmall?.copyWith(
        fontSize: displaySize,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: theme.headlineLarge?.copyWith(
        fontSize: entityTitleSize,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: theme.headlineMedium?.copyWith(
        fontSize: pageTitleSize,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(
        fontSize: panelTitleSize,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: theme.titleLarge?.copyWith(
        fontSize: sectionTitleSize,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: theme.titleMedium?.copyWith(
        fontSize: bodyLargeSize,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: theme.titleSmall?.copyWith(
        fontSize: bodySize,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: theme.bodyLarge?.copyWith(fontSize: bodyLargeSize),
      bodyMedium: theme.bodyMedium?.copyWith(fontSize: bodySize),
      bodySmall: theme.bodySmall?.copyWith(fontSize: labelSmallSize),
      labelLarge: theme.labelLarge?.copyWith(
        fontSize: labelSize,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: theme.labelMedium?.copyWith(
        fontSize: labelSmallSize,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: theme.labelSmall?.copyWith(
        fontSize: captionSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
