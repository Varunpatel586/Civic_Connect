/// How many complaints sit in one category.
class CategoryCount {
  final String category;
  final int count;

  const CategoryCount({required this.category, required this.count});

  factory CategoryCount.fromJson(Map<String, dynamic> json) {
    return CategoryCount(
      category: json['category']?.toString() ?? 'other',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The counters a municipal officer opens the console to see.
///
/// Everything here is measured from stored records — no estimates. In
/// particular [avgCloseDays] is computed only across complaints that carry a
/// recorded closure, and [measuredClosures] says how many that was, so the
/// figure can be reported honestly rather than as a bare number.
class WardStats {
  final int total;
  final int open;
  final int overdue;
  final int inProgress;
  final int resolved;
  final int rejected;

  /// Mean days from filing to closure. Null until something has closed.
  final double? avgCloseDays;

  /// How many closures [avgCloseDays] was averaged over.
  final int measuredClosures;

  final List<CategoryCount> byCategory;

  const WardStats({
    required this.total,
    required this.open,
    required this.overdue,
    required this.inProgress,
    required this.resolved,
    required this.rejected,
    required this.avgCloseDays,
    required this.measuredClosures,
    required this.byCategory,
  });

  static const empty = WardStats(
    total: 0,
    open: 0,
    overdue: 0,
    inProgress: 0,
    resolved: 0,
    rejected: 0,
    avgCloseDays: null,
    measuredClosures: 0,
    byCategory: [],
  );

  /// Share of all complaints that have been resolved, 0–1. Null while nothing
  /// has been filed, so the UI can say "no data" instead of showing 0%.
  double? get resolutionRate => total == 0 ? null : resolved / total;

  factory WardStats.fromJson(Map<String, dynamic> json) {
    return WardStats(
      total: (json['total'] as num?)?.toInt() ?? 0,
      open: (json['open'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      inProgress: (json['in_progress'] as num?)?.toInt() ?? 0,
      resolved: (json['resolved'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
      avgCloseDays: (json['avg_close_days'] as num?)?.toDouble(),
      measuredClosures: (json['measured_closures'] as num?)?.toInt() ?? 0,
      byCategory:
          (json['by_category'] as List?)
              ?.map(
                (e) =>
                    CategoryCount.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
    );
  }
}
