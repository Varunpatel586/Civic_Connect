import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/complaint_reference.dart';
import '../utils/issue_categories.dart';
import '../utils/sla.dart';
import 'status_chip.dart';

/// A complaint as it appears in a feed or a queue.
///
/// Reads the way you would describe it out loud: what kind of problem and
/// where, then what it is, then its reference, then how long the municipality
/// has left. No rules between those — the spacing does the separating.
class IssueCard extends StatelessWidget {
  final Issue issue;
  final VoidCallback? onTap;
  final VoidCallback? onVote;
  final bool showActions;

  const IssueCard({
    super.key,
    required this.issue,
    this.onTap,
    this.onVote,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final sla = SlaPolicy.evaluate(issue);

    return DecoratedBox(
      decoration: AppTheme.cardDecoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.cardRadius),
                ),
                child: _Evidence(issue: issue),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetaLine(issue: issue, overdue: sla.isOverdue),
                    const SizedBox(height: 7),
                    Text(
                      issue.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    ReferenceLabel(reference: ComplaintReference.format(issue)),
                    if (issue.description?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: 11),
                      Text(
                        issue.description!.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 15),
                    _Ledger(issue: issue, sla: sla),
                    if (showActions) ...[
                      const SizedBox(height: 16),
                      _Actions(
                        issue: issue,
                        appProvider: appProvider,
                        onVote: onVote,
                        onTap: onTap,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photograph. Nothing overlaid on it — the category now sits in the meta
/// line where it can be read as text rather than decoded from a chip.
class _Evidence extends StatelessWidget {
  final Issue issue;

  const _Evidence({required this.issue});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: CachedNetworkImage(
        imageUrl: ApiClient().normalizeUrl(issue.imageUrl),
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (context, url) =>
            Container(color: AppColors.slate100),
        errorWidget: (context, url, error) => Container(
          color: AppColors.slate100,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.slate400,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// Category · ward · when, with the status pushed to the right.
///
/// Reads as one sentence of provenance instead of three separate rows with
/// icons, which is what the old card spent most of its height on.
class _MetaLine extends StatelessWidget {
  final Issue issue;
  final bool overdue;

  const _MetaLine({required this.issue, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final parts = [
      IssueCategories.labelFor(issue.category),
      ComplaintReference.locality(issue.address) ?? 'Location unrecorded',
      timeago.format(issue.timestamp, locale: 'en_short'),
    ];

    return Row(
      children: [
        Expanded(
          child: Text(
            parts.join('  ·  '),
            style: AppTypography.meta(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        StatusChip(status: issue.status, overdue: overdue, dense: true),
      ],
    );
  }
}

/// Deadline on the left, community tally on the right.
class _Ledger extends StatelessWidget {
  final Issue issue;
  final Sla sla;

  const _Ledger({required this.issue, required this.sla});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: sla.isClosed
              ? Text(
                  'Closed ${timeago.format(issue.createdAt)}',
                  style: AppTypography.meta(),
                )
              : SlaLabel(sla: sla),
        ),
        _Tally(
          icon: Icons.arrow_upward_rounded,
          count: issue.agreeCount,
          active: issue.userVote == 'agree',
          activeColor: StatusColors.resolved.foreground,
        ),
        const SizedBox(width: 14),
        _Tally(
          icon: Icons.arrow_downward_rounded,
          count: issue.disagreeCount,
          active: issue.userVote == 'disagree',
          activeColor: StatusColors.rejected.foreground,
        ),
      ],
    );
  }
}

class _Tally extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool active;
  final Color activeColor;

  const _Tally({
    required this.icon,
    required this.count,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.slate400;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: AppTypography.inlineCount(color: color).copyWith(
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Agree · Disagree · Discuss, as text rather than three bordered thirds.
class _Actions extends StatelessWidget {
  final Issue issue;
  final AppProvider appProvider;
  final VoidCallback? onVote;
  final VoidCallback? onTap;

  const _Actions({
    required this.issue,
    required this.appProvider,
    required this.onVote,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: issue.userVote == 'agree'
              ? Icons.thumb_up_rounded
              : Icons.thumb_up_outlined,
          label: 'Agree',
          active: issue.userVote == 'agree',
          activeColor: StatusColors.resolved.foreground,
          onPressed: () => _vote(context, true),
        ),
        const SizedBox(width: 20),
        _ActionButton(
          icon: issue.userVote == 'disagree'
              ? Icons.thumb_down_rounded
              : Icons.thumb_down_outlined,
          label: 'Disagree',
          active: issue.userVote == 'disagree',
          activeColor: StatusColors.rejected.foreground,
          onPressed: () => _vote(context, false),
        ),
        const Spacer(),
        _ActionButton(
          icon: Icons.mode_comment_outlined,
          label: 'Discuss',
          active: false,
          activeColor: AppColors.navy900,
          onPressed: () => onTap?.call(),
        ),
      ],
    );
  }

  Future<void> _vote(BuildContext context, bool isAgree) async {
    if (!appProvider.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to vote on complaints.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await appProvider.voteOnIssue(issue.id, isAgree);
      (onVote ?? onTap)?.call();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Vote did not go through. Try again.'),
          backgroundColor: StatusColors.rejected.foreground,
        ),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.slate600;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
