import '../models/issue.dart';

/// Where a complaint stands against its response deadline.
enum SlaState {
  /// Work is finished — the clock no longer applies.
  closed,

  /// Inside the response window.
  onTrack,

  /// Inside the window, but with a day or less left.
  dueSoon,

  /// Past the response deadline.
  overdue,
}

/// A complaint's position against its response deadline, ready to render.
class Sla {
  final SlaState state;

  /// Whole days remaining (positive) or elapsed past the deadline (positive,
  /// with [state] set to [SlaState.overdue]).
  final int days;

  /// Short text for a card row, e.g. `Due in 2 days` or `Overdue by 3 days`.
  final String label;

  const Sla({required this.state, required this.days, required this.label});

  bool get isOverdue => state == SlaState.overdue;
  bool get isClosed => state == SlaState.closed;
}

/// Response windows per category, in days.
///
/// Mirrors `server/config/sla.js`, which is authoritative — these values are
/// consulted only for payloads that arrive without a `due_at`. Change one and
/// you must change the other; `server/test/sla.test.js` guards the pairing.
///
/// These mirror the tiering municipal bodies already use: anything that is a
/// live safety or supply failure gets a short window, wear-and-tear gets a
/// long one. Adjust the numbers to match whichever corporation you are
/// pitching — they are policy, not physics.
abstract final class SlaPolicy {
  static const Map<String, int> _windowDays = {
    'water': 2,
    'electricity': 2,
    'street_light': 3,
    'garbage': 3,
    'drainage': 5,
    'pothole': 7,
    'road': 10,
    'other': 7,
  };

  static const int _defaultWindowDays = 7;

  /// The response window for a category, in days.
  static int windowFor(String category) =>
      _windowDays[category.toLowerCase()] ?? _defaultWindowDays;

  /// The deadline this complaint is measured against.
  ///
  /// Prefers the server's computed value — `server/config/sla.js` is the source
  /// of truth, so the citizen app and the municipal dashboard cannot disagree
  /// about what is late. The local table is the offline fallback.
  static DateTime dueDate(Issue issue) =>
      issue.dueAt ??
      issue.createdAt.add(Duration(days: windowFor(issue.category)));

  /// Evaluates a complaint against its deadline.
  ///
  /// [now] is injectable so the widget tests can pin the clock.
  static Sla evaluate(Issue issue, {DateTime? now}) {
    final status = issue.status.toLowerCase();
    if (status == 'resolved' || status == 'rejected') {
      return const Sla(state: SlaState.closed, days: 0, label: '');
    }

    final clock = now ?? DateTime.now();
    final due = dueDate(issue);
    final remaining = due.difference(clock);

    if (remaining.isNegative) {
      final late = remaining.abs().inDays;
      return Sla(
        state: SlaState.overdue,
        days: late,
        label: late == 0
            ? 'Overdue today'
            : 'Overdue by $late ${_plural(late, 'day')}',
      );
    }

    final left = remaining.inDays;
    if (left <= 1) {
      return Sla(
        state: SlaState.dueSoon,
        days: left,
        label: left == 0 ? 'Due today' : 'Due tomorrow',
      );
    }

    return Sla(
      state: SlaState.onTrack,
      days: left,
      label: 'Due in $left ${_plural(left, 'day')}',
    );
  }

  static String _plural(int n, String word) => n == 1 ? word : '${word}s';
}
