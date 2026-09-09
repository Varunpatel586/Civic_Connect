import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'issue_detail_screen.dart';

/// Everything the municipality has told this citizen.
///
/// This list is the delivery guarantee. Push can be dropped by the network, a
/// rotated token or a reinstall; the inbox cannot, because the server writes
/// here before it pushes. A complaint's whole history of contact therefore
/// survives a phone that was switched off for a week.
class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  final NotificationService _service = NotificationService();

  List<AppNotification> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.getInbox();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    // Painted immediately: clearing the badge is the whole point of the tap,
    // and waiting for a round trip would make it lag behind the finger.
    setState(() {
      _items = _items.map((n) => n.copyWith(read: true)).toList();
    });
    await _service.markAllRead();
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.read) {
      setState(() {
        _items = _items
            .map((n) => n.id == notification.id ? n.copyWith(read: true) : n)
            .toList();
      });
      await _service.markRead(notification.id);
    }

    final issueId = notification.issueId;
    if (issueId == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IssueDetailScreen(issueId: issueId)),
    );

    // The complaint may have been answered while we were away, which changes
    // what this screen should show.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: AppTypography.meta(color: AppColors.navy700),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty ? const _EmptyInbox() : _list(),
            ),
    );
  }

  Widget _list() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _NotificationRow(
        notification: _items[i],
        onTap: () => _open(_items[i]),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    // Scrollable, so pull-to-refresh still works with nothing in the list.
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.notifications_none,
          size: 44,
          color: AppColors.slate400,
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Nothing yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'You will hear from your ward office here.',
            style: AppTypography.meta(),
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationRow({required this.notification, required this.onTap});

  /// A leading glyph per message type, so the list is scannable without
  /// reading every title.
  (IconData, Color) get _glyph {
    switch (notification.type) {
      case 'verification_requested':
        return (Icons.help_outline, StatusColors.inProgress.foreground);
      case 'verification_disputed':
        return (Icons.replay, StatusColors.rejected.foreground);
      case 'verification_confirmed':
        return (Icons.check_circle_outline, StatusColors.resolved.foreground);
      case 'escalated':
        return (Icons.priority_high, StatusColors.overdue.foreground);
      default:
        return (Icons.campaign_outlined, AppColors.navy700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = _glyph;
    final unread = !notification.read;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            // Only a message still waiting on an answer carries a rule. Read
            // ones recede, so the list reads as a queue rather than a wall.
            border: notification.needsAnswer && unread
                ? Border.all(color: StatusColors.inProgress.border)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: tint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w500,
                            color:
                                unread ? AppColors.navy900 : AppColors.slate600,
                          ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: AppTypography.meta(color: AppColors.slate600),
                      ),
                    ],
                    if (notification.reference.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notification.reference,
                        style: AppTypography.recordId(),
                      ),
                    ],
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.navy700,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
