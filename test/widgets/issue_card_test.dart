import 'package:civic_connect/models/issue.dart';
import 'package:civic_connect/providers/app_provider.dart';
import 'package:civic_connect/theme/app_colors.dart';
import 'package:civic_connect/theme/app_theme.dart';
import 'package:civic_connect/widgets/issue_card.dart';
import 'package:civic_connect/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

Issue _issue({
  String category = 'pothole',
  String status = 'Pending',
  DateTime? createdAt,
  String? address = 'Ring Road, Ahmedabad, 380015, Gujarat, India',
  int agreeCount = 34,
  int disagreeCount = 2,
  String? userVote,
}) {
  final filed = createdAt ?? DateTime.now().subtract(const Duration(days: 1));
  return Issue(
    id: '66bc2e2a0f8b1c4d4b123457',
    userId: 'u1',
    title: 'Severe pothole on Ring Road',
    description: 'Large pothole in the middle lane causing cars to swerve.',
    category: category,
    imageUrl: 'http://example.test/pothole.jpg',
    latitude: 23.03,
    longitude: 72.58,
    timestamp: filed,
    createdAt: filed,
    status: status,
    address: address,
    agreeCount: agreeCount,
    disagreeCount: disagreeCount,
    userVote: userVote,
  );
}

Future<void> _pumpCard(WidgetTester tester, Issue issue) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(child: IssueCard(issue: issue)),
        ),
      ),
    ),
  );
  // Not pumpAndSettle: the image placeholder spins indefinitely offline.
  await tester.pump();
}

void main() {
  setUpAll(() {
    // Keep the suite offline and deterministic.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows the complaint title and category', (tester) async {
    await _pumpCard(tester, _issue());

    expect(find.text('Severe pothole on Ring Road'), findsOneWidget);
    expect(find.text('POTHOLE'), findsOneWidget);
  });

  testWidgets('shows a quotable complaint reference', (tester) async {
    await _pumpCard(tester, _issue());

    expect(find.text('CC-2026-GJ-93047'), findsOneWidget);
  });

  testWidgets('shows the locality parsed out of the address', (tester) async {
    await _pumpCard(tester, _issue());

    expect(find.text('Ahmedabad'), findsOneWidget);
  });

  testWidgets('says so plainly when no address was recorded', (tester) async {
    await _pumpCard(tester, _issue(address: null));

    expect(find.text('Location unrecorded'), findsOneWidget);
  });

  testWidgets('renders the status badge', (tester) async {
    await _pumpCard(tester, _issue(status: 'In Progress'));

    expect(find.text('IN PROGRESS'), findsOneWidget);
  });

  testWidgets('shows the SLA countdown while inside the window', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _issue(
        category: 'pothole', // 7 day window
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    );

    expect(find.textContaining('Due in'), findsOneWidget);
  });

  testWidgets('overrides the badge to OVERDUE once past the deadline', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _issue(
        category: 'water', // 2 day window
        status: 'Pending',
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
    );

    expect(find.text('OVERDUE'), findsOneWidget);
    expect(find.text('PENDING'), findsNothing);
    expect(find.textContaining('Overdue by'), findsOneWidget);
  });

  testWidgets('an overdue card is tinted so it cannot be scrolled past', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _issue(
        category: 'water',
        createdAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
    );

    final tinted = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.color == StatusColors.overdue.background);

    expect(tinted, isNotEmpty);
  });

  testWidgets('a resolved complaint shows no countdown', (tester) async {
    await _pumpCard(
      tester,
      _issue(
        status: 'Resolved',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
    );

    expect(find.text('RESOLVED'), findsOneWidget);
    expect(find.textContaining('Overdue'), findsNothing);
    expect(find.textContaining('Due in'), findsNothing);
  });

  testWidgets('shows both vote tallies', (tester) async {
    await _pumpCard(tester, _issue(agreeCount: 34, disagreeCount: 2));

    expect(find.text('34'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('offers the three citizen actions', (tester) async {
    await _pumpCard(tester, _issue());

    expect(find.text('Agree'), findsOneWidget);
    expect(find.text('Disagree'), findsOneWidget);
    expect(find.text('Discuss'), findsOneWidget);
  });

  testWidgets('hides the actions when asked to', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: IssueCard(issue: _issue(), showActions: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Agree'), findsNothing);
  });

  group('StatusChip', () {
    Future<void> pumpChip(WidgetTester tester, Widget chip) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Center(child: chip)),
        ),
      );
      await tester.pump();
    }

    testWidgets('uppercases the status', (tester) async {
      await pumpChip(tester, const StatusChip(status: 'In Progress'));
      expect(find.text('IN PROGRESS'), findsOneWidget);
    });

    testWidgets('an unknown status still renders rather than blanking', (
      tester,
    ) async {
      await pumpChip(tester, const StatusChip(status: 'Escalated'));
      expect(find.text('ESCALATED'), findsOneWidget);
    });

    testWidgets('overdue wins over the stored status', (tester) async {
      await pumpChip(
        tester,
        const StatusChip(status: 'Pending', overdue: true),
      );
      expect(find.text('OVERDUE'), findsOneWidget);
    });
  });

  group('palette', () {
    test('every complaint state maps to a distinct foreground', () {
      final foregrounds = {
        StatusColors.pending.foreground,
        StatusColors.inProgress.foreground,
        StatusColors.resolved.foreground,
        StatusColors.rejected.foreground,
        StatusColors.overdue.foreground,
      };

      expect(foregrounds.length, 5);
    });

    test('an unrecognised status falls back rather than rendering colourless', () {
      expect(StatusColors.forStatus('nonsense'), StatusColors.pending);
    });

    test('status lookup ignores case', () {
      expect(StatusColors.forStatus('RESOLVED'), StatusColors.resolved);
      expect(StatusColors.forStatus('in progress'), StatusColors.inProgress);
    });

    test('amber is reserved for time pressure alone', () {
      // Guards the one rule that keeps the palette readable at a glance: if
      // amber ever becomes a status colour, the SLA signal stops meaning
      // anything.
      final statusColors = [
        StatusColors.pending,
        StatusColors.inProgress,
        StatusColors.resolved,
        StatusColors.rejected,
      ];

      for (final palette in statusColors) {
        expect(palette.foreground, isNot(AppColors.amber700));
      }
    });
  });
}
