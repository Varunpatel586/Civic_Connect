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
    await _loadData(showLoading: true);
  }

  Future<void> _refreshData() async {
    await _loadData(showLoading: false);
  }

  Future<void> _loadData({required bool showLoading}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

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
      await _refreshData();
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
      await _refreshData();
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


  /// The prompt belongs to the people who reported it, and only while the
  /// question is actually open.
  bool _canVerify(Issue issue) {
    if (issue.verificationState != 'pending') return false;
    final me = context.read<AppProvider>().currentUser?.id;
    if (me == null || me.isEmpty) return false;
    return issue.reporterIds.contains(me) || issue.userId == me;
  }

  /// Answers "is this actually fixed?".
  ///
  /// Confirming closes the complaint for good. Disputing sends it back into the
  /// queue escalated, so it asks for a reason first — an unexplained reopen
  /// gives the officer nothing to act on.
  Future<void> _verify(bool confirmed) async {
    String note = '';

    if (!confirmed) {
      final controller = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('What is still wrong?'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Describe what has not been fixed',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reopen complaint'),
            ),
          ],
        ),
      );

      note = controller.text.trim();
      controller.dispose();
      if (proceed != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final updated = await _issueService.verifyFix(
        issueId: widget.issueId,
        confirmed: confirmed,
        note: note,
      );
      if (!mounted) return;
      setState(() => _issue = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmed
                ? 'Thank you. This complaint is now closed.'
                : 'Reopened and escalated to your ward office.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // The server's own words: a complaint somebody else already answered
      // comes back as a 409, which is worth showing rather than swallowing.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          if (_canVerify(issue))
            _VerificationPrompt(
              issue: issue,
              busy: _isSubmitting,
              onAnswer: _verify,
            ),
          if (issue.verificationState == 'disputed')
            _EscalatedBanner(issue: issue),
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
class _Evidence extends StatefulWidget {
  final Issue issue;

  const _Evidence({required this.issue});

  @override
  State<_Evidence> createState() => _EvidenceState();
}

class _EvidenceState extends State<_Evidence> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.issue.imageUrls.isNotEmpty
        ? widget.issue.imageUrls
        : [widget.issue.imageUrl];

    return SizedBox(
      height: MediaQuery.of(context).size.width > 600 ? 280 : 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: urls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: urls[index],
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (context, url) =>
                    Container(color: AppColors.slate100),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.slate100,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.slate400,
                    size: 32,
                  ),
                ),
              );
            },
          ),
          if (urls.length > 1) ...[
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  urls.length,
                  (index) => Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1}/${urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
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
          if (issue.reportCount > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_alt_outlined,
                    color: AppColors.slate600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reported by ${issue.reportCount} citizens. Merged to amplify community priority.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.slate600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                  // The proof photo stays in the record after the
                  // verification prompt has been answered and gone.
                  if (event.photoUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      child: CachedNetworkImage(
                        imageUrl: ApiClient().normalizeUrl(event.photoUrl),
                        height: 128,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, _) =>
                            Container(height: 128, color: AppColors.slate100),
                        errorWidget: (context, _, __) => Container(
                          height: 128,
                          color: AppColors.slate100,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.slate400,
                          ),
                        ),
                      ),
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

/// The question the whole system exists to ask: is it actually fixed?
///
/// Shown only to the people who reported the complaint, and only while the
/// window is open. Deliberately placed directly under the summary rather than
/// at the foot of the page — it is a call to action, not a footnote, and a
/// citizen who has to scroll past the comments to find it will not answer.
class _VerificationPrompt extends StatelessWidget {
  final Issue issue;
  final bool busy;
  final ValueChanged<bool> onAnswer;

  const _VerificationPrompt({
    required this.issue,
    required this.busy,
    required this.onAnswer,
  });

  /// Plain-language time remaining. Precision past a day is noise here.
  String get _remaining {
    final due = issue.verificationDueBy;
    if (due == null) return '';
    final left = due.difference(DateTime.now());
    if (left.isNegative) return 'Closing shortly';
    if (left.inHours >= 24) return '${left.inDays + 1} days left to answer';
    if (left.inHours >= 1) return '${left.inHours} hours left to answer';
    return 'Less than an hour left to answer';
  }

  @override
  Widget build(BuildContext context) {
    final palette = StatusColors.inProgress;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 18, color: palette.foreground),
              const SizedBox(width: 8),
              Text(
                'Is this actually fixed?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: palette.foreground,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your ward office has marked this complaint resolved. Nothing '
            'closes until you say so.',
            style: AppTypography.meta(color: AppColors.slate600),
          ),
          if (_remaining.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_remaining, style: AppTypography.meta(color: AppColors.slate400)),
          ],
          if (issue.resolutionPhotoUrl.isNotEmpty &&
              issue.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            _BeforeAfter(
              beforeUrl: issue.imageUrl,
              afterUrl: issue.resolutionPhotoUrl,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : () => onAnswer(true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Yes, it is fixed'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => onAnswer(false),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('No, reopen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown after a reporter rejected a claimed fix, so the escalation is visible
/// to everyone reading the complaint rather than buried in the timeline.
class _EscalatedBanner extends StatelessWidget {
  final Issue issue;

  const _EscalatedBanner({required this.issue});

  @override
  Widget build(BuildContext context) {
    final palette = StatusColors.overdue;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.priority_high, size: 18, color: palette.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.reopenCount > 1
                      ? 'Reopened ${issue.reopenCount} times'
                      : 'Reopened by the reporter',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (issue.verificationNote.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    issue.verificationNote,
                    style: AppTypography.meta(color: AppColors.slate600),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  'The response deadline was never reset, so this complaint '
                  'sits at the top of the ward queue.',
                  style: AppTypography.meta(color: AppColors.slate400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The original complaint photo beside the officer's photo of the work.
///
/// This is what makes the verification question answerable. Asked from memory,
/// days after filing, a citizen is guessing; shown the two pictures together,
/// they are judging.
class _BeforeAfter extends StatelessWidget {
  final String beforeUrl;
  final String afterUrl;

  const _BeforeAfter({required this.beforeUrl, required this.afterUrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Pane(label: 'You reported', url: beforeUrl)),
        const SizedBox(width: 10),
        Expanded(child: _Pane(label: 'Ward office says', url: afterUrl)),
      ],
    );
  }
}

class _Pane extends StatelessWidget {
  final String label;
  final String url;

  const _Pane({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.sectionLabel()),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: ApiClient().normalizeUrl(url),
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (context, _) => Container(color: AppColors.slate100),
              errorWidget: (context, _, __) => Container(
                color: AppColors.slate100,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.slate400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
