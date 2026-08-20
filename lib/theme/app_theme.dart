import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Assembles Municipal Navy into a [ThemeData].
///
/// Two rules run through all of it. Surfaces are separated by hairline borders
/// rather than elevation — municipal software looks printed, not floating — and
/// corner radii stay at [radius], small enough to read as institutional without
/// being brutally square.
abstract final class AppTheme {
  static const double radius = 4;
  static const double cardRadius = 6;

  /// Hairline used everywhere a surface meets the canvas.
  static const BorderSide hairline =
      BorderSide(color: AppColors.slate200, width: 1);

  static ThemeData light() {
    final textTheme = AppTypography.textTheme();

    const colorScheme = ColorScheme.light(
      primary: AppColors.navy900,
      onPrimary: Colors.white,
      primaryContainer: AppColors.navy700,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.amber700,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.navy900,
      error: Color(0xFFB91C1C),
      onError: Colors.white,
      outline: AppColors.slate200,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: textTheme,
      dividerColor: AppColors.slate100,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontSize: 17,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: hairline,
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.slate100,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy900,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.slate200,
          disabledForegroundColor: AppColors.slate600,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy900,
          minimumSize: const Size.fromHeight(48),
          side: hairline,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy700,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.slate600),
        border: const OutlineInputBorder(
          borderSide: hairline,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: hairline,
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.navy900, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFB91C1C), width: 1),
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.navy900,
        unselectedItemColor: AppColors.slate600,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTypography.sectionLabel(
          color: AppColors.navy900,
        ).copyWith(fontSize: 11, letterSpacing: 0.2),
        unselectedLabelStyle: AppTypography.sectionLabel(
          color: AppColors.slate600,
        ).copyWith(fontSize: 11, letterSpacing: 0.2),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy900,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.navy200,
        indicatorColor: AppColors.amber700,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: textTheme.titleSmall?.copyWith(color: Colors.white),
        unselectedLabelStyle: textTheme.titleSmall,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.navy900,
        linearMinHeight: 2,
      ),
    );
  }
}
