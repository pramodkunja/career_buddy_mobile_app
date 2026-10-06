import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_session_summary.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/controllers/gd_history_controller.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/providers/gd_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../gd_test_doubles.dart';

void main() {
  group('GdHistoryController', () {
    test('resolves to the real sessions list from GdRepository.getSessions, in the order the API returned it', () async {
      final repo = FakeGdRepository(
        sessionsResult: const Success([
          GdSessionSummary(id: 2, topic: 'AI will replace human jobs', createdAt: '2026-09-20T10:00:00', isActive: false),
          GdSessionSummary(id: 1, topic: 'Work from home vs office', createdAt: '2026-09-10T10:00:00', isActive: true),
        ]),
      );
      final container = ProviderContainer(overrides: [gdRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      final sessions = await container.read(gdHistoryControllerProvider.future);

      expect(sessions.map((s) => s.id), [2, 1]); // preserved, never re-sorted client-side
      expect(sessions[1].isActive, isTrue);
    });

    test('surfaces the real failure on error', () async {
      final repo = FakeGdRepository(sessionsResult: const Failed(ServerFailure()));
      final container = ProviderContainer(overrides: [gdRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);

      Object? caught;
      try {
        await container.read(gdHistoryControllerProvider.future);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<ServerFailure>());
    });

    test('retry() re-invokes the repository', () async {
      final repo = FakeGdRepository();
      final container = ProviderContainer(overrides: [gdRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(container.dispose);
      await container.read(gdHistoryControllerProvider.future);

      await container.read(gdHistoryControllerProvider.notifier).retry();

      expect(container.read(gdHistoryControllerProvider), isA<AsyncData<List<GdSessionSummary>>>());
    });
  });
}
