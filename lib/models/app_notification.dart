/// One message in the citizen's or officer's inbox.
///
/// Named `AppNotification` rather than `Notification` because Flutter ships its
/// own `Notification` class, which is in scope wherever `material.dart` is.
class AppNotification {
  final String id;

  /// The complaint this concerns. Null for messages not about one.
  final String? issueId;

  /// One of `status_changed`, `verification_requested`,
  /// `verification_confirmed`, `verification_disputed`, `escalated`.
  final String type;

  final String title;
  final String body;

  /// Quotable reference of the complaint, carried on the message so a row can
  /// render without fetching the issue behind it.
  final String reference;

  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    this.issueId,
    required this.type,
    required this.title,
    this.body = '',
    this.reference = '',
    this.read = false,
    this.readAt,
    required this.createdAt,
  });

  /// True when this message asks the reporter to confirm a claimed fix. The
  /// inbox draws these differently because they are the only ones that need an
  /// answer rather than just being read.
  bool get needsAnswer => type == 'verification_requested';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      issueId: json['issue_id']?.toString(),
      type: json['type']?.toString() ?? 'status_changed',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      read: json['read'] == true,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_id': issueId,
      'type': type,
      'title': title,
      'body': body,
      'reference': reference,
      'read': read,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({bool? read, DateTime? readAt}) {
    return AppNotification(
      id: id,
      issueId: issueId,
      type: type,
      title: title,
      body: body,
      reference: reference,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
