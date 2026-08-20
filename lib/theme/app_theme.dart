import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Assembles Municipal Navy into a [ThemeData].
///
/// The organising rule: surfaces are separated by space and a whisper of
/// shadow, not by rules and colour blocks. Chrome stays near-white so the only
/// weight on screen belongs to the content — which, in a complaint system, is
/// the photograph, the title, and how late the work is.
abstract final class AppTheme {
  /// Buttons, inputs, chips.
  static const double radius = 10;

  /// Cards. Large enough to read as a soft object rather than a boxed row.
  static const double cardRadius = 14;

  /// Status badges and other small fills.
  static const double badgeRadius = 6;

  /// The only rule left in the system, used where an edge is genuinely load
  /// bearing — a nav boundary, a focused field.
  static const BorderSide hairline =
      BorderSide(color: AppColors.slate200, width: 1);

  /// What lifts a card off the canvas. Two layers: a tight one for the edge,
  /// a wide soft one for the lift. Tuned to be felt rather than seen.
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0A0F1F35),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0F0F1F35),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Decoration for anything that should read as a card.
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(cardRadius),
    boxShadow: softShadow,
  );

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

      // White chrome. The wordmark carries the identity now; a solid colour
      // block is how software looked when the chrome *was* the brand.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.navy900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontSize: 18),
        iconTheme: const IconThemeData(color: AppColors.navy900, size: 22),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
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
          disabledBackgroundColor: AppColors.slate100,
          disabledForegroundColor: AppColors.slate400,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy900,
          minimumSize: const Size.fromHeight(50),
          side: hairline,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy900,
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),

      // Filled and borderless. An outline around every field is a lot of rules
      // for something a fill states more quietly.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.slate400),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(radius),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(radius),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.navy900, width: 1.5),
          borderRadius: BorderRadius.circular(radius),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFB91C1C)),
          borderRadius: BorderRadius.circular(radius),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.navy900,
        unselectedItemColor: AppColors.slate400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTypography.sectionLabel(
          color: AppColors.navy900,
        ).copyWith(fontSize: 11.5),
        unselectedLabelStyle: AppTypography.sectionLabel().copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.navy900,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
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

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.navy900,
        unselectedLabelColor: AppColors.slate400,
        indicatorColor: AppColors.navy900,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.slate100,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.navy900,
        linearMinHeight: 3,
      ),
    );
  }
}
