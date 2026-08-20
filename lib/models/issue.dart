import 'status_event.dart';

class Issue {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String category;
  final String imageUrl;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String status;
  final DateTime createdAt;
  final int agreeCount;
  final int disagreeCount;
  final int reportCount;
  final String? address;

  /// Administrative ward, derived server-side from the geocoded address.
  final String? ward;

  final String? userVote;

  /// Response deadline as computed by the server. Authoritative when present;
  /// [SlaPolicy] falls back to its own table only for payloads without it.
  final DateTime? dueAt;

  /// Set once the complaint reaches Resolved or Rejected.
  final DateTime? closedAt;

  /// Populated by the single-issue endpoint only; list endpoints omit it.
  final List<StatusEvent> statusHistory;

  Issue({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.category = 'other',
    required this.imageUrl,
    this.imageUrls = const [],
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = 'Pending',
    required this.createdAt,
    this.agreeCount = 0,
    this.disagreeCount = 0,
    this.reportCount = 1,
    this.address,
    this.ward,
    this.userVote,
    this.dueAt,
    this.closedAt,
    this.statusHistory = const [],
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? 'other',
      imageUrl: json['image_url']?.toString() ?? '',
      imageUrls:
          (json['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
      status: json['status']?.toString() ?? 'Pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      agreeCount: (json['agree_count'] as int?) ?? 0,
      disagreeCount: (json['disagree_count'] as int?) ?? 0,
      reportCount: (json['report_count'] as int?) ?? 1,
      address: json['address']?.toString(),
      ward: json['ward']?.toString(),
      userVote: json['user_vote']?.toString(),
      dueAt: json['due_at'] != null
          ? DateTime.tryParse(json['due_at'].toString())
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'].toString())
          : null,
      statusHistory:
          (json['status_history'] as List?)
              ?.map(
                (e) => StatusEvent.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'agree_count': agreeCount,
      'disagree_count': disagreeCount,
      'report_count': reportCount,
      'address': address,
      'ward': ward,
      'user_vote': userVote,
      'due_at': dueAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'status_history': statusHistory.map((e) => e.toJson()).toList(),
    };
  }
}
