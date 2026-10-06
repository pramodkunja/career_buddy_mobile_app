import 'dart:async';

import 'package:career_buddy_lms/features/grammar/presentation/providers/grammar_providers.dart';
import 'package:career_buddy_lms/features/grammar/presentation/widgets/grammar_video_player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../grammar_test_doubles.dart';

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  final originalPlatform = VideoPlayerPlatform.instance;
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());
  tearDown(() => VideoPlayerPlatform.instance = originalPlatform);

  group('GrammarVideoPlayerSheet', () {
    testWidgets('shows a loading indicator while the video is still downloading', (tester) async {
      final media = FakeGrammarMediaDataSource()..videoGate = Completer<void>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [grammarMediaDataSourceProvider.overrideWithValue(media)],
          child: const MaterialApp(home: Scaffold(body: GrammarVideoPlayerSheet(slug: 'noun'))),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(VideoPlayer), findsNothing);

      media.videoGate!.complete();
      await tester.pump();
    });

    testWidgets('renders the video player once the download and platform init resolve', (tester) async {
      final media = FakeGrammarMediaDataSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [grammarMediaDataSourceProvider.overrideWithValue(media)],
          child: const MaterialApp(home: Scaffold(body: GrammarVideoPlayerSheet(slug: 'noun'))),
        ),
      );

      await _pumpUntilFound(tester, find.byType(VideoPlayer));

      expect(media.fetchVideoCallCount, 1);
      expect(find.byType(VideoProgressIndicator), findsOneWidget);
    });
  });
}
