import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/complaint_reference.dart';
import 'admin_console_screen.dart';
import 'camera_screen.dart';
import 'feed_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

/// The citizen shell: feed, map, and profile, with reporting on the centre
/// action.
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
  /// one rather than showing a list that is missing what was just reported.
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
      FeedScreen(key: ValueKey(_feedRevision)),
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
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.slate200)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onDestinationSelected,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dynamic_feed_outlined),
              activeIcon: Icon(Icons.dynamic_feed),
              label: 'Complaints',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Map',
            ),
            // Spacer beneath the floating action button.
            BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Wordmark over the locality the citizen is currently filing from.
///
/// Naming the jurisdiction in the chrome is what municipal systems do, and it
/// tells the citizen which body will receive whatever they report.
class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final address = context.select<AppProvider, String?>(
      (p) => p.currentAddress,
    );
    final locality = ComplaintReference.locality(address);

    final isAdmin = context.select<AppProvider, bool>((p) => p.isAdmin);

    return AppBar(
      titleSpacing: 16,
      actions: [
        // Only municipal officers see a way in; the server enforces the same
        // rule, so hiding it here is convenience rather than security.
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: 'Municipal console',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminConsoleScreen()),
            ),
          ),
      ],
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Civic Connect', style: Theme.of(context).appBarTheme.titleTextStyle),
          if (locality != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                locality.toUpperCase(),
                style: AppTypography.badge(color: AppColors.navy200),
              ),
            ),
        ],
      ),
    );
  }
}
