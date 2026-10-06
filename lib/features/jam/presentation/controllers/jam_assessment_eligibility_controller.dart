import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/jam_assessment.dart';
import '../providers/jam_providers.dart';

/// Drives the "Start Assessment" entry point's enabled/disabled state on
/// [JamTopicsScreen] — fetches `jam:history` and reproduces
/// `get_jam_level_progress` client-side (`computeJamAssessmentEligibility`).
/// `AsyncNotifier`, same reasoning as `JamTopicsController`: nothing here
/// needs a bespoke state machine beyond loading/data/error/retry.
class JamAssessmentEligibilityController extends AsyncNotifier<JamAssessmentEligibility> {
  @override
  Future<JamAssessmentEligibility> build() async {
    final result = await ref.read(jamAssessmentRepositoryProvider).getHistory();
    return switch (result) {
      Success(value: final sessions) => computeJamAssessmentEligibility(sessions),
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}
