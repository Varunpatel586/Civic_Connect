import 'dart:convert';

import '../models/issue.dart';
import '../models/ward_stats.dart';
import 'api_client.dart';

/// Raised when the server rejects a municipal action, carrying the server's own
/// message so the UI can say what actually went wrong.
class AdminException implements Exception {
  final String message;
  AdminException(this.message);

  @override
  String toString() => 'AdminException: $message';
}

/// The municipal-officer half of the API.
///
/// Every endpoint here is gated behind the server's `admin` middleware, which
/// re-reads the account's role rather than trusting the token — so a revoked
/// officer loses access immediately rather than when their token expires.
class AdminService {
  final ApiClient _apiClient = ApiClient();

  /// Ward counters for the overview.
  Future<WardStats> getStats() async {
    final response = await _apiClient.get('/issues/stats');

    if (response.statusCode == 200) {
      return WardStats.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw AdminException(_apiClient.errorMessage(response, 'Could not load ward statistics'));
  }

  /// The triage queue, already ranked by the server: overdue first, then most
  /// agreed-with, then oldest.
  Future<List<Issue>> getQueue({String? status, String? category}) async {
    final query = <String, String>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
    };
    final suffix = query.isEmpty
        ? ''
        : '?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

    final response = await _apiClient.get('/issues/queue$suffix');

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((e) => Issue.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw AdminException(_apiClient.errorMessage(response, 'Could not load the triage queue'));
  }

  /// Moves a complaint to a new state, optionally recording why.
  Future<Issue> updateStatus({
    required String issueId,
    required String status,
    String note = '',
  }) async {
    final response = await _apiClient.patch('/issues/$issueId/status', {
      'status': status,
      if (note.trim().isNotEmpty) 'note': note.trim(),
    });

    if (response.statusCode == 200) {
      return Issue.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw AdminException(_apiClient.errorMessage(response, 'Could not update the complaint'));
  }
}
