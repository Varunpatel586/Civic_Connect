import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' hide ClusterManager, Cluster;
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/map_provider.dart';
import '../widgets/issue_preview_sheet.dart';

/// A ClusterItem wrapper around MapIssue so the cluster manager can
/// extract a LatLng from each issue.
class MapIssueClusterItem with ClusterItem {
  final MapIssue issue;

  MapIssueClusterItem(this.issue);

  @override
  LatLng get location => LatLng(issue.latitude, issue.longitude);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Timer? _debounceTimer;
  Set<Marker> _markers = {};
  late ClusterManager<MapIssueClusterItem> _clusterManager;
  LatLng? _lastCenteredLocation;

  // Default location: Mountain View, CA (matches seed data)
  static const _defaultCenter = LatLng(37.4225, -122.084);

  // Filter state
  static const _statusOptions = ['Pending', 'In Progress', 'Resolved', 'Rejected'];
  static const _categoryOptions = [
    'pothole', 'street_light', 'water', 'electricity',
    'garbage', 'road', 'drainage', 'other',
  ];

  @override
  void initState() {
    super.initState();
    _clusterManager = ClusterManager<MapIssueClusterItem>(
      [],
      _updateMarkers,
      markerBuilder: _markerBuilder,
      levels: const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
      extraPercent: 0.2,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Map Callbacks
  // ---------------------------------------------------------------------------

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _clusterManager.setMapId(controller.mapId);
    _centerOnAvailableLocation();
    // Initial fetch after map loads
    _onCameraIdle();
  }

  void _centerOnAvailableLocation() {
    final position = context.read<AppProvider>().currentPosition;
    if (position == null || _mapController == null) return;

    final location = LatLng(position.latitude, position.longitude);
    if (_lastCenteredLocation == location) return;
    _lastCenteredLocation = location;
    _mapController!.animateCamera(CameraUpdate.newLatLngZoom(location, 13));
  }

  void _onCameraMove(CameraPosition position) {
    _clusterManager.onCameraMove(position);
  }

  void _onCameraIdle() {
    _clusterManager.updateMap();

    // Debounce the API call so we don't fire on every tiny pan
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (_mapController == null) return;
      final bounds = await _mapController!.getVisibleRegion();
      if (!mounted) return;
      final mapProvider = context.read<MapProvider>();
      await mapProvider.fetchIssuesInBounds(bounds);

      // Feed updated issues to the cluster manager
      final items = mapProvider.mapIssues
          .map((issue) => MapIssueClusterItem(issue))
          .toList();
      _clusterManager.setItems(items);
    });
  }

  // ---------------------------------------------------------------------------
  // Marker Builder
  // ---------------------------------------------------------------------------

  void _updateMarkers(Set<Marker> markers) {
    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  Future<Marker> Function(Cluster<MapIssueClusterItem>) get _markerBuilder =>
      (Cluster<MapIssueClusterItem> cluster) async {
        final isCluster = cluster.isMultiple;

        if (isCluster) {
          // Cluster marker: circle with count
          final icon = await _buildClusterIcon(cluster.count);
          return Marker(
            markerId: MarkerId(cluster.getId()),
            position: cluster.location,
            icon: icon,
            onTap: () async {
              showClusterIssueSheet(
                context,
                cluster.items.map((item) => item.issue).toList(),
              );
            },
          );
        } else {
          // Single issue marker
          final issue = cluster.items.first.issue;
          final color = _statusHue(issue.status);
          return Marker(
            markerId: MarkerId('issue_${issue.id}'),
            position: LatLng(issue.latitude, issue.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(color),
            onTap: () {
              showIssuePreviewSheet(context, issue);
            },
          );
        }
      };

  /// Builds a round cluster icon with the issue count rendered as text.
  Future<BitmapDescriptor> _buildClusterIcon(int count) async {
    final size = count < 10 ? 80.0 : (count < 100 ? 95.0 : 110.0);
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = Colors.green;

    // Outer circle
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
    // Inner lighter circle
    paint.color = Colors.green.shade300;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 6, paint);
    // White center
    paint.color = Colors.white;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 12, paint);

    // Count text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: TextStyle(
          fontSize: size / 3,
          color: Colors.green.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size / 2 - textPainter.height / 2,
      ),
    );

    final image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// Maps issue status to a marker hue (matching the color scheme in issue_card.dart).
  static double _statusHue(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return BitmapDescriptor.hueGreen;
      case 'in progress':
        return BitmapDescriptor.hueOrange;
      case 'rejected':
        return BitmapDescriptor.hueRed;
      default: // pending
        return BitmapDescriptor.hueAzure;
    }
  }

  // ---------------------------------------------------------------------------
  // Re-center on user location
  // ---------------------------------------------------------------------------

  void _goToUserLocation() {
    final appProvider = context.read<AppProvider>();
    final position = appProvider.currentPosition;
    if (position != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Filter Chips
  // ---------------------------------------------------------------------------

  Widget _buildFilterBar() {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status filters
                ..._statusOptions.map((status) {
                  final isSelected = mapProvider.selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        status,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        mapProvider.setFilter(
                          status: selected ? status : null,
                          category: mapProvider.selectedCategory,
                        );
                        _onCameraIdle(); // re-fetch with new filter
                      },
                      selectedColor: Colors.green,
                      backgroundColor: Colors.grey[100],
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }),
                // Divider
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                // Category filters
                ..._categoryOptions.map((cat) {
                  final isSelected = mapProvider.selectedCategory == cat;
                  final label = cat.replaceAll('_', ' ');
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        label[0].toUpperCase() + label.substring(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        mapProvider.setFilter(
                          category: selected ? cat : null,
                          status: mapProvider.selectedStatus,
                        );
                        _onCameraIdle(); // re-fetch with new filter
                      },
                      selectedColor: Colors.green,
                      backgroundColor: Colors.grey[100],
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerOnAvailableLocation();
    });

    // Determine initial center from the user's current location
    final appProvider = context.read<AppProvider>();
    final position = appProvider.currentPosition;
    final initialTarget = position != null
        ? LatLng(position.latitude, position.longitude)
        : _defaultCenter;

    return Stack(
      children: [
        // Google Map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 13,
          ),
          onMapCreated: _onMapCreated,
          onCameraMove: _onCameraMove,
          onCameraIdle: _onCameraIdle,
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        // Filter bar at top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: _buildFilterBar(),
          ),
        ),

        // Loading indicator
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Consumer<MapProvider>(
            builder: (context, mapProvider, _) {
              if (!mapProvider.isLoading) return const SizedBox.shrink();
              return const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Colors.green,
              );
            },
          ),
        ),

        // My location FAB
        Positioned(
          bottom: 24,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'map_locate_btn',
            onPressed: _goToUserLocation,
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: Colors.green),
          ),
        ),
      ],
    );
  }
}
