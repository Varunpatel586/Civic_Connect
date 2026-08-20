// Replaces the generated counter-app smoke test, which tested a widget tree
// this app has never had. `MyApp` cannot be pumped directly because `main()`
// loads `.env` and kicks off location work first, so the theme is exercised
// here instead — it is the piece every screen depends on.

import 'package:civic_connect/theme/app_colors.dart';
import 'package:civic_connect/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('theme builds without throwing', () {
    expect(AppTheme.light(), isA<ThemeData>());
  });

  test('navy carries the primary role', () {
    expect(AppTheme.light().colorScheme.primary, AppColors.navy900);
  });

  test('amber is the accent, not the primary', () {
    final scheme = AppTheme.light().colorScheme;

    expect(scheme.secondary, AppColors.amber700);
    expect(scheme.primary, isNot(AppColors.amber700));
  });

  test('surfaces are separated by hairlines, not elevation', () {
    final theme = AppTheme.light();

    expect(theme.cardTheme.elevation, 0);
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
  });

  testWidgets('scaffolds paint the canvas colour', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SizedBox()),
      ),
    );

    final scaffold = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(scaffold.color, AppColors.canvas);
  });
}
