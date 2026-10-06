import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/grammar/presentation/providers/grammar_providers.dart';
import 'package:career_buddy_lms/features/grammar/presentation/screens/grammar_detail_screen.dart';
import 'package:career_buddy_lms/features/grammar/presentation/widgets/grammar_audio_player_sheet.dart';
import 'package:career_buddy_lms/features/grammar/presentation/widgets/grammar_image_carousel_sheet.dart';
import 'package:career_buddy_lms/features/grammar/presentation/widgets/grammar_video_player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../grammar_test_doubles.dart';

/// The real, JSON-asset-backed "Nouns" topic (`assets/data/grammar_data.json`)
/// is used directly (via the real [grammarDataSourceProvider]) rather than a
/// fake, so every assertion below is against real ported copy — only the
/// two network-backed media providers are overridden.
const _slug = 'noun';

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.grammarTopic(_slug),
  routes: [
    GoRoute(
      path: RoutePaths.grammarTopicPattern,
      builder: (context, state) => GrammarDetailScreen(slug: state.pathParameters['slug']!),
    ),
    GoRoute(path: RoutePaths.grammar, builder: (context, state) => const Scaffold(body: Text('Grammar Index Screen'))),
  ],
);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeGrammarMediaDataSource media,
  required FakeGrammarTtsService tts,
}) async {
  tester.view.physicalSize = const Size(400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      grammarMediaDataSourceProvider.overrideWithValue(media),
      grammarTtsServiceProvider.overrideWithValue(tts),
    ],
  );
  addTearDown(container.dispose);

  // `grammarTopicDetailProvider` reads the real bundled JSON asset via
  // `rootBundle.loadString` — a genuine async platform-message round trip
  // that a plain `tester.pump()` loop never resolves inside `testWidgets`'
  // fake-async zone. Pre-warming it via `runAsync` (a real event-loop turn)
  // before `pumpWidget` means the widget tree sees `AsyncData` on its very
  // first build, same as `GrammarIndexScreen`'s equivalent tests would need.
  await tester.runAsync(() => container.read(grammarTopicDetailProvider(_slug).future));

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())));
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  final originalVideoPlatform = VideoPlayerPlatform.instance;
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());
  tearDown(() => VideoPlayerPlatform.instance = originalVideoPlatform);

  group('GrammarDetailScreen', () {
    testWidgets('renders the real topic title, definition, and lesson slide', (tester) async {
      await _pump(tester, media: FakeGrammarMediaDataSource(), tts: FakeGrammarTtsService());

      expect(find.text('Nouns'), findsOneWidget);
      expect(
        find.text(
          'A noun is a naming word. It names a person, place, thing, idea, feeling, or quality, and it helps us identify what a sentence is talking about.',
        ),
        findsOneWidget,
      );
      expect(find.text('Back to Subject Library'), findsOneWidget);
      expect(find.text('Why learning nouns is important'), findsOneWidget);
      expect(find.text('1. Spot the Naming Words'), findsOneWidget);
    });

    testWidgets('renders the summary table with its hardcoded headers and real rows', (tester) async {
      await _pump(tester, media: FakeGrammarMediaDataSource(), tts: FakeGrammarTtsService());

      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Definition'), findsOneWidget);
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('Common Noun'), findsOneWidget);
    });

    testWidgets('renders a dynamic exercises section with both question and answer visible, no toggle', (tester) async {
      await _pump(tester, media: FakeGrammarMediaDataSource(), tts: FakeGrammarTtsService());

      final questionFinder = find.text('Q: Q1. Identify the noun: The baby laughed loudly.');
      await tester.scrollUntilVisible(questionFinder, 300, scrollable: find.byType(Scrollable).first);
      expect(questionFinder, findsOneWidget);

      // The answer is directly rendered too — confirmed there is no
      // "Show Answer" reveal control anywhere in the real page's markup.
      expect(find.textContaining('baby', findRichText: true), findsWidgets);
      expect(find.text('Show Answer'), findsNothing);
      expect(find.text('Reveal Answer'), findsNothing);
    });

    testWidgets('tapping the Visual Guide card opens the image carousel sheet', (tester) async {
      final media = FakeGrammarMediaDataSource();
      await _pump(tester, media: media, tts: FakeGrammarTtsService());

      await tester.tap(find.text('Visual Guide'));
      await tester.pump();

      expect(find.byType(GrammarImageCarouselSheet), findsOneWidget);
      expect(find.text('Presentation Slides'), findsOneWidget);
    });

    testWidgets('tapping the Video Lesson card opens the video player sheet', (tester) async {
      final media = FakeGrammarMediaDataSource();
      await _pump(tester, media: media, tts: FakeGrammarTtsService());

      await tester.tap(find.text('Video Lesson'));
      await tester.pump();

      expect(find.byType(GrammarVideoPlayerSheet), findsOneWidget);
      await _pumpUntilFound(tester, find.text('Video Lesson').last);
      expect(media.fetchVideoCallCount, 1);
    });

    testWidgets('tapping the Audio Recap card opens the audio player sheet and speaks the real audio text', (tester) async {
      final tts = FakeGrammarTtsService();
      await _pump(tester, media: FakeGrammarMediaDataSource(), tts: tts);

      await tester.tap(find.text('Audio Recap'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GrammarAudioPlayerSheet), findsOneWidget);
      expect(tts.spokenTexts, isNotEmpty);
      expect(tts.spokenTexts.first, startsWith('Nouns are naming words.'));
    });
  });
}
