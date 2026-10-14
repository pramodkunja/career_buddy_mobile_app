import 'package:career_buddy_lms/features/home/presentation/widgets/home_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// REGRESSION (Phase 21) — the new unified hero
/// (`landing.html:6536-6588`), tested in isolation from the rest of
/// `HomeScreen` (notably the pre-existing `PortalCard`, which has its own
/// unrelated overflow at 320px — see `home_screen_test.dart`'s responsive
/// group for why that's excluded there, not here).
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('HomeHero', () {
    testWidgets('renders the headline and all 3 CTA labels', (tester) async {
      await tester.pumpWidget(
        _wrap(HomeHero(onGetStarted: () {}, onFindJobs: () {}, onCreateResume: () {})),
      );

      expect(find.text('Build skills. Craft capability. Claim your career.'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Find Jobs'), findsOneWidget);
      expect(find.text('Create Resume'), findsOneWidget);
    });

    testWidgets('invokes the correct callback for each CTA, independently', (tester) async {
      var getStartedCount = 0;
      var findJobsCount = 0;
      var createResumeCount = 0;
      await tester.pumpWidget(
        _wrap(
          HomeHero(
            onGetStarted: () => getStartedCount++,
            onFindJobs: () => findJobsCount++,
            onCreateResume: () => createResumeCount++,
          ),
        ),
      );

      await tester.tap(find.text('Get Started'));
      await tester.tap(find.text('Find Jobs'));
      await tester.tap(find.text('Find Jobs'));
      await tester.tap(find.text('Create Resume'));

      expect(getStartedCount, 1);
      expect(findJobsCount, 2);
      expect(createResumeCount, 1);
    });

    testWidgets('renders without horizontal overflow at every target width, including the narrowest (320px)', (
      tester,
    ) async {
      for (final size in [const Size(320, 700), const Size(360, 700), const Size(390, 700), const Size(430, 700)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(HomeHero(onGetStarted: () {}, onFindJobs: () {}, onCreateResume: () {})),
        );

        expect(tester.takeException(), isNull);
      }
    });
  });
}
