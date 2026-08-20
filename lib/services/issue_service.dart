import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'api_client.dart';
import '../models/models.dart';
import '../utils/issue_categories.dart';

class IssueService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Issue>> getNearbyIssues({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.get(
        '/issues/nearby?lat=$latitude&lng=$longitude&radius_km=$radiusKm&limit=$limit',
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((issue) => Issue.fromJson(issue as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get nearby issues error: $e');
      return [];
    }
  }

  Future<Issue?> getIssueById(String issueId) async {
    try {
      final response = await _apiClient.get('/issues/$issueId');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Issue.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Get issue by id error: $e');
      return null;
    }
  }

  /// Files a new complaint.
  ///
  /// The category is passed in rather than guessed from the title: the
  /// submission form already asked the citizen directly, and keyword-sniffing a
  /// title silently misfiled anything phrased unusually.
  Future<Issue> createIssue({
    required String category,
    required String description,
    required List<String> imageUrls,
    required double latitude,
    required double longitude,
    String? address,
    String? title,
  }) async {
    if (imageUrls.isEmpty) {
      throw ArgumentError('A complaint needs at least one photograph');
    }

    // Resolve an address if the caller did not already have one. Best-effort:
    // the coordinates are what the municipality dispatches on.
    var resolved = address;
    if (resolved == null || resolved.trim().isEmpty) {
      try {
        final placemarks = await placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          resolved =
              '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
        }
      } catch (e) {
        debugPrint('Could not reverse geocode: $e');
      }
    }

    try {
      final response = await _apiClient.post('/issues', {
        'title': (title?.trim().isNotEmpty ?? false)
            ? title!.trim()
            : IssueCategories.labelFor(category),
        'description': description.trim(),
        'category': category,
        'imageUrl': imageUrls.first,
        'imageUrls': imageUrls,
        'latitude': latitude,
        'longitude': longitude,
        if (resolved != null) 'address': resolved,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        // The create endpoint returns the raw Mongoose document, so the id and
        // owner arrive under their camelCase names rather than the wire format.
        return Issue.fromJson({
          ...data,
          'id': data['_id'] ?? data['id'],
          'user_id': data['userId'] ?? data['user_id'],
        });
      }
      throw Exception(
        _apiClient.errorMessage(response, 'Server rejected the complaint'),
      );
    } catch (e) {
      debugPrint('Create issue error: $e');
      rethrow;
    }
  }

  Future<void> updateIssueStatus({
    required String issueId,
    required String status,
  }) async {
    try {
      final response = await _apiClient.patch('/issues/$issueId/status', {
        'status': status,
      });

      if (response.statusCode != 200) {
        throw Exception(
          _apiClient.errorMessage(response, 'Could not update the status'),
        );
      }
    } catch (e) {
      debugPrint('Update issue status error: $e');
      rethrow;
    }
  }

  Future<List<Comment>> getIssueComments(String issueId) async {
    try {
      final response = await _apiClient.get('/comments/issue/$issueId');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((comment) => Comment.fromJson(comment as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get comments error: $e');
      return [];
    }
  }

  Future<Comment> addComment({
    required String issueId,
    required String content,
  }) async {
    try {
      final response = await _apiClient.post('/comments/issue/$issueId', {
        'content': content,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Comment.fromJson(data);
      } else {
        throw Exception('Failed to post comment: ${response.body}');
      }
    } catch (e) {
      debugPrint('Add comment error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> voteOnIssue({
    required String issueId,
    required String userId,
    required bool isAgree,
  }) async {
    try {
      final response = await _apiClient.post('/issues/$issueId/vote', {
        'isAgree': isAgree,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': true,
          'action': 'voted',
          'agree_count': data['agreeCount'],
          'disagree_count': data['disagreeCount'],
        };
      } else {
        throw Exception(_apiClient.errorMessage(response, 'Vote did not register'));
      }
    } catch (e) {
      debugPrint('Vote on issue error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getVoteCounts(String issueId) async {
    try {
      final response = await _apiClient.get('/issues/$issueId');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'agree': data['agree_count'] ?? 0,
          'disagree': data['disagree_count'] ?? 0,
        };
      }
      return {'agree': 0, 'disagree': 0};
    } catch (e) {
      debugPrint('Get vote counts error: $e');
      return {'agree': 0, 'disagree': 0};
    }
  }

  Future<List<Issue>> getUserIssues(String userId) async {
    try {
      final response = await _apiClient.get('/issues/user');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((issue) => Issue.fromJson(issue as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get user issues error: $e');
      return [];
    }
  }
}
