import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../providers/app_provider.dart';
import '../services/issue_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/complaint_reference.dart';
import '../utils/issue_categories.dart';
import '../utils/sla.dart';
import '../widgets/status_chip.dart';
import 'issue_detail_screen.dart';

/// Complaints plotted where they were reported.
///
/// Uses OpenStreetMap tiles rather than Google Maps: no API key, no billing
/// account, and nothing to configure before it works — which matters more here
/// than the marginal difference in tile styling.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// Bandra West — where the seeded complaints sit, so the map opens on data
  /// rather than the middle of the ocean when there is no location fix.
  static const LatLng _fallbackCentre = LatLng(19.0596, 72.8295);

  final IssueService _issueService = IssueService();
  final MapController _mapController = MapController();

  List<Issue> _issues = [];
  Issue? _selected;
  bool _isLoading = true;
  String? _error;

  /// The controller throws if it is driven before [FlutterMap] has attached it,
  /// so nothing may move the camera until `onMapReady` has fired.
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Radius is deliberately unbounded: a map that only showed a 5 km circle
      // would look broken the moment you panned out of it.
      final issues = await _issueService.getNearbyIssues(
        latitude: 0,
        longitude: 0,
        radiusKm: 20000,
        limit: 200,
      );

      if (!mounted) return;
      setState(() {
        _issues = issues;
        _isLoading = false;
      });

      // On the first load the map does not exist yet; `onMapReady` frames it
      // instead. On a refresh the map is already up, so frame it now.
      if (_isMapReady) _fitToComplaints();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the complaint map.';
        _isLoading = false;
      });
    }
  }

  /// Frames every plotted complaint, so the map never opens somewhere with
  /// nothing on it.
  void _fitToComplaints() {
    if (!_isMapReady) return;

    final points = _issues
        .where((i) => i.latitude != 0 || i.longitude != 0)
        .map((i) => LatLng(i.latitude, i.longitude))
        .toList();

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ),
    );
  }

  void _goToMyLocation() {
    if (!_isMapReady) return;
    final position = context.read<AppProvider>().currentPosition;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location is off, so you cannot be placed on the map.')),
      );
      return;
    }
    _mapController.move(LatLng(position.latitude, position.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 38,
                color: AppColors.slate200,
              ),
              const SizedBox(height: 12),
              Text(_error!, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final position = context.select<AppProvider, ({double lat, double lng})?>(
      (p) => p.currentPosition == null
          ? null
          : (lat: p.currentPosition!.latitude, lng: p.currentPosition!.longitude),
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: position == null
                ? _fallbackCentre
                : LatLng(position.lat, position.lng),
            initialZoom: 13,
            onMapReady: () {
              _isMapReady = true;
              _fitToComplaints();
            },
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.civic_connect',
              maxZoom: 19,
              // Tile failures are otherwise silent — the basemap just stays
              // blank with no clue why.
              errorTileCallback: (tile, error, stackTrace) {
                debugPrint('TILE ERROR ${tile.coordinates}: $error');
              },
            ),
            if (position != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(position.lat, position.lng),
                    width: 18,
                    height: 18,
                    child: const _YouAreHere(),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final issue in _issues)
                  if (issue.latitude != 0 || issue.longitude != 0)
                    Marker(
                      point: LatLng(issue.latitude, issue.longitude),
                      width: 36,
                      height: 36,
                      child: _ComplaintPin(
                        issue: issue,
                        selected: _selected?.id == issue.id,
                        onTap: () => setState(() => _selected = issue),
                      ),
                    ),
              ],
            ),
          ],
        ),
        const Positioned(top: 10, left: 10, child: _Legend()),
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              _MapButton(
                icon: Icons.my_location,
                tooltip: 'Centre on me',
                onTap: _goToMyLocation,
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: Icons.fit_screen_outlined,
                tooltip: 'Show all complaints',
                onTap: _fitToComplaints,
              ),
            ],
          ),
        ),
        if (_selected != null)
          Positioned(
            left: 10,
            right: 10,
            bottom: 12,
            child: _SelectedCard(
              issue: _selected!,
              onOpen: () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          IssueDetailScreen(issueId: _selected!.id),
                    ),
                  )
                  .then((_) => _load()),
              onDismiss: () => setState(() => _selected = null),
            ),
          ),
        // OpenStreetMap's licence requires visible attribution.
        const Positioned(right: 0, bottom: 0, child: _Attribution()),
      ],
    );
  }
}

/// A complaint on the map, coloured by where it stands.
class _ComplaintPin extends StatelessWidget {
  final Issue issue;
  final bool selected;
  final VoidCallback onTap;

  const _ComplaintPin({
    required this.issue,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = SlaPolicy.evaluate(issue).isOverdue;
    final palette = overdue
        ? StatusColors.overdue
        : StatusColors.forStatus(issue.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: palette.background,
          border: Border.all(
            color: palette.foreground,
            width: selected ? 3 : 2,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.navy900.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          IssueCategories.iconFor(issue.category),
          size: 17,
          color: palette.foreground,
        ),
      ),
    );
  }
}

class _YouAreHere extends StatelessWidget {
  const _YouAreHere();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy900,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const _entries = <(String, StatusPalette)>[
    ('Overdue', StatusColors.overdue),
    ('Pending', StatusColors.pending),
    ('In progress', StatusColors.inProgress),
    ('Resolved', StatusColors.resolved),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, palette) in _entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: palette.background,
                      border: Border.all(color: palette.foreground, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: AppTypography.badge(color: AppColors.slate600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.slate200),
          borderRadius: BorderRadius.circular(3),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 19, color: AppColors.navy900),
          ),
        ),
      ),
    );
  }
}

/// Compact summary of the tapped pin.
class _SelectedCard extends StatelessWidget {
  final Issue issue;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const _SelectedCard({
    required this.issue,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final sla = SlaPolicy.evaluate(issue);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            issue.title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          status: issue.status,
                          overdue: sla.isOverdue,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          ComplaintReference.format(issue),
                          style: AppTypography.recordId(),
                        ),
                        const SizedBox(width: 9),
                        Flexible(child: SlaLabel(sla: sla)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ComplaintReference.locality(issue.address) ??
                          'Location unrecorded',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 17),
                color: AppColors.slate600,
                tooltip: 'Dismiss',
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.82),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Text(
        '© OpenStreetMap contributors',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontSize: 9),
      ),
    );
  }
}
