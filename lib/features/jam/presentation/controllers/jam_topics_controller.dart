import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/jam_topic.dart';
import '../providers/jam_providers.dart';

/// `jam:topics`' 3 sections, bucketed exactly like `topics.html` itself —
/// `easy`/`medium`/`hard`.
class JamTopicsState {
  const JamTopicsState({required this.easy, required this.medium, required this.hard});

  final List<JamTopic> easy;
  final List<JamTopic> medium;
  final List<JamTopic> hard;
}

/// `AsyncNotifier`, same reasoning as `ResumeHistoryController` — nothing
/// here needs a bespoke state machine beyond loading/data/error/retry.
class JamTopicsController extends AsyncNotifier<JamTopicsState> {
  @override
  Future<JamTopicsState> build() async {
    final result = await ref.read(jamRepositoryProvider).getTopics();
    return switch (result) {
      Success(value: final topics) => JamTopicsState(
        easy: [for (final t in topics) if (t.difficulty == 'easy') t],
        medium: [for (final t in topics) if (t.difficulty == 'medium') t],
        hard: [for (final t in topics) if (t.difficulty == 'hard') t],
      ),
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}
