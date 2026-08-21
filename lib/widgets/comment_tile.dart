import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;

  const CommentTile({
    super.key,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = comment.user;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.primaryColor.withOpacity(0.1),
            backgroundImage: user?.avatarUrl != null
                ? CachedNetworkImageProvider(user!.avatarUrl!)
                : null,
            child: user?.avatarUrl == null
                ? Text(
                    user?.username.isNotEmpty ?? false
                        ? user!.username[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.poppins(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and Time
                Row(
                  children: [
                    Text(
                      user?.username ?? 'Anonymous',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Comment Text
                Text(
                  comment.content,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
