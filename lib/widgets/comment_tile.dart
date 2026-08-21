import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/models.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// One entry in a complaint's discussion.
class CommentTile extends StatelessWidget {
  final Comment comment;

  const CommentTile({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = comment.user;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(user: user),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.username.isEmpty ? 'Anonymous' : user.username,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt),
                      style: AppTypography.meta(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A circle, because a person is the one thing in a register that is not a
/// record. Falls back to the initial when there is no picture.
class _Avatar extends StatelessWidget {
  final UserProfile user;

  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final initial = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : '?';

    return Container(
      width: 34,
      height: 34,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.slate100,
        shape: BoxShape.circle,
      ),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Center(
              child: Text(
                initial,
                style: AppTypography.recordId(
                  color: AppColors.navy700,
                ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            )
          : CachedNetworkImage(
              imageUrl: ApiClient().normalizeUrl(avatarUrl),
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Center(
                child: Text(
                  initial,
                  style: AppTypography.recordId(
                    color: AppColors.navy700,
                  ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
    );
  }
}
