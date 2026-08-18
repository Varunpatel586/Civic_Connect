class Vote {
  final String id;
  final String issueId;
  final String userId;
  final String voteType;
  final DateTime createdAt;

  Vote({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.voteType,
    required this.createdAt,
  });

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      id: json['id']?.toString() ?? '',
      issueId: json['issue_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      voteType: json['vote_type']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'user_id': userId,
      'vote_type': voteType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
