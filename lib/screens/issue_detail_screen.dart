import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher_string.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../services/issue_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/complaint_reference.dart';
import '../utils/issue_categories.dart';
import '../utils/sla.dart';
import '../widgets/comment_tile.dart';
import '../widgets/status_chip.dart';

/// A single complaint, in full: the evidence, where it stands, what has
/// happened to it, and the discussion under it.
class IssueDetailScreen extends StatefulWidget {
  final String issueId;

  const IssueDetailScreen({super.key, required this.issueId});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final _commentController = TextEditingController();
  final _issueService = IssueService();

  Issue? _issue;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Always refetches rather than reading the provider's cached copy: this
  /// screen shows the status history, which list endpoints do not return.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final issue = await _issueService.getIssueById(widget.issueId);
      if (!mounted) return;

      if (issue == null) {
        setState(() {
          _error = 'This complaint could not be found.';
          _isLoading = false;
        });
        return;
      }

      await context.read<AppProvider>().loadCommentsForIssue(widget.issueId);
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this complaint.';
        _isLoading = false;
      });
    }
  }

  Future<void> _vote(bool isAgree) async {
    final appProvider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (!appProvider.isAuthenticated) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to vote on complaints.')),
      );
      return;
    }

    try {
      await appProvider.voteOnIssue(widget.issueId, isAgree);
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Vote did not go through. Try again.'),
          backgroundColor: StatusColors.rejected.foreground,
        ),
      );
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);
    final appProvider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await appProvider.addComment(widget.issueId, content);
      _commentController.clear();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Comment did not post. Try again.'),
          backgroundColor: StatusColors.rejected.foreground,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _share() {
    final issue = _issue;
    if (issue == null) return;

    Share.share(
      '${issue.title}\n'
      'Complaint ${ComplaintReference.format(issue)} — ${issue.status}\n'
      'Reported via Civic Connect',
    );
  }

  Future<void> _openInMaps() async {
    final issue = _issue;
    if (issue == null) return;

    final url =
        'https://www.google.com/maps/search/?api=1&query=${issue.latitude},${issue.longitude}';
    final messenger = ScaffoldMessenger.of(context);

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('No maps app available to open this.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = context.select<AppProvider, List<Comment>>(
      (p) => p.getCommentsForIssue(widget.issueId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint'),
        actions: [
          if (_issue != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                tooltip: 'Share',
                onPressed: _share,
              ),
            ),
        ],
      ),
      body: _buildBody(comments),
      bottomNavigationBar: _issue == null
          ? null
          : _CommentComposer(
              controller: _commentController,
              isSubmitting: _isSubmitting,
              onSubmit: _submitComment,
            ),
    );
  }

  Widget _buildBody(List<Comment> comments) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: AppColors.slate400,
              ),
              const SizedBox(height: 14),
              Text(_error!, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final issue = _issue!;
    final sla = SlaPolicy.evaluate(issue);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          _Evidence(issue: issue),
          _Summary(issue: issue, sla: sla),
          _LocationRow(issue: issue, onOpenMaps: _openInMaps),
          _VoteBar(issue: issue, onVote: _vote),
          if (issue.statusHistory.isNotEmpty) _Timeline(issue: issue),
          _CommentSection(comments: comments),
        ],
      ),
    );
  }
}

/// The photograph, full width and hard against the chrome.
///
/// The one element here that is not a floating card: it is the evidence, and
/// insetting it would make it read as an illustration rather than a record of
/// what is actually there.
class _Evidence extends StatelessWidget {
  final Issue issue;

  const _Evidence({required this.issue});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: CachedNetworkImage(
        imageUrl: ApiClient().normalizeUrl(issue.imageUrl),
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (context, url) => Container(color: AppColors.slate100),
        errorWidget: (context, url, error) => Container(
          color: AppColors.slate100,
          child: const Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.slate400,
            size: 32,
          ),
        ),
      ),
    );
  }
}

