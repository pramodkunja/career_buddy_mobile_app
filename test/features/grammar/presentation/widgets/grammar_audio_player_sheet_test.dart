import 'package:career_buddy_lms/features/grammar/presentation/providers/grammar_providers.dart';
import 'package:career_buddy_lms/features/grammar/presentation/widgets/grammar_audio_player_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../grammar_test_doubles.dart';

/// Unlike the image/video sheets, the real page's audio player has no
/// loading state to reproduce: `speakAudio()`'s browser-fallback path
/// (the only path this app's [GrammarTtsService] reproduces, see its doc
/// comment) starts speaking synchronously on open — a loading spinner only
/// ever appears on the neural-TTS-server path this app intentionally does
/// not reproduce. So this suite instead verifies the idle→playing
/// transition and the two real controls (Restart, Play/Pause/Resume).
void main() {
  group('GrammarAudioPlayerSheet', () {
    testWidgets('auto-plays the given audio text on open and shows the Pause/Restart controls', (tester) async {
      final tts = FakeGrammarTtsService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [grammarTtsServiceProvider.overrideWithValue(tts)],
          child: const MaterialApp(home: Scaffold(body: GrammarAudioPlayerSheet(audioText: 'Nouns are naming words.'))),
        ),
      );
      await tester.pump();

      expect(tts.spokenTexts, ['Nouns are naming words.']);
      expect(find.text('Nouns are naming words.'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('tapping Pause stops speech and swaps the label to Resume; tapping again resumes', (tester) async {
      final tts = FakeGrammarTtsService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [grammarTtsServiceProvider.overrideWithValue(tts)],
          child: const MaterialApp(home: Scaffold(body: GrammarAudioPlayerSheet(audioText: 'Nouns are naming words.'))),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(tts.stopCallCount, 1);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pump();

      expect(tts.spokenTexts, ['Nouns are naming words.', 'Nouns are naming words.']);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('tapping Restart re-speaks the same text from the top', (tester) async {
      final tts = FakeGrammarTtsService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [grammarTtsServiceProvider.overrideWithValue(tts)],
          child: const MaterialApp(home: Scaffold(body: GrammarAudioPlayerSheet(audioText: 'Nouns are naming words.'))),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Restart'));
      await tester.pump();

      expect(tts.spokenTexts, ['Nouns are naming words.', 'Nouns are naming words.']);
    });
  });
}
