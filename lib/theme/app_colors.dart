import 'package:flutter/material.dart';

/// Municipal Navy palette.
///
/// The chrome stays quiet so the complaint data is the loud thing on screen.
/// Colour carries meaning here: navy is structure, amber is time pressure, and
/// everything else is a [StatusPalette] that maps 1:1 to a complaint state.
abstract final class AppColors {
  // --- Structure ---------------------------------------------------------

  /// App bars, headings, primary actions.
  static const navy900 = Color(0xFF10243E);

  /// Secondary surfaces on dark, pressed states.
  static const navy700 = Color(0xFF2E4C6D);

  /// Supporting text on navy surfaces.
  static const navy200 = Color(0xFF8FA6C0);

  // --- Accent ------------------------------------------------------------

  /// Reserved for time pressure: SLA countdowns, escalation, overdue work.
  /// Using it anywhere else dilutes the one signal that should make an
  /// officer look twice.
  static const amber700 = Color(0xFFC77700);

  // --- Neutrals ----------------------------------------------------------

  /// Page background.
  static const canvas = Color(0xFFF4F6F8);

  static const surface = Color(0xFFFFFFFF);

  /// Muted body text, metadata.
  static const slate600 = Color(0xFF5C6B7A);

  /// Hairline borders. This palette uses borders, not elevation shadows.
  static const slate200 = Color(0xFFD8DEE5);

  /// Dividers inside a card, one step lighter than [slate200].
  static const slate100 = Color(0xFFEDF1F5);
}

/// The three-colour set a status badge needs: text, fill, and hairline.
@immutable
class StatusPalette {
  final Color foreground;
  final Color background;
  final Color border;

  const StatusPalette({
    required this.foreground,
    required this.background,
    required this.border,
  });
}

/// Every complaint state a badge can render, including [overdue] — which is
/// derived from the SLA clock rather than stored on the issue.
abstract final class StatusColors {
  static const pending = StatusPalette(
    foreground: Color(0xFF1D4ED8),
    background: Color(0xFFDBEAFE),
    border: Color(0xFFBFDBFE),
  );

  static const inProgress = StatusPalette(
    foreground: Color(0xFFB45309),
    background: Color(0xFFFEF3C7),
    border: Color(0xFFFDE68A),
  );

  static const resolved = StatusPalette(
    foreground: Color(0xFF15803D),
    background: Color(0xFFDCFCE7),
    border: Color(0xFFBBF7D0),
  );

  static const rejected = StatusPalette(
    foreground: Color(0xFFB91C1C),
    background: Color(0xFFFEE2E2),
    border: Color(0xFFFECACA),
  );

  static const overdue = StatusPalette(
    foreground: Color(0xFF7C2D12),
    background: Color(0xFFFFEDD5),
    border: Color(0xFFFED7AA),
  );

  /// Maps the server's `status` string onto a palette. Unknown values fall
  /// back to [pending] so a new server-side status never renders colourless.
  static StatusPalette forStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in progress':
        return inProgress;
      case 'resolved':
        return resolved;
      case 'rejected':
        return rejected;
      case 'overdue':
        return overdue;
      default:
        return pending;
    }
  }
}
