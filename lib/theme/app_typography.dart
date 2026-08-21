import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type system for Municipal Navy.
///
/// Two faces, split by job. IBM Plex Sans carries the interface; IBM Plex Mono
/// carries anything that is a *record* — complaint references, ward codes,
/// coordinates, metric values. A monospaced complaint ID reads as an entry in
/// a register rather than a string in an app, and that split is the signature
/// of this design.
///
/// Hierarchy comes from size and colour, not from boxes. There is exactly one
/// uppercase style, [badge], and it is spent on status alone.
abstract final class AppTypography {
  /// Applied to every numeric run so digits hold their columns in lists and
  /// tables. Proportional figures make a queue of deadlines look ragged.
  static const _tabular = FontFeature.tabularFigures();

  // --- Interface face ----------------------------------------------------

  static TextTheme textTheme() {
    final base = GoogleFonts.ibmPlexSansTextTheme();

    return base.copyWith(
      // Screen titles.
      headlineMedium: GoogleFonts.ibmPlexSans(
        fontSize: 27,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.2,
        color: AppColors.navy900,
      ),
      headlineSmall: GoogleFonts.ibmPlexSans(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.25,
        color: AppColors.navy900,
      ),

      // Card headings. Up from 15 — the title should be the first thing the
      // eye lands on, without a rule around it to say so.
      titleMedium: GoogleFonts.ibmPlexSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.32,
        letterSpacing: -0.2,
        color: AppColors.navy900,
      ),
      titleSmall: GoogleFonts.ibmPlexSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.1,
        color: AppColors.navy900,
      ),

      // Running text. More line-height than before; minimal layouts live or
      // die on whether the paragraphs breathe.
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: 13.5,
        height: 1.5,
        color: AppColors.slate600,
      ),
      bodySmall: GoogleFonts.ibmPlexSans(
        fontSize: 12.5,
        height: 1.45,
        color: AppColors.slate400,
      ),

      // Buttons.
      labelLarge: GoogleFonts.ibmPlexSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }

  // --- Record face -------------------------------------------------------

  /// Complaint references, ward codes, coordinates. Monospaced and lightly
  /// tracked so the reference reads as something you could quote over a phone.
  static TextStyle recordId({Color color = AppColors.slate400}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      color: color,
      fontFeatures: const [_tabular],
    );
  }

  /// Dashboard metric values. Large, tight, and tabular so a row of counters
  /// stays optically aligned as the numbers change.
  static TextStyle metric({Color color = AppColors.navy900}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      letterSpacing: -1.4,
      height: 1.0,
      color: color,
      fontFeatures: const [_tabular],
    );
  }

  /// Vote tallies and other inline counts sitting beside body text.
  static TextStyle inlineCount({Color color = AppColors.slate400}) {
    return GoogleFonts.ibmPlexMono(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      color: color,
      fontFeatures: const [_tabular],
    );
  }

  // --- Labels ------------------------------------------------------------

  /// The only uppercase in the system, and only ever a complaint's state.
  /// Tracked out because uppercase at this size is unreadable set tight.
  static TextStyle badge({required Color color}) {
    return GoogleFonts.ibmPlexSans(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      height: 1.2,
      color: color,
    );
  }

  /// Section headings inside a screen. Sentence case, quiet — it names the
  /// group without competing with the content under it.
  static TextStyle sectionLabel({Color color = AppColors.slate400}) {
    return GoogleFonts.ibmPlexSans(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: color,
    );
  }

  /// Metadata that sits above or beside a title: category, ward, timestamp.
  static TextStyle meta({Color color = AppColors.slate400}) {
    return GoogleFonts.ibmPlexSans(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: color,
    );
  }
}
