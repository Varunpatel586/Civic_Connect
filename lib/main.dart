import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/admin_console_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/deep_link_service.dart';
import 'theme/app_theme.dart';
import 'widgets/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Client configuration only. Server secrets stay in `.env`, which is not
  // bundled — see .env.client for why.
  await dotenv.load(fileName: ".env.client");

  // Initialize Provider state asynchronously (non-blocking)
  final appProvider = AppProvider()..initialize();

  // Initialize Deep Links in background (non-blocking). A verified OAuth
  // callback refreshes the provider so the UI picks up the new session.
  final deepLinkService = DeepLinkService()
    ..onSessionEstablished = appProvider.initialize;
  deepLinkService.handleInitialUri().then((_) {
    deepLinkService.listenToDeepLinks();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => appProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civic Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/auth': (context) => const AuthScreen(),
        '/login': (context) => const AuthScreen(initialView: AuthView.login),
        '/signup': (context) => const AuthScreen(initialView: AuthView.signup),
        '/home': (context) => const HomeScreen(),
        '/console': (context) => const AdminConsoleScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Page not found')),
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
      },
    );
  }
}
