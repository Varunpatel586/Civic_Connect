import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart' show UserProfile, Issue, Comment;
import '../services/auth_service.dart';
import '../services/comment_service.dart';
import '../services/issue_service.dart';
import '../services/location_service.dart';

class AppProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final IssueService _issueService = IssueService();
  final LocationService _locationService = LocationService();

  UserProfile? _currentUser;
  bool _isLoading = false;
  Position? _currentPosition;
  String? _currentAddress;
  List<Issue> _nearbyIssues = [];
  List<Issue> _userIssues = [];

  // Getters
  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role.toLowerCase() == 'admin';
  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  List<Issue> get nearbyIssues => _nearbyIssues;
  List<Issue> get userIssues => _userIssues;

  // Initialize app state
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Check if user is already logged in
      await _checkCurrentUser();

      // Location is best-effort during startup. If it fails or times out the
      // app still opens — it just opens without a position, and the feed
      // defaults to showing every ward.
      try {
        await _getCurrentLocation();
      } catch (e) {
        debugPrint('Startup continuing without a location: $e');
      }

      // Load nearby issues if location is available
      if (_currentPosition != null) {
        await _loadNearbyIssues();
      }

      // Load user's issues if authenticated
      if (isAuthenticated) {
        await _loadUserIssues();
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Authentication methods
  Future<UserProfile?> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.signInWithEmail(email: email, password: password);
      await _checkCurrentUser();
      if (isAuthenticated) {
        await _loadUserIssues();
      }
      return _currentUser;
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserProfile?> signUp(
    String email,
    String password,
    String username,
  ) async {
    _setLoading(true);
    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        username: username,
      );
      await _checkCurrentUser();
      return _currentUser;
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserProfile?> signInWithGoogle() async {
    _setLoading(true);
    try {
      await _authService.signInWithGoogle();
      await _checkCurrentUser();
      if (isAuthenticated) {
        await _loadUserIssues();
      }
      return _currentUser;
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
      _userIssues = [];
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Issue methods

  /// Files a complaint and refreshes what the app is showing.
  ///
  /// Refreshing here is the point: without it a citizen returns from reporting
  /// to a feed that does not contain the complaint they just filed.
  Future<void> reportIssue({
    required String category,
    required String description,
    required List<String> imageUrls,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    _setLoading(true);
    try {
      await _issueService.createIssue(
        category: category,
        description: description,
        imageUrls: imageUrls,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      await _loadNearbyIssues();
      if (isAuthenticated) {
        await _loadUserIssues();
      }
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Location methods
  Future<void> refreshLocation() async {
    _setLoading(true);
    try {
      await _getCurrentLocation();
      if (_currentPosition != null) {
        await _loadNearbyIssues();
      }
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  Future<void> _checkCurrentUser() async {
    _currentUser = await _authService.getCurrentUserProfile();
    notifyListeners();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      _currentPosition = position;

      // Get address from coordinates
      _currentAddress = await _locationService.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error getting current location: $e');
      rethrow;
    }
  }

  Future<void> _loadNearbyIssues() async {
    if (_currentPosition == null) return;

    try {
      _nearbyIssues = await _issueService.getNearbyIssues(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading nearby issues: $e');
      rethrow;
    }
  }

  Future<void> _loadUserIssues() async {
    if (_currentUser == null) return;

    try {
      _userIssues = await _issueService.getUserIssues(_currentUser!.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user issues: $e');
      rethrow;
    }
  }

  // Get issue by ID
  Future<Issue> getIssueById(String issueId) async {
    try {
      final response = await _issueService.getIssueById(issueId);
      if (response == null) {
        throw Exception('Issue not found');
      }
      return response;
    } catch (e) {
      debugPrint('Error getting issue: $e');
      rethrow;
    }
  }

  // Get comments for an issue
  Future<List<Comment>> getIssueComments(String issueId) async {
    try {
      return await _issueService.getIssueComments(issueId);
    } catch (e) {
      debugPrint('Error getting comments: $e');
      rethrow;
    }
  }

  // Vote on an issue
  Future<void> voteOnIssue(String issueId, bool isAgree) async {
    if (_currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _issueService.voteOnIssue(
        issueId: issueId,
        userId: _currentUser!.id,
        isAgree: isAgree,
      );
    } catch (e) {
      debugPrint('Error voting on issue: $e');
      rethrow;
    }
  }

  // Update issue status (admin only)
  Future<void> updateIssueStatus({
    required String issueId,
    required String status,
  }) async {
    try {
      await _issueService.updateIssueStatus(issueId: issueId, status: status);
      await _loadIssueWithComments(issueId);
    } catch (e) {
      debugPrint('Error updating issue status: $e');
      rethrow;
    }
  }

  // Map to store comments for each issue
  final Map<String, List<Comment>> _issueComments = {};

  /// Get comments for a specific issue
  List<Comment> getCommentsForIssue(String issueId) {
    return _issueComments[issueId] ?? [];
  }

  /// Load or refresh comments for a specific issue
  Future<void> loadCommentsForIssue(String issueId) async {
    try {
      final comments = await _issueService.getIssueComments(issueId);
      _issueComments[issueId] = comments;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading comments: $e');
      rethrow;
    }
  }

  /// Add a comment to an issue
  Future<void> addComment(String issueId, String content) async {
    try {
      final commentService = CommentService();
      await commentService.addComment(issueId: issueId, content: content);
      await loadCommentsForIssue(issueId);
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  Future<void> _loadIssueWithComments(String issueId) async {
    try {
      final updatedIssue = await _issueService.getIssueById(issueId);

      if (updatedIssue != null) {
        final nearbyIndex = _nearbyIssues.indexWhere(
          (issue) => issue.id == issueId,
        );
        if (nearbyIndex != -1) _nearbyIssues[nearbyIndex] = updatedIssue;

        final userIssueIndex = _userIssues.indexWhere(
          (issue) => issue.id == issueId,
        );
        if (userIssueIndex != -1) _userIssues[userIssueIndex] = updatedIssue;
      }
      await loadCommentsForIssue(issueId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating issue with comments: $e');
      rethrow;
    }
  }

  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }
}
