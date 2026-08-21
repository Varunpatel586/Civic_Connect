/// Lightweight model for the `/api/issues/map` endpoint response.
/// Contains only the fields needed to render map markers — full issue
/// details are fetched via the existing issue-by-id endpoint on tap.
class MapIssue {
  final String id;
  final double latitude;
  final double longitude;
  final String category;
  final String status;
  final String imageUrl;
  final String title;
  final String? address;
  final DateTime createdAt;

  const MapIssue({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.status,
    required this.imageUrl,
    required this.title,
    this.address,
    required this.createdAt,
  });

  factory MapIssue.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final coordinates = location?['coordinates'] as List<dynamic>?;
    final longitude = coordinates != null && coordinates.length > 1
        ? (coordinates[0] as num).toDouble()
        : (json['longitude'] as num?)?.toDouble() ?? 0.0;
    final latitude = coordinates != null && coordinates.length > 1
        ? (coordinates[1] as num).toDouble()
        : (json['latitude'] as num?)?.toDouble() ?? 0.0;

    return MapIssue(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      category: json['category']?.toString() ?? 'other',
      status: json['status']?.toString() ?? 'Pending',
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      address: json['address']?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at']) != null
          ? DateTime.parse((json['createdAt'] ?? json['created_at']).toString())
          : DateTime.now(),
    );
  }
}
