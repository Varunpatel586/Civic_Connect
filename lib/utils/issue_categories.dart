import 'package:flutter/material.dart';

/// One complaint category, as the municipality would list it.
@immutable
class IssueCategory {
  /// The value stored on the issue and validated by the server's enum.
  final String value;

  /// What a citizen sees.
  final String label;

  final IconData icon;

  const IssueCategory({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// The complaint taxonomy, matching the server's `category` enum exactly.
///
/// Kept in one place because the submission form, the feed filters, and the
/// admin queue all need the same list, and a category that exists in one but
/// not another silently drops complaints out of view.
abstract final class IssueCategories {
  static const List<IssueCategory> all = [
    IssueCategory(
      value: 'pothole',
      label: 'Pothole',
      icon: Icons.dangerous_outlined,
    ),
    IssueCategory(
      value: 'street_light',
      label: 'Street light',
      icon: Icons.lightbulb_outline,
    ),
    IssueCategory(
      value: 'water',
      label: 'Water supply',
      icon: Icons.water_drop_outlined,
    ),
    IssueCategory(
      value: 'electricity',
      label: 'Electricity',
      icon: Icons.bolt_outlined,
    ),
    IssueCategory(
      value: 'garbage',
      label: 'Garbage',
      icon: Icons.delete_outline,
    ),
    IssueCategory(
      value: 'road',
      label: 'Road damage',
      icon: Icons.add_road_outlined,
    ),
    IssueCategory(
      value: 'drainage',
      label: 'Drainage',
      icon: Icons.water_damage_outlined,
    ),
    IssueCategory(
      value: 'other',
      label: 'Other',
      icon: Icons.report_outlined,
    ),
  ];

  static const IssueCategory _fallback = IssueCategory(
    value: 'other',
    label: 'Other',
    icon: Icons.report_outlined,
  );

  static IssueCategory byValue(String value) {
    final needle = value.toLowerCase();
    for (final category in all) {
      if (category.value == needle) return category;
    }
    return _fallback;
  }

  static String labelFor(String value) => byValue(value).label;

  static IconData iconFor(String value) => byValue(value).icon;
}
