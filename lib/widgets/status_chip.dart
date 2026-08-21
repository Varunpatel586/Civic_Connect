import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/sla.dart';

/// The complaint's current state.
///
/// Borderless by default: the pale fill groups it and the text colour carries
/// the meaning, which is enough at this size. Only [overdue] keeps a rule,
/// because it is the one state that should stop someone scrolling.
class StatusChip extends StatelessWidget {
  final String status;

  /// Renders the overdue palette and an alert dot regardless of [status]. An
  /// overdue Pending complaint is the one thing in a queue an officer must not
  /// scroll past.
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
        horizontal: dense ? 7 : 8,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        border: overdue ? Border.all(color: palette.border) : null,
        borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
      ),
      child: Text(text, style: AppTypography.badge(color: palette.foreground)),
    );
  }
}

/// The response-deadline countdown.
///
/// A dot rather than an icon: at 6px it reads as a status light, needs no
/// alignment fussing next to text, and keeps the row calm when the deadline is
/// still comfortably away.
class SlaLabel extends StatelessWidget {
  final Sla sla;

  const SlaLabel({super.key, required this.sla});

  @override
  Widget build(BuildContext context) {
    if (sla.isClosed) return const SizedBox.shrink();

    final (color, weight) = switch (sla.state) {
      SlaState.overdue => (StatusColors.overdue.foreground, FontWeight.w600),
      SlaState.dueSoon => (AppColors.amber700, FontWeight.w600),
      _ => (AppColors.slate600, FontWeight.w400),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            sla.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta(color: color).copyWith(
              fontWeight: weight,
            ),
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
