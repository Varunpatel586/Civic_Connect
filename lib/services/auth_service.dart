import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';
import '../models/user_profile.dart';

class AppAuthException implements Exception {
  final String message;
  AppAuthException(this.message);

  @override
  String toString() => 'AppAuthException: $message';
}

/// Service for handling user authentication and profile management via MongoDB REST API backend
class AuthService {
  final ApiClient _apiClient = ApiClient();

  /// Check if a user is currently authenticated
  Future<bool> get isAuthenticated async {
    final token = await _apiClient.token;
    return token != null;
  }

  /// Get the current user's profile
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final response = await _apiClient.get('/auth/profile');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile from MongoDB: $e');
      return null;
    }
  }

  /// Signs in a user with email and password
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw AppAuthException('Email and password are required');
      }

      final response = await _apiClient.post('/auth/login', {
        'email': email.trim(),
        'password': password.trim(),
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await _apiClient.setToken(token);
      } else {
        final errorData = jsonDecode(response.body);
        throw AppAuthException(errorData['message'] ?? 'Invalid email or password');
      }
    } catch (e) {
      debugPrint('Sign in error: $e');
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Failed to connect to backend server');
    }
  }

  /// Signs up a new user with email and password
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        throw AppAuthException('All fields are required');
      }

      final response = await _apiClient.post('/auth/signup', {
        'email': email.trim(),
        'password': password.trim(),
        'username': username.trim(),
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await _apiClient.setToken(token);
      } else {
        final errorData = jsonDecode(response.body);
        throw AppAuthException(errorData['message'] ?? 'Failed to create user account');
      }
    } catch (e) {
      debugPrint('Sign up error: $e');
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Failed to connect to backend server');
    }
  }

  /// Signs out the current user
  Future<void> signOut() async {
    try {
      await _apiClient.setToken(null);
    } catch (e) {
      debugPrint('Error signing out: $e');
      throw AppAuthException('Failed to sign out');
    }
  }

  /// Updates the current user's profile
  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username.trim();
      if (fullName != null) updates['fullName'] = fullName.trim();
      if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

      final response = await _apiClient.put('/auth/profile', updates);

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw AppAuthException(errorData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Failed to connect to backend server');
    }
  }

  /// Google Auth logic via MongoDB REST API backend
  Future<void> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In...');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw AppAuthException('Google sign in cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw AppAuthException('Google authentication failed: No ID token received');
      }

      final response = await _apiClient.post('/auth/google', {
        'idToken': idToken,
        'accessToken': googleAuth.accessToken,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await _apiClient.setToken(token);
      } else {
        final errorData = jsonDecode(response.body);
        throw AppAuthException(errorData['message'] ?? 'Google auth exchange failed');
      }
    } catch (e) {
      debugPrint('Google sign in error: $e');
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Failed to connect to backend server');
    }
  }

  Future<void> debugGoogleSignIn() async {
    try {
      debugPrint('=== TESTING GOOGLE SIGN-IN CLIENT ===');
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        debugPrint('Google authentication details:');
        debugPrint('- ID Token exists: ${googleAuth.idToken != null}');
        debugPrint('- Access Token exists: ${googleAuth.accessToken != null}');
      }
    } catch (e) {
      debugPrint('Test error: $e');
    }
  }
}
