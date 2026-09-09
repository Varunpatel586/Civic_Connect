/// One entry in a complaint's lifecycle.
///
/// The server records these on filing and on every status change, so the
/// citizen-facing timeline is a read of what actually happened rather than a
/// reconstruction from the current state.
class StatusEvent {
  final String status;
  final DateTime changedAt;

  /// Optional free text an officer attached to the change.
  final String note;

  /// Photograph of the completed work, present on Resolved entries.
  /// The server requires one before it will accept that status.
  final String photoUrl;

  StatusEvent({
    required this.status,
    required this.changedAt,
    this.note = '',
    this.photoUrl = '',
  });

  factory StatusEvent.fromJson(Map<String, dynamic> json) {
    return StatusEvent(
      status: json['status']?.toString() ?? 'Pending',
      changedAt: json['changed_at'] != null
          ? DateTime.parse(json['changed_at'].toString())
          : DateTime.now(),
      note: json['note']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'changed_at': changedAt.toIso8601String(),
    'note': note,
    'photo_url': photoUrl,
  };
}
