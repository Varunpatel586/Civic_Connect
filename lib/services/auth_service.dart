import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuthException implements Exception {
  final String message;
  AppAuthException(this.message);

  @override
  String toString() => 'AppAuthException: $message';
}

/// Service for handling user authentication and profile management
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get the current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if a user is currently authenticated
  bool get isAuthenticated => currentUser != null;

  /// Stream of authentication state changes
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  /// Get the current user's profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    if (currentUser == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      return response;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Signs in a user with email and password
  ///
  /// Throws [AppAuthException] if sign in fails
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw AppAuthException('Email and password are required');
      }

      return await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('Sign in error: $e');
      throw AppAuthException('Invalid email or password');
    }
  }

  /// Signs up a new user with email and password
  ///
  /// Throws [AppAuthException] if signup fails
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Validate input
      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        throw AppAuthException('All fields are required');
      }

      if (username.length < 3) {
        throw AppAuthException('Username must be at least 3 characters long');
      }

      // Check if username is available
      final usernameCheck = await _supabase
          .from('profiles')
          .select('username')
          .eq('username', username.trim())
          .maybeSingle();

      if (usernameCheck != null) {
        throw AuthException('Username is already taken');
      }

      // Check if email is already registered
      final emailCheck = await _supabase
          .from('profiles')
          .select('email')
          .eq('email', email.trim())
          .maybeSingle();

      if (emailCheck != null) {
        throw AppAuthException('Email is already registered');
      }

      // Sign up the user with Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        emailRedirectTo: kIsWeb
            ? null
            : 'io.supabase.civicconnect://login-callback',
        data: {
          'username': username.trim(),
          'full_name': username.trim(), // Use username as default full name
        },
      );

      if (authResponse.user == null) {
        throw AppAuthException('Failed to create user account');
      }

      // The profile will be created by the database trigger
      // But we'll update it with the username and other details
      await _supabase
          .from('profiles')
          .update({
            'username': username.trim(),
            'email': email.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', authResponse.user!.id);

      return authResponse;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    }
  }

  /// Signs out the current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      throw AppAuthException('Failed to sign out');
    }
  }

  /// Updates the current user's profile
  ///
  /// Throws [AppAuthException] if update fails
  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      if (currentUser == null) {
        throw AppAuthException('No user is signed in');
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (username != null) {
        // Check if username is available
        final usernameCheck = await _supabase
            .from('profiles')
            .select('username')
            .eq('username', username.trim())
            .neq('id', currentUser!.id)
            .maybeSingle();

        if (usernameCheck != null) {
          throw AppAuthException('Username is already taken');
        }
        updates['username'] = username.trim();
      }

      if (fullName != null) {
        updates['full_name'] = fullName.trim();
      }

      if (avatarUrl != null) {
        updates['avatar_url'] = avatarUrl;
      }

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', currentUser!.id);
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      throw AppAuthException('Failed to update profile');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In...');

      // Initialize Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Use Google Sign-In package directly
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      // NULL SAFETY CHECK: Ensure we have an ID token
      if (idToken == null) {
        throw Exception('Google authentication failed: No ID token received');
      }

      // Direct token exchange - no redirect URIs needed!
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken!, // Using ! because we checked for null above
        accessToken: googleAuth.accessToken,
      );

      // NULL SAFETY CHECK: Ensure we have a user
      if (response.user == null) {
        throw Exception('Supabase authentication failed: No user returned');
      }

      final user = response.user!;
      debugPrint(
        'Successfully signed in with Google: ${user.email ?? "No email"}',
      );

      // Check if profile exists, if not create one
      try {
        await _supabase.from('profiles').select().eq('id', user.id).single();
      } catch (e) {
        if (e.toString().contains('No rows returned')) {
          // NULL SAFETY: Handle potential null email
          final String username =
              user.email?.split('@').first ?? 'user_${user.id.substring(0, 8)}';

          await _supabase.from('profiles').upsert({
            'id': user.id,
            'email': user.email ?? '', // Handle null email
            'username': username,
            'role_id': 1,
            'created_at': DateTime.now().toIso8601String(),
          });
        } else {
          debugPrint('Error checking profile: $e');
          // Don't rethrow - auth was successful even if profile creation failed
        }
      }
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      rethrow;
    }
  }

  Future<void> debugGoogleSignIn() async {
    try {
      debugPrint('=== TESTING SERVER CLIENT ID ===');

      // Test with web client ID
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId:
            '185655557777-urupuri@dzhijumf0gakfgjsm75yjb2x.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        debugPrint('Web Client ID Result:');
        debugPrint(
          '- ID Token: ${googleAuth.idToken != null ? "✅ SUCCESS" : "❌ FAILED"}',
        );
        debugPrint(
          '- Access Token: ${googleAuth.accessToken != null ? "✅ SUCCESS" : "❌ FAILED"}',
        );

        if (googleAuth.idToken != null) {
          debugPrint('Token length: ${googleAuth.idToken!.length} characters');
        }
      }
    } catch (e) {
      debugPrint('Test error: $e');
    }
  }

  // Future<void> updateProfile({String? username, String? avatarUrl}) async {
  //   try {
  //     if (currentUser == null) {
  //       throw Exception('User not authenticated');
  //     }
  //
  //     final updates = <String, dynamic>{};
  //     if (username != null) updates['username'] = username.trim();
  //     if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
  //
  //     if (updates.isNotEmpty) {
  //       await _supabase
  //           .from('profiles')
  //           .update(updates)
  //           .eq('id', currentUser!.id);
  //     }
  //   } catch (e) {
  //     debugPrint('Update profile error: $e');
  //     rethrow;
  //   }
  // }
  //
  // Future<UserProfile?> getCurrentUserProfile() async {
  //   try {
  //     if (currentUser == null) return null;
  //
  //     try {
  //       // Try to get the profile
  //       final response = await _supabase
  //           .from('profiles')
  //           .select('*, roles(name)')
  //           .eq('id', currentUser!.id)
  //           .single();
  //
  //       return UserProfile(
  //         id: response['id'],
  //         username: response['username'],
  //         email: response['email'],
  //         role: response['roles']?['name'] ?? 'user',
  //         avatarUrl: response['avatar_url'],
  //         createdAt: response['created_at'] != null
  //             ? DateTime.parse(response['created_at'])
  //             : DateTime.now(),
  //       );
  //     } catch (e) {
  //       // If profile doesn't exist, create one
  //       if (e.toString().contains('No rows returned')) {
  //         debugPrint('Profile not found, creating default profile...');
  //         await _supabase.from('profiles').upsert({
  //           'id': currentUser!.id,
  //           'email': currentUser!.email,
  //           'username':
  //               currentUser!.email?.split('@').first ??
  //               'user_${currentUser!.id.substring(0, 8)}',
  //           'role_id': 1,
  //         });
  //
  //         // Try getting the profile again
  //         return getCurrentUserProfile();
  //       }
  //       rethrow;
  //     }
  //   } catch (e) {
  //     debugPrint('Error in getCurrentUserProfile: $e');
  //     return null;
  //   }
  // }
}
