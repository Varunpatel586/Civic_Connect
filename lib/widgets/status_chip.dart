import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/sla.dart';

/// The complaint's current state, as a bordered badge.
///
/// Deliberately not a Material `Chip`: those carry their own padding, elevation
/// and shape, none of which match the hairline treatment used everywhere else.
class StatusChip extends StatelessWidget {
  final String status;

  /// Renders the [StatusColors.overdue] palette and an alert glyph regardless
  /// of [status]. An overdue Pending complaint is the one thing in the queue an
  /// officer must not scroll past.
  final bool overdue;

  final bool dense;

  const StatusChip({
    super.key,
    required this.status,
    this.overdue = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = overdue
        ? StatusColors.overdue
        : StatusColors.forStatus(status);
    final text = overdue ? 'OVERDUE' : status.toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 7,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (overdue) ...[
            Icon(Icons.priority_high, size: 10, color: palette.foreground),
            const SizedBox(width: 2),
          ],
          Text(text, style: AppTypography.badge(color: palette.foreground)),
        ],
      ),
    );
  }
}

/// The response-deadline countdown.
///
/// Amber is reserved for this across the whole app, so a glance at a screen
/// tells you where the time pressure is without reading a word.
class SlaLabel extends StatelessWidget {
  final Sla sla;

  const SlaLabel({super.key, required this.sla});

  @override
  Widget build(BuildContext context) {
    if (sla.isClosed) return const SizedBox.shrink();

    final color = switch (sla.state) {
      SlaState.overdue => StatusColors.overdue.foreground,
      SlaState.dueSoon => AppColors.amber700,
      _ => AppColors.slate600,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          sla.isOverdue ? Icons.error_outline : Icons.schedule,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          sla.label,
          style: AppTypography.inlineCount(color: color).copyWith(
            fontWeight: sla.state == SlaState.onTrack
                ? FontWeight.w500
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The complaint reference, set in the record face.
class ReferenceLabel extends StatelessWidget {
  final String reference;

  const ReferenceLabel({super.key, required this.reference});

  @override
  Widget build(BuildContext context) {
    return Text(reference, style: AppTypography.recordId());
  }
}
