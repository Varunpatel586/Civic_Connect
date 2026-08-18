import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';
import 'camera_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    const Center(child: Text('Map')),
    const Center(child: Text('Upload')),
    const ProfileScreen(),
  ];

  Future<void> _onAddPressed() async {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session == null) {
      if (mounted) {
        // Show a message that the user needs to log in
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to report an issue'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Optionally navigate to auth screen
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushNamed('/auth');
        }
      }
      return;
    }
    
    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CameraScreen(),
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          'Civic Connect',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _screens[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddPressed(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add, size: 0),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              if (index != 2) {
                setState(() {
                  _selectedIndex = index;
                });
              } else {
                // Handle upload button press
                // TODO: Implement upload functionality
              }
            },
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
