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

/// A complaint as it appears in a feed or queue.
///
/// Reads top-down the way a case file does: what it looks like, what it is and
/// where it stands, who filed it and where, how long the municipality has left,
/// and only then what you can do about it.
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

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Evidence(issue: issue),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Heading(issue: issue, overdue: sla.isOverdue),
                  const SizedBox(height: 6),
                  ReferenceLabel(reference: ComplaintReference.format(issue)),
                  if (issue.description?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 10),
                    Text(
                      issue.description!.trim(),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _Provenance(issue: issue),
                ],
              ),
            ),
            const Divider(),
            _Ledger(issue: issue, sla: sla),
            if (showActions) ...[
              const Divider(),
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
    );
  }
}

/// The photograph, with the category named over it.
///
/// The category belongs on the image rather than in the body because it is the
/// one label that tells you what you are looking at before you read anything.
class _Evidence extends StatelessWidget {
  final Issue issue;

  const _Evidence({required this.issue});

  @override
  Widget build(BuildContext context) {
    final category = IssueCategories.byValue(issue.category);

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: CachedNetworkImage(
            imageUrl: ApiClient().normalizeUrl(issue.imageUrl),
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppColors.canvas,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.canvas,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.slate200,
                size: 28,
              ),
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.navy900.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, size: 12, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  category.label.toUpperCase(),
                  style: AppTypography.badge(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Title on the left, state on the right.
class _Heading extends StatelessWidget {
  final Issue issue;
  final bool overdue;

  const _Heading({required this.issue, required this.overdue});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            issue.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        StatusChip(status: issue.status, overdue: overdue),
      ],
    );
  }
}

/// Where it was filed and when.
class _Provenance extends StatelessWidget {
  final Issue issue;

  const _Provenance({required this.issue});

  @override
  Widget build(BuildContext context) {
    final locality =
        ComplaintReference.locality(issue.address) ?? 'Location unrecorded';

    return Row(
      children: [
        Icon(Icons.place_outlined, size: 14, color: AppColors.slate600),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            locality,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.schedule_outlined, size: 14, color: AppColors.slate600),
        const SizedBox(width: 4),
        Text(
          timeago.format(issue.timestamp),
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      color: sla.isOverdue ? StatusColors.overdue.background : null,
      child: Row(
        children: [
          Expanded(
            child: sla.isClosed
                ? Text(
                    'Closed ${timeago.format(issue.createdAt)}',
                    style: AppTypography.inlineCount(),
                  )
                : SlaLabel(sla: sla),
          ),
          _Tally(
            icon: Icons.arrow_drop_up,
            count: issue.agreeCount,
            active: issue.userVote == 'agree',
            activeColor: StatusColors.resolved.foreground,
          ),
          const SizedBox(width: 12),
          _Tally(
            icon: Icons.arrow_drop_down,
            count: issue.disagreeCount,
            active: issue.userVote == 'disagree',
            activeColor: StatusColors.rejected.foreground,
          ),
        ],
      ),
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
    final color = active ? activeColor : AppColors.slate600;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        Text(
          '$count',
          style: AppTypography.inlineCount(color: color).copyWith(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Agree / Disagree / Comment.
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
        Expanded(
          child: _ActionButton(
            icon: issue.userVote == 'agree'
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            label: 'Agree',
            active: issue.userVote == 'agree',
            activeColor: StatusColors.resolved.foreground,
            onPressed: () => _vote(context, true),
          ),
        ),
        const _ActionDivider(),
        Expanded(
          child: _ActionButton(
            icon: issue.userVote == 'disagree'
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            label: 'Disagree',
            active: issue.userVote == 'disagree',
            activeColor: StatusColors.rejected.foreground,
            onPressed: () => _vote(context, false),
          ),
        ),
        const _ActionDivider(),
        Expanded(
          child: _ActionButton(
            icon: Icons.mode_comment_outlined,
            label: 'Discuss',
            active: false,
            activeColor: AppColors.navy900,
            onPressed: () => onTap?.call(),
          ),
        ),
      ],
    );
  }

  Future<void> _vote(BuildContext context, bool isAgree) async {
    if (!appProvider.isAuthenticated) {
      _notify(context, 'Sign in to vote on complaints.');
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

  void _notify(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 22, color: AppColors.slate100);
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
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
