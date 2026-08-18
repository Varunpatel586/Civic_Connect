import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../providers/app_provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    if (appProvider.isLoading && !appProvider.isAuthenticated) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!appProvider.isAuthenticated) {
      return const AuthScreen();
    }

    return const HomeScreen();
  }
}
