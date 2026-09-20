import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';

import '../models/issue.dart';
import '../providers/app_provider.dart';
import '../services/api_client.dart';
import '../services/issue_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
  double _rotationAngle = 0.0;

  void _rotateMap() {
    if (!_isMapReady) return;
    setState(() {
      _rotationAngle = (_rotationAngle + 90.0) % 360.0;
    });
    _mapController.rotate(_rotationAngle);
  }

  void _showClusterBottomSheet(BuildContext context, List<Issue> issues) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${issues.length} Issues at this location',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: issues.length,
                  itemBuilder: (context, index) {
                    final issue = issues[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: issue.imageUrl.isNotEmpty
                            ? Image.network(
                                ApiClient().normalizeUrl(issue.imageUrl),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 40,
                                  height: 40,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, size: 20),
                                ),
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, size: 20),
                              ),
                      ),
                      title: Text(
                        issue.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Category: ${issue.category} · Status: ${issue.status}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selected = issue;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

  Future<void> _refreshIssue(String issueId) async {
    final updatedIssue = await _issueService.getIssueById(issueId);
    if (!mounted || updatedIssue == null) return;

    final index = _issues.indexWhere((issue) => issue.id == issueId);
    if (index == -1) return;
    setState(() {
      _issues[index] = updatedIssue;
      if (_selected?.id == issueId) _selected = updatedIssue;
    });
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
        const SnackBar(
          content: Text('Location is off, so you cannot be placed on the map.'),
        ),
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
                size: 36,
                color: AppColors.slate400,
              ),
              const SizedBox(height: 14),
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
          : (
              lat: p.currentPosition!.latitude,
              lng: p.currentPosition!.longitude,
            ),
    );

    final Map<String, List<Issue>> groupedIssues = {};
    for (final issue in _issues) {
      if (issue.latitude != 0 || issue.longitude != 0) {
        final key = '${issue.latitude.toStringAsFixed(6)}_${issue.longitude.toStringAsFixed(6)}';
        groupedIssues.putIfAbsent(key, () => []).add(issue);
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: position == null
                ? _fallbackCentre
                : LatLng(position.lat, position.lng),
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              enableMultiFingerGestureRace: true,
            ),
            onMapReady: () {
              _isMapReady = true;
              final userPos = context.read<AppProvider>().currentPosition;
              if (userPos == null) {
                _fitToComplaints();
              }
            },
            onTap: (_, __) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              fallbackUrl: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.civic_connect',
              maxZoom: 19,
              tileProvider: NetworkTileProvider(
                cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
                  overrideFreshAge: const Duration(days: 30), // Force long cache duration for instant offline loading
                ),
              ),
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
                for (final entry in groupedIssues.entries) ...[
                  if (entry.value.length == 1)
                    Marker(
                      point: LatLng(entry.value[0].latitude, entry.value[0].longitude),
                      width: 50,
                      height: 55,
                      alignment: Alignment.bottomCenter,
                      child: _ComplaintPin(
                        issue: entry.value[0],
                        selected: _selected?.id == entry.value[0].id,
                        onTap: () => setState(() => _selected = entry.value[0]),
                      ),
                    )
                  else
                    Marker(
                      point: LatLng(entry.value[0].latitude, entry.value[0].longitude),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: _ClusterPin(
                        count: entry.value.length,
                        onTap: () => _showClusterBottomSheet(context, entry.value),
                      ),
                    )
                ]
              ],
            ),
          ],
        ),
        const Positioned(top: 12, left: 12, child: _Legend()),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _MapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Centre on me',
                onTap: _goToMyLocation,
              ),
              const SizedBox(height: 10),
              _MapButton(
                icon: Icons.fit_screen_outlined,
                tooltip: 'Show all complaints',
                onTap: _fitToComplaints,
              ),
              const SizedBox(height: 10),
              _MapButton(
                tooltip: 'Rotate map (North/90/180/270)',
                onTap: _rotateMap,
                child: Transform.rotate(
                  angle: -_rotationAngle * (3.1415926535897932 / 180.0),
                  child: const Icon(Icons.explore_outlined, size: 19, color: AppColors.navy900),
                ),
              ),
            ],
          ),
        ),
        if (_selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: _SelectedCard(
              issue: _selected!,
              onOpen: () {
                final issueId = _selected!.id;
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => IssueDetailScreen(issueId: issueId),
                      ),
                    )
                    .then((_) => _refreshIssue(issueId));
              },
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

    final double size = selected ? 44.0 : 38.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: palette.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.navy900 : palette.foreground,
                width: selected ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy900.withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: issue.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: ApiClient().normalizeUrl(issue.imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: palette.background,
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                palette.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        IssueCategories.iconFor(issue.category),
                        size: selected ? 20 : 16,
                        color: palette.foreground,
                      ),
                    )
                  : Icon(
                      IssueCategories.iconFor(issue.category),
                      size: selected ? 20 : 16,
                      color: palette.foreground,
                    ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -3),
            child: ClipPath(
              clipper: _TriangleClipper(),
              child: Container(
                width: 10,
                height: 7,
                color: selected ? AppColors.navy900 : palette.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, palette) in _entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
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
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.meta(color: AppColors.slate600),
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
  final IconData? icon;
  final Widget? child;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton({
    this.icon,
    this.child,
    required this.tooltip,
    required this.onTap,
  }) : assert(icon != null || child != null);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: AppTheme.softShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: child ?? Icon(icon, size: 19, color: AppColors.navy900),
            ),
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

    return DecoratedBox(
      decoration: AppTheme.cardDecoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Text(
                            ComplaintReference.format(issue),
                            style: AppTypography.recordId(),
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: SlaLabel(sla: sla)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ComplaintReference.locality(issue.address) ??
                            'Location unrecorded',
                        style: AppTypography.meta(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.slate400,
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                ),
              ],
            ),
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
      color: AppColors.surface.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        '© OpenStreetMap contributors',
        style: AppTypography.meta().copyWith(fontSize: 9.5),
      ),
    );
  }
}

class _ClusterPin extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ClusterPin({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
