import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'api_client.dart';
import '../models/models.dart';

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

  Future<Issue> createIssue({
    required String title,
    required String? description,
    required String imageUrl,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Get address from coordinates
      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address = '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      // Map categories from title or default to 'other'
      String category = 'other';
      final lowerTitle = title.toLowerCase();
      if (lowerTitle.contains('pothole')) category = 'pothole';
      else if (lowerTitle.contains('light')) category = 'street_light';
      else if (lowerTitle.contains('water')) category = 'water';
      else if (lowerTitle.contains('electricity') || lowerTitle.contains('power')) category = 'electricity';
      else if (lowerTitle.contains('garbage') || lowerTitle.contains('trash')) category = 'garbage';
      else if (lowerTitle.contains('road')) category = 'road';
      else if (lowerTitle.contains('drain')) category = 'drainage';

      final response = await _apiClient.post('/issues', {
        'title': title.trim(),
        'description': description?.trim() ?? '',
        'category': category,
        'imageUrl': imageUrl,
        'imageUrls': [imageUrl],
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Ensure standard fields map back correctly
        final formatted = {
          ...data,
          'id': data['_id'] ?? data['id'],
          'user_id': data['userId'] ?? data['user_id'],
        };
        return Issue.fromJson(formatted);
      } else {
        throw Exception('Failed to create issue: ${response.body}');
      }
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
        throw Exception('Failed to update issue status: ${response.body}');
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
        final errorData = jsonDecode(response.body);
        return {'success': false, 'error': errorData['message'] ?? 'Voting failed'};
      }
    } catch (e) {
      debugPrint('Vote on issue error: $e');
      return {'success': false, 'error': e.toString()};
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
