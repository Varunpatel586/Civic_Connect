import 'package:civic_connect/models/issue.dart';
import 'package:civic_connect/utils/sla.dart';
import 'package:flutter_test/flutter_test.dart';

Issue _issue({
  required String category,
  required DateTime createdAt,
  String status = 'Pending',
}) {
  return Issue(
    id: '66bc2e2a0f8b1c4d4b123457',
    userId: 'u1',
    title: 'Test complaint',
    category: category,
    imageUrl: 'http://example.test/a.jpg',
    latitude: 23.03,
    longitude: 72.58,
    timestamp: createdAt,
    createdAt: createdAt,
    status: status,
  );
}

void main() {
  // Pinned so the tests do not drift with the wall clock.
  final now = DateTime(2026, 8, 20, 12);

  group('response windows', () {
    test('urgent categories get a short window', () {
      expect(SlaPolicy.windowFor('water'), 2);
      expect(SlaPolicy.windowFor('electricity'), 2);
    });

    test('wear-and-tear categories get a long window', () {
      expect(SlaPolicy.windowFor('road'), 10);
      expect(SlaPolicy.windowFor('pothole'), 7);
    });

    test('an unknown category falls back rather than throwing', () {
      expect(SlaPolicy.windowFor('meteor_strike'), 7);
    });

    test('category matching ignores case', () {
      expect(SlaPolicy.windowFor('WATER'), 2);
    });
  });

  group('evaluate', () {
    test('reports days remaining inside the window', () {
      final issue = _issue(
        category: 'pothole', // 7 day window
        createdAt: now.subtract(const Duration(days: 5)),
      );

      final sla = SlaPolicy.evaluate(issue, now: now);

      expect(sla.state, SlaState.onTrack);
      expect(sla.days, 2);
      expect(sla.label, 'Due in 2 days');
    });

    test('flags the last day before the deadline', () {
      final issue = _issue(
        category: 'pothole',
        createdAt: now.subtract(const Duration(days: 6)),
      );

      final sla = SlaPolicy.evaluate(issue, now: now);

      expect(sla.state, SlaState.dueSoon);
      expect(sla.label, 'Due tomorrow');
    });

    test('flags work past its deadline and counts the days late', () {
      final issue = _issue(
        category: 'water', // 2 day window
        createdAt: now.subtract(const Duration(days: 5)),
      );

      final sla = SlaPolicy.evaluate(issue, now: now);

      expect(sla.state, SlaState.overdue);
      expect(sla.isOverdue, isTrue);
      expect(sla.days, 3);
      expect(sla.label, 'Overdue by 3 days');
    });

    test('singular day reads correctly', () {
      final issue = _issue(
        category: 'water',
        createdAt: now.subtract(const Duration(days: 3)),
      );

      expect(SlaPolicy.evaluate(issue, now: now).label, 'Overdue by 1 day');
    });

    test('stops the clock once the complaint is resolved', () {
      final issue = _issue(
        category: 'water',
        createdAt: now.subtract(const Duration(days: 90)),
        status: 'Resolved',
      );

      final sla = SlaPolicy.evaluate(issue, now: now);

      expect(sla.state, SlaState.closed);
      expect(sla.isClosed, isTrue);
      expect(sla.isOverdue, isFalse);
    });

    test('stops the clock once the complaint is rejected', () {
      final issue = _issue(
        category: 'water',
        createdAt: now.subtract(const Duration(days: 90)),
        status: 'Rejected',
      );

      expect(SlaPolicy.evaluate(issue, now: now).isClosed, isTrue);
    });
  });
}
