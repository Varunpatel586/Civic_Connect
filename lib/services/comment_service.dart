import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/comment.dart';

class CommentService {
  final ApiClient _apiClient = ApiClient();

  /// Fetches all comments for a specific issue
  Future<List<Comment>> getCommentsByIssueId(String issueId) async {
    try {
      debugPrint('Fetching comments for issue via MongoDB REST: $issueId');

      final response = await _apiClient.get('/comments/issue/$issueId');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((comment) => Comment.fromJson(comment as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Get comments error: $e');
      rethrow;
    }
  }

  /// Fetches all comments by the current user
  Future<List<Map<String, dynamic>>> getUserComments() async {
    try {
      final response = await _apiClient.get('/comments/user');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      debugPrint('Get user comments error: $e');
      return [];
    }
  }

  /// Adds a new comment to an issue
  Future<Comment> addComment({
    required String issueId,
    required String content,
  }) async {
    try {
      debugPrint('Adding comment to issue via MongoDB REST: $issueId');

      final response = await _apiClient.post('/comments/issue/$issueId', {
        'content': content,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Comment.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to post comment');
      }
    } catch (e) {
      debugPrint('Add comment error: $e');
      rethrow;
    }
  }

  /// Updates an existing comment
  Future<Comment> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final response = await _apiClient.put('/comments/$commentId', {
        'content': content,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Comment.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update comment');
      }
    } catch (e) {
      debugPrint('Update comment error: $e');
      rethrow;
    }
  }

  /// Deletes a comment
  Future<void> deleteComment(String commentId) async {
    try {
      final response = await _apiClient.delete('/comments/$commentId');
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete comment');
      }
    } catch (e) {
      debugPrint('Delete comment error: $e');
      rethrow;
    }
  }

  /// Get a single comment by ID
  Future<Comment?> getCommentById(String commentId) async {
    try {
      final response = await _apiClient.get('/comments/$commentId');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return Comment.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Get comment by id error: $e');
      return null;
    }
  }
}
