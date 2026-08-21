import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';
import '../services/issue_service.dart';

/// Provider for the map view, managing map issue data and filter state.
class MapProvider with ChangeNotifier {
  final IssueService _issueService = IssueService();

  List<MapIssue> _mapIssues = [];
  bool _isLoading = false;
  String? _selectedCategory;
  String? _selectedStatus;
  String? _since;

  // Getters
  List<MapIssue> get mapIssues => _mapIssues;
  bool get isLoading => _isLoading;
  String? get selectedCategory => _selectedCategory;
  String? get selectedStatus => _selectedStatus;
  String? get since => _since;

  /// Fetches issues within the given map viewport bounds.
  Future<void> fetchIssuesInBounds(
    LatLngBounds bounds, {
    String? since,
  }) async {
    _since = since;
    _isLoading = true;
    notifyListeners();

    try {
      _mapIssues = await _issueService.getMapIssues(
        swLat: bounds.southwest.latitude,
        swLng: bounds.southwest.longitude,
        neLat: bounds.northeast.latitude,
        neLng: bounds.northeast.longitude,
        status: _selectedStatus,
        category: _selectedCategory,
        since: _since,
      );
    } catch (e) {
      debugPrint('Error fetching map issues: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the active filters. Does NOT re-fetch automatically —
  /// the screen re-fetches on camera idle with the current bounds.
  void setFilter({String? category, String? status}) {
    _selectedCategory = category;
    _selectedStatus = status;
    notifyListeners();
  }

  /// Clears all active filters.
  void clearFilters() {
    _selectedCategory = null;
    _selectedStatus = null;
    _since = null;
    notifyListeners();
  }
}
