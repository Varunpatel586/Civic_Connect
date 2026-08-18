import 'package:supabase_flutter/supabase_flutter.dart';

class UpvoteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Toggle upvote - adds or removes an upvote
  Future<void> toggleUpvote(String issueId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Check if user already upvoted
    final existingVote = await _supabase
        .from('issue_upvotes')
        .select()
        .eq('issue_id', issueId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existingVote != null) {
      // Remove upvote
      await _supabase
          .from('issue_upvotes')
          .delete()
          .eq('issue_id', issueId)
          .eq('user_id', userId);
    } else {
      // Add upvote
      await _supabase.from('issue_upvotes').insert({
        'issue_id': issueId,
        'user_id': userId,
      });
    }
  }

  // Get upvote count for an issue
  Future<int> getUpvoteCount(String issueId) async {
    final response = await _supabase.rpc(
      'get_issue_upvotes',
      params: {'issue_uuid': issueId},
    );
    return response as int;
  }

  // Check if current user has upvoted an issue
  Future<bool> hasUserUpvoted(String issueId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _supabase
        .from('issue_upvotes')
        .select()
        .eq('issue_id', issueId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  // Stream upvote count for real-time updates
  Stream<int> streamUpvoteCount(String issueId) {
    return _supabase
        .from('issue_upvotes')
        .stream(primaryKey: ['id'])
        .eq('issue_id', issueId)
        .map((items) => items.length);
  }
}
