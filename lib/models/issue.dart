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
  /// Quotable complaint reference, e.g. `CC-2026-GJ-04821`. Computed by the
  /// server so it cannot disagree with what a notification quoted.
  /// Everyone who reported this complaint. Clustering merges duplicate
  /// reports, so this can hold several accounts, and any of them may
  /// answer the verification question.
  final List<String> reporterIds;

  /// Photo from the most recent time an officer claimed this was fixed.
  /// Shown beside the original when the reporter is asked to confirm.
  final String resolutionPhotoUrl;
  final String? reference;

  /// Whether the reporter has agreed the fix is real: one of `none`,
  /// `pending`, `confirmed`, `auto_confirmed` or `disputed`. Independent of
  /// [status] — the officer claims, the citizen confirms.
  final String verificationState;

  /// When the reporter loses the chance to dispute a claimed fix.
  final DateTime? verificationDueBy;

  /// The reporter's own words when they answered.
  final String verificationNote;

  /// Photo the reporter supplied to show the problem is still there.
  final String verificationEvidenceUrl;

  /// Set when a disputed fix sent this complaint back into the queue.
  final DateTime? escalatedAt;

  final int reopenCount;

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
    this.reporterIds = const [],
    this.resolutionPhotoUrl = '',    this.reference,
    this.verificationState = 'none',
    this.verificationDueBy,
    this.verificationNote = '',
    this.verificationEvidenceUrl = '',
    this.escalatedAt,
    this.reopenCount = 0,
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
      reporterIds:
          (json['reporter_ids'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      resolutionPhotoUrl: json['resolution_photo_url']?.toString() ?? '',      reference: json['reference']?.toString(),
      verificationState: json['verification_state']?.toString() ?? 'none',
      verificationDueBy: json['verification_due_by'] != null
          ? DateTime.tryParse(json['verification_due_by'].toString())
          : null,
      verificationNote: json['verification_note']?.toString() ?? '',
      verificationEvidenceUrl:
          json['verification_evidence_url']?.toString() ?? '',
      escalatedAt: json['escalated_at'] != null
          ? DateTime.tryParse(json['escalated_at'].toString())
          : null,
      reopenCount: (json['reopen_count'] as int?) ?? 0,
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
      'reporter_ids': reporterIds,
      'resolution_photo_url': resolutionPhotoUrl,      'reference': reference,
      'verification_state': verificationState,
      'verification_due_by': verificationDueBy?.toIso8601String(),
      'verification_note': verificationNote,
      'verification_evidence_url': verificationEvidenceUrl,
      'escalated_at': escalatedAt?.toIso8601String(),
      'reopen_count': reopenCount,
    };
  }
}
