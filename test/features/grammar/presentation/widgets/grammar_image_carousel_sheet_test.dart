import 'dart:async';

import 'package:career_buddy_lms/features/grammar/presentation/providers/grammar_providers.dart';
import 'package:career_buddy_lms/features/grammar/presentation/widgets/grammar_image_carousel_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../grammar_test_doubles.dart';

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  group('GrammarImageCarouselSheet', () {
    testWidgets('shows a loading indicator while the slide deck is still being fetched', (tester) async {
      final media = FakeGrammarMediaDataSource()..slideImageGate = Completer<void>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [grammarMediaDataSourceProvider.overrideWithValue(media)],
          child: const MaterialApp(home: Scaffold(body: GrammarImageCarouselSheet(slug: 'noun'))),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      media.slideImageGate!.complete();
      await tester.pump();
    });

    testWidgets('renders every real slide image once the fetch resolves, with prev/next controls', (tester) async {
      final media = FakeGrammarMediaDataSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [grammarMediaDataSourceProvider.overrideWithValue(media)],
          child: const MaterialApp(home: Scaffold(body: GrammarImageCarouselSheet(slug: 'noun'))),
        ),
      );

      await _pumpUntilFound(tester, find.byType(Image));

      // `noun` has 14 real slide PNGs (`kGrammarSlideDeckCounts`), fetched
      // as `01.png`..`14.png`.
      expect(media.requestedSlideFileNames, hasLength(14));
      expect(media.requestedSlideFileNames.first, '01.png');
      expect(media.requestedSlideFileNames.last, '14.png');
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // `warnIfMissed: false` — the `AnimatedSwitcher`-faded outgoing slide
      // briefly overlaps the button's hit-test area during the crossfade;
      // harmless in a real app (the button still receives the tap), just
      // noisy under the test binding's stricter hit-test warning.
      await tester.tap(find.byIcon(Icons.chevron_right), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    });
  });
}
