import 'user_profile.dart';

class Comment {
  final String id;
  final String issueId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final UserProfile user;

  Comment({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.user,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'].toString(),
      issueId: json['issue_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      user: UserProfile.fromJson(json['user'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'user': user.toJson(),
    };
  }
}
