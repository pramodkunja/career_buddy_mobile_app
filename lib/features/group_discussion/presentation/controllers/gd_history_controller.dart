import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/gd_session_summary.dart';
import '../providers/gd_providers.dart';

/// Batch 10 — `GD_app:api_sessions` already existed at the data layer
/// since Batch 9 (built, tested, unused by any screen) — this is the
/// controller for the History screen that finally surfaces it. Plain
/// `AsyncNotifier`: nothing here needs a bespoke state machine beyond
/// loading/data/error/retry, same reasoning as `JamTopicsController`.
class GdHistoryController extends AsyncNotifier<List<GdSessionSummary>> {
  @override
  Future<List<GdSessionSummary>> build() async {
    final result = await ref.read(gdRepositoryProvider).getSessions();
    return switch (result) {
      Success(value: final sessions) => sessions,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final gdHistoryControllerProvider = AsyncNotifierProvider<GdHistoryController, List<GdSessionSummary>>(
  GdHistoryController.new,
  // Explicit-retry, not silent-backoff — same established convention as
  // `JamAssessmentEligibilityController`'s own provider.
  retry: (retryCount, error) => null,
);
