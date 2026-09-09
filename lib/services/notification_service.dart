import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/app_notification.dart';

/// The citizen's and officer's inbox.
///
/// The server writes every message to the database before it attempts a push,
/// so this list — not FCM — is what the app trusts. A device that was offline,
/// reinstalled, or never registered for push still sees everything here.
class NotificationService {
  final ApiClient _apiClient = ApiClient();

  /// Newest first. [unreadOnly] backs the badge-clearing view.
  Future<List<AppNotification>> getInbox({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _apiClient.get(
        '/notifications?limit=$limit${unreadOnly ? '&unread_only=true' : ''}',
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data
            .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
            .toList();
      }
      return const [];
    } catch (e) {
      debugPrint('Get inbox error: $e');
      return const [];
    }
  }

  /// Badge count. Returns 0 rather than throwing, because a failed badge must
  /// never be the reason a screen fails to build.
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.get('/notifications/unread-count');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return (data['count'] as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Unread count error: $e');
      return 0;
    }
  }

  Future<bool> markRead(String notificationId) async {
    try {
      final response = await _apiClient.patch(
        '/notifications/$notificationId/read',
        const {},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Mark read error: $e');
      return false;
    }
  }

  Future<bool> markAllRead() async {
    try {
      final response = await _apiClient.post(
        '/notifications/read-all',
        const {},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Mark all read error: $e');
      return false;
    }
  }

  /// Registers this handset for push.
  ///
  /// Safe to call on every launch: the server stores tokens as a set, and FCM
  /// hands out a fresh token after a reinstall or a data clear.
  Future<bool> registerDevice(String token) async {
    if (token.isEmpty) return false;
    try {
      final response = await _apiClient.post('/notifications/device-token', {
        'token': token,
      });
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Register device error: $e');
      return false;
    }
  }

  /// Unregisters on sign-out, so the next account on this handset does not
  /// inherit the previous one's pushes.
  Future<bool> unregisterDevice(String token) async {
    if (token.isEmpty) return false;
    try {
      // Passed on the query string because ApiClient.delete carries no body.
      final response = await _apiClient.delete(
        '/notifications/device-token?token=${Uri.encodeQueryComponent(token)}',
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Unregister device error: $e');
      return false;
    }
  }
}
