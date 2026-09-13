import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/complaint_reference.dart';
import 'admin_console_screen.dart';
import 'camera_screen.dart';
import 'feed_screen.dart';
import 'map_screen.dart';
import 'notification_inbox_screen.dart';
import 'profile_screen.dart';

/// The citizen shell: complaints, map, and profile, with reporting on the
/// centre action.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Index 2 is the notch the floating action button sits in, so it is never
  /// selectable — see [_onDestinationSelected].
  static const int _reportSlot = 2;

  int _selectedIndex = 0;

  /// Bumped when the citizen returns from filing something. The feed keeps its
  /// own copy of the complaint list, so it needs rebuilding to pick up a new
  /// one rather than showing a list missing what was just reported.
  int _feedRevision = 0;

  Future<void> _onReportPressed() async {
    final isAuthenticated = await AuthService().isAuthenticated;
    if (!mounted) return;

    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to report an issue.')),
      );
      Navigator.of(context).pushNamed('/login');
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CameraScreen()));

    if (mounted) setState(() => _feedRevision++);
  }

  void _onDestinationSelected(int index) {
    if (index == _reportSlot) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      FeedScreen(refreshToken: _feedRevision),
      const MapScreen(),
      const SizedBox.shrink(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: const _HomeAppBar(),
      body: screens[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _onReportPressed,
        tooltip: 'Report an issue',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.slate100)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onDestinationSelected,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined),
              activeIcon: Icon(Icons.article_rounded),
              label: 'Complaints',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            // Spacer beneath the floating action button.
            BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Wordmark beside the ward the citizen is filing from.
///
/// Naming the jurisdiction is what municipal systems do — it tells the citizen
/// which body receives what they report. It sits inline with the wordmark now
/// rather than stacked beneath it in uppercase.
class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final address = context.select<AppProvider, String?>(
      (p) => p.currentAddress,
    );
    final locality = ComplaintReference.locality(address);
    final isAdmin = context.select<AppProvider, bool>((p) => p.isAdmin);

    return AppBar(
      titleSpacing: 18,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              'Civic Connect',
              style: Theme.of(context).appBarTheme.titleTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (locality != null) ...[
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                locality,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      actions: [
        const _InboxButton(),
        // Only municipal officers see a way in; the server enforces the same
        // rule, so hiding it here is convenience rather than security.
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: const Icon(Icons.account_balance_rounded, size: 21),
              tooltip: 'Municipal console',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.canvas,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminConsoleScreen()),
              ),
            ),
          ),
      ],
    );
  }
}

/// Way into the inbox, with the unread count on it.
///
/// Stateful only because the count is fetched: the app bar around it stays
/// stateless. A failed fetch shows a plain bell rather than an error — a badge
/// is never worth breaking the shell over.
class _InboxButton extends StatefulWidget {
  const _InboxButton();

  @override
  State<_InboxButton> createState() => _InboxButtonState();
}

class _InboxButtonState extends State<_InboxButton> {
  final NotificationService _service = NotificationService();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final count = await _service.getUnreadCount();
    if (mounted) setState(() => _unread = count);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 21),
            tooltip: 'Notifications',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.canvas,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
            ),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationInboxScreen(),
                ),
              );
              // Anything read while in there should drop off the badge.
              _refresh();
            },
          ),
          if (_unread > 0)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 17),
                decoration: BoxDecoration(
                  color: StatusColors.rejected.foreground,
                  borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
