import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../utils/complaint_reference.dart';
import 'camera_screen.dart';
import 'feed_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'notification_inbox_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _feedRevision = 0;

  Future<void> _onReportPressed() async {
    final isAuthenticated = await AuthService().isAuthenticated;

    if (!mounted) return;

    if (!isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to report an issue.'),
        ),
      );

      Navigator.of(context).pushNamed('/login');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CameraScreen(),
      ),
    );

    if (mounted) {
      setState(() {
        _feedRevision++;
      });
    }
  }

  void _onNavigationTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final address = context.select<AppProvider, String?>(
      (p) => p.currentAddress,
    );

    final locality =
        ComplaintReference.locality(address) ?? 'Uday Nagar';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),

      body: SafeArea(
        child: Column(
          children: [
            // ------------------------------------------------------------
            // HEADER
            // ------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 22, 24, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Hi Citizen',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF777D7D),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  // Notification bell
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationInboxScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications_rounded,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            // ------------------------------------------------------------
            // MAIN CONTENT
            // ------------------------------------------------------------
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  FeedScreen(
                    key: ValueKey(_feedRevision),
                  ),
                  const MapScreen(),
                  const SizedBox(),
                  const ProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),

      // --------------------------------------------------------------
      // CUSTOM BOTTOM NAVIGATION
      // --------------------------------------------------------------
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 78,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main black navigation pill
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  height: 58,
                  width: 145,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navIcon(
                        icon: Icons.home_rounded,
                        index: 0,
                      ),
                      _navIcon(
                        icon: Icons.map_outlined,
                        index: 1,
                      ),
                      _navIcon(
                        icon: Icons.person_outline_rounded,
                        index: 3,
                      ),
                    ],
                  ),
                ),
              ),

              // Location
              Positioned(
                bottom: 17,
                left: 148,
                right: 58,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: Color(0xFF777D7D),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        locality,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF777D7D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ----------------------------------------------------------
              // PLUS BUTTON
              // ----------------------------------------------------------
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _onReportPressed,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon({
    required IconData icon,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onNavigationTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 23,
          color: isSelected
              ? Colors.black
              : const Color(0xFF777777),
        ),
      ),
    );
  }
}