import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comment.dart';
import '../models/user_profile.dart';

class CommentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches all comments for a specific issue
  Future<List<Comment>> getCommentsByIssueId(String issueId) async {
    try {
      debugPrint('Fetching comments for issue: $issueId');

      final response = await _supabase
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              id,
              username,
              avatar_url,
              created_at
            )
          ''')
          .eq('issue_id', issueId)
          .order('created_at', ascending: false);

      if (response == null) {
        debugPrint('No comments found for issue: $issueId');
        return [];
      }

      debugPrint('Retrieved ${response.length} comments for issue: $issueId');

      final comments = (response as List)
          .map((comment) {
            try {
              return Comment.fromJson({
                'id': comment['id'].toString(),
                'issue_id': comment['issue_id'],
                'user_id': comment['user_id'],
                'content': comment['content'],
                'created_at': comment['created_at'],
                'user': {
                  'id': comment['user_id'],
                  'username': comment['profiles']?['username'] ?? 'Unknown',
                  'email': '',
                  'role': 'user',
                  'avatar_url': comment['profiles']?['avatar_url'],
                  'created_at':
                      comment['profiles']?['created_at'] ??
                      comment['created_at'],
                },
              });
            } catch (e) {
              debugPrint('Error parsing comment: $e');
              return null;
            }
          })
          .whereType<Comment>()
          .toList();

      return comments;
    } catch (e) {
      debugPrint('Get comments error: $e');
      rethrow;
    }
  }

  /// Adds a new comment to an issue
  Future<Comment> addComment({
    required String issueId,
    required String content,
  }) async {
    try {
      debugPrint('Adding comment to issue: $issueId');

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final trimmedContent = content.trim();
      if (trimmedContent.isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      debugPrint('Inserting comment into database...');
      // Insert comment and fetch the created comment with user profile in a single query
      final response = await _supabase
          .from('comments')
          .insert({
            'issue_id': issueId,
            'user_id': user.id,
            'content': trimmedContent,
          })
          .select('''
            *,
            profiles:user_id (
              id,
              username,
              avatar_url,
              created_at
            )
          ''')
          .single();

      debugPrint('Successfully added comment with ID: ${response['id']}');

      return Comment.fromJson({
        'id': response['id'].toString(),
        'issue_id': response['issue_id'],
        'user_id': response['user_id'],
        'content': response['content'],
        'created_at': response['created_at'],
        'user': {
          'id': response['user_id'],
          'username': response['profiles']?['username'] ?? 'Unknown',
          'email': '',
          'role': 'user',
          'avatar_url': response['profiles']?['avatar_url'],
          'created_at':
              response['profiles']?['created_at'] ?? response['created_at'],
        },
      });
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
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      if (content.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      // First verify the comment exists and belongs to the user
      final existingComment = await _supabase
          .from('comments')
          .select('user_id')
          .eq('id', int.parse(commentId))
          .single();

      if (existingComment['user_id'] != user.id) {
        throw Exception('You can only edit your own comments');
      }

      // Update the comment
      await _supabase
          .from('comments')
          .update({'content': content.trim()})
          .eq('id', int.parse(commentId));

      // Fetch the updated comment with user profile
      final updatedComment = await _supabase
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              email,
              role,
              created_at
            )
          ''')
          .eq('id', int.parse(commentId))
          .single();

      return Comment.fromJson({
        'id': updatedComment['id'].toString(),
        'issue_id': updatedComment['issue_id'],
        'user_id': updatedComment['user_id'],
        'content': updatedComment['content'],
        'created_at': updatedComment['created_at'],
        'user': UserProfile.fromJson(updatedComment['profiles']),
      });
    } catch (e) {
      debugPrint('Update comment error: $e');
      rethrow;
    }
  }

  /// Deletes a comment
  Future<void> deleteComment(String commentId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // First verify the comment exists and belongs to the user
      final existingComment = await _supabase
          .from('comments')
          .select('user_id')
          .eq('id', int.parse(commentId))
          .single();

      if (existingComment['user_id'] != user.id) {
        throw Exception('You can only delete your own comments');
      }

      await _supabase.from('comments').delete().eq('id', int.parse(commentId));
    } catch (e) {
      debugPrint('Delete comment error: $e');
      rethrow;
    }
  }

  /// Get a single comment by ID
  Future<Comment?> getCommentById(String commentId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('id', int.parse(commentId))
          .single();

      return Comment.fromJson({
        'id': response['id'].toString(),
        'issue_id': response['issue_id'],
        'user_id': response['user_id'],
        'content': response['content'],
        'created_at': response['created_at'],
        'user': {
          'id': response['user_id'],
          'username': response['profiles']?['username'] ?? 'Unknown',
          'email': '',
          'role': 'user',
          'avatar_url': response['profiles']?['avatar_url'],
          'created_at': response['created_at'],
        },
      });
    } catch (e) {
      debugPrint('Get comment by id error: $e');
      return null;
    }
  }
}
