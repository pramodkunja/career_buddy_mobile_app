import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_message.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_speaker.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_started_session.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_ws_event.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/controllers/gd_session_controller.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/providers/gd_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/screens/gd_discussion_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../gd_test_doubles.dart';

const _session = GdStartedSession(sessionId: 5, topic: 'AI will replace human jobs');

GdMessage _message({required GdSpeaker speaker, required String name, required String content, bool isUser = false}) {
  return GdMessage(
    speaker: speaker,
    speakerName: name,
    avatar: '🔵',
    colorHex: '#4F8EF7',
    content: content,
    isUser: isUser,
    receivedAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pump(WidgetTester tester, GdState state, {FakeGdRealtimeService? realtime, Size? physicalSize}) async {
  if (physicalSize != null) {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gdRealtimeServiceProvider.overrideWithValue(realtime ?? FakeGdRealtimeService()),
        gdSpeechServiceProvider.overrideWithValue(FakeGdSpeechService()),
        gdTtsServiceProvider.overrideWithValue(FakeGdTtsService()),
        apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio())),
        gdSessionControllerProvider.overrideWith(() => FixedGdSessionController(state)),
      ],
      child: const MaterialApp(home: GdDiscussionScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('GdDiscussionScreen', () {
    testWidgets('renders incoming agent and user messages in the transcript', (tester) async {
      final state = GdLive(
        session: _session,
        messages: [
          _message(speaker: GdSpeaker.rishi, name: 'Rishi', content: 'Welcome everyone!'),
          _message(speaker: GdSpeaker.user, name: 'You', content: 'I think so too.', isUser: true),
        ],
        typingSpeaker: null,
        micState: GdMicState.idle,
      );

      await _pump(tester, state);

      expect(find.text('Welcome everyone!'), findsOneWidget);
      expect(find.text('I think so too.'), findsOneWidget);
      expect(find.text('Rishi'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('shows the typing indicator when an agent is about to speak', (tester) async {
      const state = GdLive(
        session: _session,
        messages: [],
        typingSpeaker: GdTypingEvent(speaker: GdSpeaker.alex, speakerName: 'Alex', avatar: '🔵', colorHex: '#4F8EF7'),
        micState: GdMicState.idle,
      );

      await _pump(tester, state);

      expect(find.text('Alex is typing...'), findsOneWidget);
    });

    testWidgets('shows the "Speak Now" mic control when idle', (tester) async {
      const idleState = GdLive(session: _session, messages: [], typingSpeaker: null, micState: GdMicState.idle);
      await _pump(tester, idleState);

      expect(find.text('Speak Now'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('shows "Done Speaking" while the mic is listening', (tester) async {
      const listeningState = GdLive(session: _session, messages: [], typingSpeaker: null, micState: GdMicState.listening);
      await _pump(tester, listeningState);

      expect(find.text('Done Speaking'), findsOneWidget);
    });

    testWidgets('shows a connection-lost state with a reconnect action, never a silent hang', (tester) async {
      final state = GdConnectionLost(session: _session, messages: const []);

      await _pump(tester, state);

      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
    });

    testWidgets('tapping Reconnect calls connect() again', (tester) async {
      final realtime = FakeGdRealtimeService();
      final state = GdConnectionLost(session: _session, messages: const []);

      await _pump(tester, state, realtime: realtime);
      await tester.tap(find.text('Reconnect'));
      await tester.pump();

      expect(realtime.connectCallCount, 1);
    });

    testWidgets('shows an analyzing loader while ending', (tester) async {
      final state = GdEnding(session: _session, messages: const []);

      await _pump(tester, state);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Analyzing the discussion...'), findsOneWidget);
    });
  });

  group('Batch 9 responsive QA', () {
    for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915), Size(430, 932)]) {
      testWidgets('transcript + typing + mic control render without overflow at ${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        final state = GdLive(
          session: _session,
          messages: [
            _message(speaker: GdSpeaker.rishi, name: 'Rishi', content: 'Welcome everyone! Let\'s discuss whether AI will replace human jobs.'),
            _message(speaker: GdSpeaker.user, name: 'You', content: 'I think automation will shift jobs rather than eliminate them entirely.', isUser: true),
            _message(speaker: GdSpeaker.alex, name: 'Alex', content: 'That is a fair point, but consider the pace of change across industries.'),
          ],
          typingSpeaker: const GdTypingEvent(speaker: GdSpeaker.maya, speakerName: 'Maya', avatar: '🟢', colorHex: '#22C55E'),
          micState: GdMicState.listening,
        );

        await _pump(tester, state, physicalSize: size);

        expect(tester.takeException(), isNull);
      });
    }
  });
}