/// Shared wrapper for the sections under the photograph.
///
/// Each is its own card on the canvas: summary, location, community check,
/// history, discussion. They used to be white strips separated by 1px gaps,
/// which made a case file look like a form.
class _Section extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const _Section({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: AppTheme.cardDecoration,
        child: onTap == null
            ? content
            : Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// Category, title, reference, deadline, description.
class _Summary extends StatelessWidget {
  final Issue issue;
  final Sla sla;

  const _Summary({required this.issue, required this.sla});

  @override
  Widget build(BuildContext context) {
    final category = IssueCategories.byValue(issue.category);

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, size: 15, color: AppColors.slate400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  category.label,
                  style: AppTypography.meta(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(status: issue.status, overdue: sla.isOverdue),
            ],
          ),
          const SizedBox(height: 12),
          Text(issue.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                ComplaintReference.format(issue),
                style: AppTypography.recordId(),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'filed ${timeago.format(issue.createdAt)}',
                  style: AppTypography.meta(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (!sla.isClosed) ...[
            const SizedBox(height: 12),
            SlaLabel(sla: sla),
          ],
          if (issue.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 15),
            Text(
              issue.description!.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final Issue issue;
  final VoidCallback onOpenMaps;

  const _LocationRow({required this.issue, required this.onOpenMaps});

  @override
  Widget build(BuildContext context) {
    return _Section(
      onTap: onOpenMaps,
      padding: const EdgeInsets.fromLTRB(18, 15, 16, 15),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 19, color: AppColors.navy700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.address?.trim().isNotEmpty ?? false
                      ? issue.address!
                      : 'Address not recorded',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${issue.latitude.toStringAsFixed(5)}, '
                  '${issue.longitude.toStringAsFixed(5)}',
                  style: AppTypography.recordId(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.open_in_new_rounded,
            size: 16,
            color: AppColors.slate400,
          ),
        ],
      ),
    );
  }
}

/// Community validation: does the neighbourhood agree this is real?
class _VoteBar extends StatelessWidget {
  final Issue issue;
  final ValueChanged<bool> onVote;

  const _VoteBar({required this.issue, required this.onVote});

  @override
  Widget build(BuildContext context) {
    final total = issue.agreeCount + issue.disagreeCount;

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Community check',
                style: AppTypography.sectionLabel(color: AppColors.slate600),
              ),
              const Spacer(),
              Text(
                total == 1 ? '1 response' : '$total responses',
                style: AppTypography.inlineCount(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _VoteButton(
                  label: 'Agree',
                  count: issue.agreeCount,
                  icon: issue.userVote == 'agree'
                      ? Icons.thumb_up
                      : Icons.thumb_up_outlined,
                  active: issue.userVote == 'agree',
                  activeColor: StatusColors.resolved.foreground,
                  onTap: () => onVote(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VoteButton(
                  label: 'Disagree',
                  count: issue.disagreeCount,
                  icon: issue.userVote == 'disagree'
                      ? Icons.thumb_down
                      : Icons.thumb_down_outlined,
                  active: issue.userVote == 'disagree',
                  activeColor: StatusColors.rejected.foreground,
                  onTap: () => onVote(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _VoteButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.slate600;

    return Material(
      color: active ? activeColor.withValues(alpha: 0.09) : AppColors.canvas,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 7),
              Text('$count', style: AppTypography.inlineCount(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything that has happened to this complaint, oldest first.
///
/// Read straight from the recorded history rather than inferred from the
/// current status, so it shows what the municipality actually did and when.
class _Timeline extends StatelessWidget {
  final Issue issue;

  const _Timeline({required this.issue});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d MMM, HH:mm');
    final events = issue.statusHistory;

    return _Section(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Case history',
            style: AppTypography.sectionLabel(color: AppColors.slate600),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < events.length; i++)
            _TimelineEntry(
              event: events[i],
              formatted: format.format(events[i].changedAt.toLocal()),
              isLatest: i == events.length - 1,
              isLast: i == events.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final StatusEvent event;
  final String formatted;
  final bool isLatest;
  final bool isLast;

  const _TimelineEntry({
    required this.event,
    required this.formatted,
    required this.isLatest,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final palette = StatusColors.forStatus(event.status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail: a filled node for the current state, hollow for past ones.
          Column(
            children: [
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: isLatest ? palette.foreground : AppColors.surface,
                  border: Border.all(color: palette.foreground, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.slate100)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        event.status,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.foreground,
                        ),
                      ),
                      const Spacer(),
                      Text(formatted, style: AppTypography.recordId()),
                    ],
                  ),
                  if (event.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.note,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentSection extends StatelessWidget {
  final List<Comment> comments;

  const _CommentSection({required this.comments});

  @override
  Widget build(BuildContext context) {
    return _Section(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  'Discussion',
                  style: AppTypography.sectionLabel(color: AppColors.slate600),
                ),
                const Spacer(),
                Text('${comments.length}', style: AppTypography.inlineCount()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
              child: Text(
                'No comments yet. Add what you know about this issue.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...comments.map((comment) => CommentTile(comment: comment)),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _CommentComposer({
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.slate100)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Add to the discussion',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 46,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(46, 46),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded, size: 19),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
