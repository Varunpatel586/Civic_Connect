import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:civic_connect/screens/auth_screen.dart';
import 'package:civic_connect/screens/home_screen.dart';
import 'package:civic_connect/services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Handle deep links for OAuth
  if (!kIsWeb) {
    final appLinks = AppLinks();
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      await Supabase.instance.client.auth.getSessionFromUrl(initialLink);
    }

    // Listen for links when the app is in the foreground
    appLinks.uriLinkStream.listen((uri) async {
      if (uri.toString().contains('access_token')) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civic Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthScreen(),
        '/login': (context) => const AuthScreen(initialView: AuthView.login),
        '/signup': (context) => const AuthScreen(initialView: AuthView.signup),
        '/home': (context) => const HomeScreen(),
      },
      onUnknownRoute: (settings) {
        // Handle unknown routes (404)
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

//Login Screen
class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Navigate to home screen
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on AppAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e, st) {
      debugPrint('Sign in with email failed: $e');
      debugPrintStack(stackTrace: st);
      setState(() {
        _errorMessage = e.toString(); // Or show a user-friendly version
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //Sign in with google logic
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      // await authService.signInWithGoogle();
      await authService
          .debugGoogleSignIn(); //Remove once google login works and uncomment signInWithGoogle

      // If sign in is successful, navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on AppAuthException catch (e) {
      setState(() {
        _errorMessage = 'Error signing in with Google: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSignUp() {
    Navigator.of(context).pushNamed('/signup');
  }

  //login & signin screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Header
              Text(
                'Welcome Back!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Sign in to continue',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Please enter your email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Please enter your password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sign in button
              ElevatedButton(
                onPressed: _isLoading ? null : _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: _navigateToSignUp,
                    child: Text(
                      'Sign up',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              // OR divider
              _buildDivider(),
              const SizedBox(height: 30),

              // Google sign in button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: const Icon(
                  Icons.g_mobiledata,
                  size: 20,
                  color: Colors.green,
                ),
                label: Text(
                  'Continue with Google',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //OR Divider
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
      ],
    );
  }
}
