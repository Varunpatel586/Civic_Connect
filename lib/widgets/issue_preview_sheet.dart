import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/models.dart';
import '../screens/issue_detail_screen.dart';
import '../services/api_client.dart';

/// Shows a modal bottom sheet preview for a map issue marker tap.
void showIssuePreviewSheet(BuildContext context, MapIssue issue) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => IssuePreviewSheet(issue: issue),
  );
}

void showClusterIssueSheet(BuildContext context, List<MapIssue> issues) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ClusterIssueSheet(issues: issues, rootContext: context),
  );
}

class ClusterIssueSheet extends StatelessWidget {
  final List<MapIssue> issues;
  final BuildContext rootContext;

  const ClusterIssueSheet({
    super.key,
    required this.issues,
    required this.rootContext,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${issues.length} issues in this area',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: issues.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final issue = issues[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: _issueThumbnail(issue),
                    title: Text(
                      issue.title.isEmpty ? 'Untitled issue' : issue.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${issue.category.replaceAll('_', ' ')} • ${issue.status}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      Future<void>.microtask(() {
                        if (rootContext.mounted) {
                          showIssuePreviewSheet(rootContext, issue);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _issueThumbnail(MapIssue issue) {
    final imageUrl = ApiClient().normalizeUrl(issue.imageUrl);
    if (imageUrl.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.report_problem_outlined));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      ),
    );
  }
}

class IssuePreviewSheet extends StatelessWidget {
  final MapIssue issue;

  const IssuePreviewSheet({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedUrl = ApiClient().normalizeUrl(issue.imageUrl);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Issue image
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: normalizedUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Issue info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        issue.title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

                // Category chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _categoryColor(issue.category).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _categoryLabel(issue.category),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _categoryColor(issue.category),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Address + time row
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        issue.address ?? 'Unknown location',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      timeago.format(issue.createdAt),
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // "View Full Report" button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // close sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IssueDetailScreen(issueId: issue.id),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'View Full Report',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, String status) {
    final statusColor = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: statusColor,
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default: // pending
        return Colors.blue;
    }
  }

  static Color _categoryColor(String category) {
    switch (category) {
      case 'pothole':
        return Colors.brown;
      case 'street_light':
        return Colors.amber.shade700;
      case 'water':
        return Colors.blue;
      case 'electricity':
        return Colors.yellow.shade800;
      case 'garbage':
        return Colors.green.shade700;
      case 'road':
        return Colors.grey.shade700;
      case 'drainage':
        return Colors.teal;
      default:
        return Colors.purple;
    }
  }

  static String _categoryLabel(String category) {
    return category.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }
}
