import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/jam_assessment.dart';
import '../../domain/entities/jam_session_result.dart';
import '../providers/jam_providers.dart';

/// Fetches one past, already-completed session by id — used only when
/// reaching [JamResultScreen] from History (the live recording flow
/// already has the `JamSessionResult` in memory from `completeSession`
/// and doesn't need this). Uses the pure-read `jam:session_detail`
/// endpoint, **not** `completeSession` (which would mutate the session).
/// One instance per session id (`.family`).
class JamSessionDetailController extends AsyncNotifier<JamSessionResult> {
  JamSessionDetailController(this.sessionId);

  final int sessionId;

  @override
  Future<JamSessionResult> build() async {
    final result = await ref.read(jamHistoryRepositoryProvider).getSessionDetail(sessionId);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final jamSessionDetailControllerProvider =
    AsyncNotifierProvider.family<JamSessionDetailController, JamSessionResult, int>(
      JamSessionDetailController.new,
      retry: (retryCount, error) => null,
    );

/// Fetches one past, already-completed assessment by id — used only when
/// reaching [JamAssessmentResultScreen] from History. One instance per
/// assessment id (`.family`).
class JamAssessmentDetailController extends AsyncNotifier<JamAssessmentResult> {
  JamAssessmentDetailController(this.assessmentId);

  final int assessmentId;

  @override
  Future<JamAssessmentResult> build() async {
    final result = await ref.read(jamHistoryRepositoryProvider).getAssessmentResult(assessmentId);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final jamAssessmentDetailControllerProvider =
    AsyncNotifierProvider.family<JamAssessmentDetailController, JamAssessmentResult, int>(
      JamAssessmentDetailController.new,
      retry: (retryCount, error) => null,
    );
