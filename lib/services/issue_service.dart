import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import '../models/models.dart';

class IssueService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Issue>> getNearbyIssues({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int limit = 50,
  }) async {
    try {
      // This is a simplified query. In a real app, you'd use PostGIS for spatial queries
      final response = await _supabase
          .rpc('get_nearby_issues', params: {
            'lat': latitude,
            'lng': longitude,
            'radius_km': radiusKm,
            'max_count': limit,
          })
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((issue) => Issue.fromJson(issue as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get nearby issues error: $e');
      return [];
    }
  }

  Future<Issue?> getIssueById(String issueId) async {
    try {
      final response = await _supabase
          .from('issues')
          .select('''
            *,
            profiles!user_id (
              username,
              avatar_url,
              created_at
            )
          ''')
          .eq('id', issueId)
          .single();

      if (response == null) return null;
      
      // Format the response to match the expected structure for Issue.fromJson
      final formattedResponse = {
        ...response,
        'user': response['profiles'] ?? {
          'username': 'Unknown',
          'avatar_url': null,
        },
      };

      return Issue.fromJson(formattedResponse);
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get address from coordinates
      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address =
              '${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}';
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      final response = await _supabase
          .from('issues')
          .insert({
            'user_id': user.id,
            'title': title.trim(),
            'description': description?.trim(),
            'image_url': imageUrl,
            'latitude': latitude,
            'longitude': longitude,
            'status': 'Pending',
            if (address != null) 'address': address,
          })
          .select()
          .single();

      return Issue.fromJson(response);
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
      await _supabase
          .from('issues')
          .update({'status': status})
          .eq('id', issueId);
    } catch (e) {
      debugPrint('Update issue status error: $e');
      rethrow;
    }
  }

  Future<List<Comment>> getIssueComments(String issueId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('*, profiles!inner(username, avatar_url)')
          .eq('issue_id', issueId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((comment) => Comment.fromJson(comment as Map<String, dynamic>))
          .toList();
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('comments')
          .insert({
            'issue_id': issueId,
            'user_id': user.id,
            'content': content.trim(),
          })
          .select()
          .single();

      return Comment.fromJson(response);
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
      // First, check if user has already voted
      final existingVote = await _supabase
          .from('votes')
          .select()
          .eq('issue_id', issueId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingVote != null) {
        // Update existing vote
        await _supabase
            .from('votes')
            .update({
              'is_agree': isAgree,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingVote['id']);
        
        // Update vote counts
        await _updateVoteCounts(issueId);
        return {'success': true, 'action': 'updated'};
      } else {
        // Create new vote
        await _supabase.from('votes').insert({
          'issue_id': issueId,
          'user_id': userId,
          'is_agree': isAgree,
        });
        
        // Update vote counts
        await _updateVoteCounts(issueId);
        return {'success': true, 'action': 'added'};
      }
    } catch (e) {
      debugPrint('Vote on issue error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _updateVoteCounts(String issueId) async {
    try {
      // Get agree count
      final agreeResponse = await _supabase
          .from('votes')
          .select()
          .eq('issue_id', issueId)
          .eq('is_agree', true);
      
      final agreeCount = agreeResponse.length;

      // Get disagree count
      final disagreeResponse = await _supabase
          .from('votes')
          .select()
          .eq('issue_id', issueId)
          .eq('is_agree', false);
      
      final disagreeCount = disagreeResponse.length;

      // Update issue with new vote counts
      await _supabase
          .from('issues')
          .update({
            'agree_count': agreeCount,
            'disagree_count': disagreeCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', issueId);

      return {
        'agree_count': agreeCount,
        'disagree_count': disagreeCount,
      };
    } catch (e) {
      debugPrint('Error updating vote counts: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getVoteCounts(String issueId) async {
    try {
      final response = await _supabase.rpc('get_issue_votes', params: {
        'p_issue_id': issueId,
      });

      return {
        'agree': response['agree_count'] ?? 0,
        'disagree': response['disagree_count'] ?? 0,
      };
    } catch (e) {
      debugPrint('Get vote counts error: $e');
      return {'agree': 0, 'disagree': 0};
    }
  }

  Future<List<Issue>> getUserIssues(String userId) async {
    try {
      final response = await _supabase
          .from('issues')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((issue) => Issue.fromJson(issue as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get user issues error: $e');
      return [];
    }
  }
}
