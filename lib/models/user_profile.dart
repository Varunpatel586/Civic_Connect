class UserProfile {
  final String id;
  final String username;
  final String email;
  final String role;
  final String? avatarUrl;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Unknown',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
