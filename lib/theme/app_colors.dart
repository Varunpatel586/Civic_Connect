import 'package:flutter/material.dart';

/// Municipal Navy palette.
///
/// Navy is ink and action here, not background. The interface stays quiet —
/// near-white surfaces, barely-there rules — so the only saturated things on
/// screen are the ones that mean something: a complaint's state, and how long
/// the municipality has left to answer it.
abstract final class AppColors {
  // --- Ink ---------------------------------------------------------------

  /// Headings and primary actions. Deep enough to read as black at a glance
  /// while still carrying the navy identity up close.
  static const navy900 = Color(0xFF0F1F35);

  /// Secondary actions, icons that need to sit back from a heading.
  static const navy700 = Color(0xFF2E4C6D);

  /// Supporting text on the rare navy surface that remains.
  static const navy200 = Color(0xFF8FA6C0);

  // --- Accent ------------------------------------------------------------

  /// Reserved for time pressure: response deadlines, escalation, overdue work.
  /// Spending it anywhere else costs the one signal that should make an
  /// officer look twice.
  static const amber700 = Color(0xFFC77700);

  // --- Neutrals ----------------------------------------------------------

  /// Page background. Cards float on this.
  static const canvas = Color(0xFFF7F8FA);

  static const surface = Color(0xFFFFFFFF);

  /// Body copy that is not a heading.
  static const slate600 = Color(0xFF5C6672);

  /// Metadata: timestamps, wards, counts. Present but never competing.
  static const slate400 = Color(0xFF8B94A0);

  /// The few rules that survive — a nav edge, a field outline.
  static const slate200 = Color(0xFFE6E9ED);

  /// Faint fills and separators inside a surface.
  static const slate100 = Color(0xFFEEF0F3);
}

/// The colours a status needs: text, fill, and a rule for the rare case that
/// still wants one.
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

/// Every complaint state a badge can render, including [overdue] — derived
/// from the response clock rather than stored on the issue.
///
/// Backgrounds are deliberately pale. A status badge should be findable, not
/// loud; the text colour carries the meaning and the fill only groups it.
abstract final class StatusColors {
  static const pending = StatusPalette(
    foreground: Color(0xFF1D4ED8),
    background: Color(0xFFEAF1FE),
    border: Color(0xFFD3E2FD),
  );

  static const inProgress = StatusPalette(
    foreground: Color(0xFFB45309),
    background: Color(0xFFFEF6E7),
    border: Color(0xFFFAE8C2),
  );

  static const resolved = StatusPalette(
    foreground: Color(0xFF15803D),
    background: Color(0xFFE9F7EE),
    border: Color(0xFFCDEBD8),
  );

  static const rejected = StatusPalette(
    foreground: Color(0xFFB91C1C),
    background: Color(0xFFFDECEC),
    border: Color(0xFFF8D5D5),
  );

  static const overdue = StatusPalette(
    foreground: Color(0xFF9A3412),
    background: Color(0xFFFFF1E7),
    border: Color(0xFFFBDCC6),
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
