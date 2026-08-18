import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class IssueCard extends StatelessWidget {
  final Issue issue;
  final VoidCallback? onTap;
  final bool showActions;

  const IssueCard({
    super.key,
    required this.issue,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Issue Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: issue.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
            ),

            // Issue Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issue.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(theme, issue.status),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Description
                  if (issue.description?.isNotEmpty ?? false) ...[
                    Text(
                      issue.description!,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Location and Time
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          issue.address ?? 'Unknown location',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeago.format(issue.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (showActions) ..._buildActionButtons(context, appProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, String status) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'in progress':
        statusColor = Colors.orange;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default: // pending
        statusColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(
      BuildContext context, AppProvider appProvider) {
    return [
      const Divider(height: 1, thickness: 1),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Agree Button
            TextButton.icon(
              onPressed: () => _handleVote(context, appProvider, true),
              icon: const Icon(Icons.thumb_up_outlined, size: 20),
              label: Text(
                'Agree (${issue.agreeCount})',
                style: TextStyle(
                  color: issue.userVote == 'agree'
                      ? Theme.of(context).primaryColor
                      : null,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),

            // Disagree Button
            TextButton.icon(
              onPressed: () => _handleVote(context, appProvider, false),
              icon: const Icon(Icons.thumb_down_outlined, size: 20),
              label: Text(
                'Disagree (${issue.disagreeCount})',
                style: TextStyle(
                  color: issue.userVote == 'disagree'
                      ? Colors.red
                      : null,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),

            // Comment Button
            TextButton.icon(
              onPressed: () {
                // Navigate to issue detail screen
                if (onTap != null) onTap!();
              },
              icon: const Icon(Icons.comment_outlined, size: 20),
              label: const Text('Comment'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _handleVote(
      BuildContext context, AppProvider appProvider, bool isAgree) async {
    if (!appProvider.isAuthenticated) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to vote'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      await appProvider.voteOnIssue(issue.id, isAgree);
      // Refresh the issue data after voting
      if (onTap != null) onTap!();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit vote. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
