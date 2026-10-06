import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_started_session.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/controllers/gd_session_controller.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/providers/gd_providers.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/screens/gd_topic_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../gd_test_doubles.dart';

Future<void> _pump(
  WidgetTester tester, {
  required FakeGdRepository repo,
  GdState? fixedState,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gdRepositoryProvider.overrideWithValue(repo),
        gdRealtimeServiceProvider.overrideWithValue(FakeGdRealtimeService()),
        gdSpeechServiceProvider.overrideWithValue(FakeGdSpeechService()),
        gdTtsServiceProvider.overrideWithValue(FakeGdTtsService()),
        apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio())),
        if (fixedState != null) gdSessionControllerProvider.overrideWith(() => FixedGdSessionController(fixedState)),
      ],
      child: const MaterialApp(home: GdTopicScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('GdTopicScreen', () {
    testWidgets('renders the suggested topics, a text field, and a Start button', (tester) async {
      await _pump(tester, repo: FakeGdRepository());

      expect(find.text('Group Discussion'), findsWidgets);
      expect(find.text('Social media is damaging society'), findsOneWidget);
      expect(find.text('AI will replace human jobs'), findsOneWidget);
      expect(find.text('Start Discussion'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('tapping a suggested topic calls create_session for that topic', (tester) async {
      final repo = FakeGdRepository()
        ..createResult = const Success(GdStartedSession(sessionId: 1, topic: 'AI will replace human jobs'));
      await _pump(tester, repo: repo);

      await tester.tap(find.text('AI will replace human jobs'));
      await tester.pump();

      expect(repo.createCallCount, 1);
    });

    testWidgets('shows the locked view when create_session is plan-gated (ForbiddenFailure)', (tester) async {
      await _pump(tester, repo: FakeGdRepository(), fixedState: const GdCreateFailed(ForbiddenFailure()));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text("You don't have permission to do that."), findsOneWidget);
      expect(find.text('View Plans'), findsOneWidget);
    });

    testWidgets('shows a retryable error view for a non-plan-gate failure', (tester) async {
      await _pump(tester, repo: FakeGdRepository(), fixedState: const GdCreateFailed(ServerFailure()));

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows a loader while creating/connecting', (tester) async {
      await _pump(tester, repo: FakeGdRepository(), fixedState: const GdCreatingSession());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
