class Issue {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String status;
  final DateTime createdAt;
  final int agreeCount;
  final int disagreeCount;
  final String? address;
  final String? userVote;

  Issue({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = 'Pending',
    required this.createdAt,
    this.agreeCount = 0,
    this.disagreeCount = 0,
    this.address,
    this.userVote,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString() ?? '',
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
      address: json['address']?.toString(),
      userVote: json['user_vote']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'agree_count': agreeCount,
      'disagree_count': disagreeCount,
      'address': address,
      'user_vote': userVote,
    };
  }
}
