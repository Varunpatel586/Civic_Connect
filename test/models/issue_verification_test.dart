import 'package:civic_connect/models/issue.dart';
import 'package:civic_connect/models/status_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// These fields cross the wire in snake_case and are read nowhere else, so a
/// renamed key on the server would surface as a silently empty verification
/// prompt rather than an error. Pinning the contract here is cheaper than
/// discovering that on stage.
void main() {
  Map<String, dynamic> payload(Map<String, dynamic> extra) => {
    'id': '65f1a2b3c4d5e6f704821a',
    'user_id': 'reporter-1',
    'title': 'Pothole on MG Road',
    'image_url': 'http://example.test/before.jpg',
    'latitude': 23.02,
    'longitude': 72.57,
    'status': 'Resolved',
    'created_at': '2026-03-14T09:30:00.000Z',
    'timestamp': '2026-03-14T09:30:00.000Z',
    ...extra,
  };

  group('Issue.fromJson verification fields', () {
    test('reads everything the verification prompt needs', () {
      final issue = Issue.fromJson(
        payload({
          'reference': 'CC-2026-GJ-04821',
          'reporter_ids': ['reporter-1', 'reporter-2'],
          'verification_state': 'pending',
          'verification_due_by': '2026-03-17T09:30:00.000Z',
          'verification_note': 'Still flooded',
          'verification_evidence_url': 'http://example.test/still-broken.jpg',
          'resolution_photo_url': 'http://example.test/after.jpg',
          'escalated_at': '2026-03-16T08:00:00.000Z',
          'reopen_count': 2,
        }),
      );

      expect(issue.reference, 'CC-2026-GJ-04821');
      expect(issue.reporterIds, ['reporter-1', 'reporter-2']);
      expect(issue.verificationState, 'pending');
      expect(issue.verificationDueBy, isNotNull);
      expect(issue.verificationNote, 'Still flooded');
      expect(
        issue.verificationEvidenceUrl,
        'http://example.test/still-broken.jpg',
      );
      expect(issue.resolutionPhotoUrl, 'http://example.test/after.jpg');
      expect(issue.escalatedAt, isNotNull);
      expect(issue.reopenCount, 2);
    });

    test('a payload predating the feature degrades rather than throwing', () {
      final issue = Issue.fromJson(payload({}));

      // 'none' matters specifically: the prompt is gated on 'pending', so an
      // older complaint must not appear to be awaiting an answer.
      expect(issue.verificationState, 'none');
      expect(issue.verificationDueBy, isNull);
      expect(issue.resolutionPhotoUrl, '');
      expect(issue.reporterIds, isEmpty);
      expect(issue.reopenCount, 0);
      expect(issue.escalatedAt, isNull);
    });

    test('survives a round trip through toJson', () {
      final original = Issue.fromJson(
        payload({
          'verification_state': 'disputed',
          'resolution_photo_url': 'http://example.test/after.jpg',
          'reporter_ids': ['reporter-1'],
          'reopen_count': 1,
        }),
      );

      final restored = Issue.fromJson(original.toJson());

      expect(restored.verificationState, 'disputed');
      expect(restored.resolutionPhotoUrl, 'http://example.test/after.jpg');
      expect(restored.reporterIds, ['reporter-1']);
      expect(restored.reopenCount, 1);
    });
  });

  group('StatusEvent.fromJson', () {
    test('carries the officer proof photo', () {
      final event = StatusEvent.fromJson({
        'status': 'Resolved',
        'changed_at': '2026-03-15T11:00:00.000Z',
        'note': 'Filled and levelled',
        'photo_url': 'http://example.test/after.jpg',
      });

      expect(event.status, 'Resolved');
      expect(event.note, 'Filled and levelled');
      expect(event.photoUrl, 'http://example.test/after.jpg');
    });

    test('an entry with no photo reads as empty, not null', () {
      final event = StatusEvent.fromJson({
        'status': 'In Progress',
        'changed_at': '2026-03-15T11:00:00.000Z',
      });

      expect(event.photoUrl, '');
    });
  });
}
