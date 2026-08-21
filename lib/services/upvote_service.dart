import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class UpvoteService {
  final ApiClient _apiClient = ApiClient();

  // Toggle upvote - adds or removes an upvote
  Future<void> toggleUpvote(String issueId) async {
    try {
      final response = await _apiClient.post('/issues/$issueId/upvote', {});
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to toggle upvote');
      }
    } catch (e) {
      debugPrint('Toggle upvote error: $e');
      rethrow;
    }
  }

  // Get upvote count for an issue
  Future<int> getUpvoteCount(String issueId) async {
    try {
      final response = await _apiClient.get('/issues/$issueId/upvote/count');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Get upvote count error: $e');
      return 0;
    }
  }

  // Check if current user has upvoted an issue
  Future<bool> hasUserUpvoted(String issueId) async {
    try {
      // In our toggle upvote implementation, we can query details or just make a check
      // For simplicity, we can query the issue upvotes count or return false if guest.
      final token = await _apiClient.token;
      if (token == null) return false;
      
      // Call the toggle endpoint safely or check from server. 
      // For now, we query the upvote status. Let's return a default false or perform checks.
      return false; // Stand-in logic
    } catch (e) {
      debugPrint('Has user upvoted check error: $e');
      return false;
    }
  }

  // Stream upvote count for real-time updates (polls the REST API every 5 seconds to simulate streaming)
  Stream<int> streamUpvoteCount(String issueId) {
    StreamController<int>? controller;
    Timer? timer;

    controller = StreamController<int>(
      onListen: () {
        // Fetch immediately
        getUpvoteCount(issueId).then((count) {
          if (controller != null && !controller.isClosed) {
            controller.add(count);
          }
        });

        // Start polling
        timer = Timer.periodic(const Duration(seconds: 5), (_) async {
          final count = await getUpvoteCount(issueId);
          if (controller != null && !controller.isClosed) {
            controller.add(count);
          }
        });
      },
      onCancel: () {
        timer?.cancel();
        controller?.close();
      },
    );

    return controller.stream;
  }
}
