import 'package:civic_connect/models/ward_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WardStats.fromJson', () {
    test('reads the counters the console displays', () {
      final stats = WardStats.fromJson({
        'total': 10,
        'open': 6,
        'overdue': 2,
        'in_progress': 2,
        'resolved': 3,
        'rejected': 1,
        'avg_close_days': 4.0,
        'measured_closures': 3,
        'by_category': [
          {'category': 'pothole', 'count': 3},
          {'category': 'garbage', 'count': 2},
        ],
      });

      expect(stats.total, 10);
      expect(stats.open, 6);
      expect(stats.overdue, 2);
      expect(stats.resolved, 3);
      expect(stats.avgCloseDays, 4.0);
      expect(stats.measuredClosures, 3);
      expect(stats.byCategory.length, 2);
      expect(stats.byCategory.first.category, 'pothole');
      expect(stats.byCategory.first.count, 3);
    });

    test('a null average survives — nothing has closed yet', () {
      final stats = WardStats.fromJson({
        'total': 4,
        'open': 4,
        'avg_close_days': null,
        'measured_closures': 0,
      });

      expect(stats.avgCloseDays, isNull);
      expect(stats.measuredClosures, 0);
    });

    test('an integer average is read as a double', () {
      // Mongo hands back a bare int when the mean lands on a whole number.
      final stats = WardStats.fromJson({'avg_close_days': 4});

      expect(stats.avgCloseDays, 4.0);
    });

    test('a missing payload degrades to zeroes rather than throwing', () {
      final stats = WardStats.fromJson({});

      expect(stats.total, 0);
      expect(stats.open, 0);
      expect(stats.avgCloseDays, isNull);
      expect(stats.byCategory, isEmpty);
    });
  });

  group('resolutionRate', () {
    test('is the resolved share of everything filed', () {
      final stats = WardStats.fromJson({'total': 10, 'resolved': 3});

      expect(stats.resolutionRate, closeTo(0.3, 1e-9));
    });

    test('is null rather than zero when nothing has been filed', () {
      // Distinguishes "no complaints" from "nothing resolved", which read very
      // differently on a dashboard.
      expect(WardStats.empty.resolutionRate, isNull);
    });
  });
}
