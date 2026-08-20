import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type system for Municipal Navy.
///
/// Two faces, split by job. IBM Plex Sans carries the interface; IBM Plex Mono
/// carries anything that is a *record* — complaint IDs, ward codes,
/// coordinates, metric values. That split is the signature of this design:
/// a monospaced complaint ID reads as an entry in a register rather than a
/// string in an app, which is most of what separates this from a class project.
abstract final class AppTypography {
  /// Applied to every numeric run so digits hold their columns in lists and
  /// tables. Proportional figures make a queue of SLA timers look ragged.
  static const _tabular = FontFeature.tabularFigures();

  // --- Interface face ----------------------------------------------------

  static TextTheme textTheme() {
    final base = GoogleFonts.ibmPlexSansTextTheme();

    return base.copyWith(
      // Screen titles.
      headlineMedium: GoogleFonts.ibmPlexSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: AppColors.navy900,
      ),
      headlineSmall: GoogleFonts.ibmPlexSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.navy900,
      ),

      // Card headings.
      titleMedium: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.1,
        color: AppColors.navy900,
      ),
      titleSmall: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.navy900,
      ),

      // Running text.
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        height: 1.45,
        color: AppColors.slate600,
      ),
      bodySmall: GoogleFonts.ibmPlexSans(
        fontSize: 12,
        height: 1.4,
        color: AppColors.slate600,
      ),

      // Buttons.
      labelLarge: GoogleFonts.ibmPlexSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }

  // --- Record face -------------------------------------------------------

  /// Complaint IDs, ward codes, coordinates. Monospaced and slightly tracked
  /// out so the reference reads as something you could quote over a phone.
  static TextStyle recordId({Color color = AppColors.slate600}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      color: color,
      fontFeatures: const [_tabular],
    );
  }

  /// Dashboard metric values. Large, tight, and tabular so a row of counters
  /// stays optically aligned as the numbers change.
  static TextStyle metric({Color color = AppColors.navy900}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: 30,
      fontWeight: FontWeight.w600,
      letterSpacing: -1,
      height: 1.05,
      color: color,
      fontFeatures: const [_tabular],
    );
  }

  /// Vote tallies and other inline counts sitting beside body text.
  static TextStyle inlineCount({Color color = AppColors.slate600}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: color,
      fontFeatures: const [_tabular],
    );
  }

  // --- Micro labels ------------------------------------------------------

  /// Uppercase eyebrow used on status badges and section headers. Tracked out
  /// heavily because uppercase at this size is unreadable set tight.
  static TextStyle badge({required Color color}) {
    return GoogleFonts.ibmPlexSans(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      height: 1.2,
      color: color,
    );
  }

  /// Section dividers in long scrolling views.
  static TextStyle sectionLabel({Color color = AppColors.slate600}) {
    return GoogleFonts.ibmPlexSans(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: color,
    );
  }
}
