/// JAM — "Just A Minute" workshop. Ported from `jam_app` (read in full:
/// `jam_app/urls.py`, `jam_app/views.py`, `jam_app/models.py`, and every
/// template under `templates/jam/`). See `ApiEndpoints`'s JAM doc comments
/// for the exact confirmed endpoint contracts and `jam_html_parser.dart`
/// for how the HTML-only responses are read.
///
/// The 3-stage Assessment flow (`AssessmentGroup`, `jam:start_assessment`/
/// `jam:assessment_session`/`jam:assessment_result`) — a separate
/// multi-session journey gated on the user having already completed one
/// practice topic at each difficulty (`get_jam_level_progress`), chaining
/// 3 `JAMSession`s together, and ending on its own result page
/// (`assessment_result.html`, `generate_final_assessment`) — is built on
/// top of the single-topic flow below rather than duplicating it: the same
/// `session.html` template (and so the same [JamSessionController] state
/// machine) renders each of the 3 stages, just with `is_assessment`/`stage`
/// context added (`parseJamAssessmentStageHtml`); only eligibility
/// (`JamAssessmentEligibilityController`), starting the group, and the
/// stage-chaining/final-report parsing (`JamAssessmentRepository`) are new
/// surfaces. See `JamAssessmentRepository`'s doc comment for why that's a
/// second repository interface rather than added methods on
/// [JamRepository].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../ai_speaking/data/services/audio_recorder_service_impl.dart';
import '../../../ai_speaking/domain/services/audio_recorder_service.dart';
import '../../data/jam_assessment_repository_impl.dart';
import '../../data/jam_history_repository_impl.dart';
import '../../data/jam_profile_repository_impl.dart';
import '../../data/jam_remote_datasource.dart';
import '../../data/jam_repository_impl.dart';
import '../../domain/entities/jam_assessment.dart';
import '../../domain/repositories/jam_assessment_repository.dart';
import '../../domain/repositories/jam_history_repository.dart';
import '../../domain/repositories/jam_profile_repository.dart';
import '../../domain/repositories/jam_repository.dart';
import '../controllers/jam_assessment_eligibility_controller.dart';
import '../controllers/jam_session_controller.dart';
import '../controllers/jam_topics_controller.dart';

final jamRemoteDataSourceProvider = Provider<JamRemoteDataSource>((ref) {
  return JamRemoteDataSource(ref.watch(apiClientProvider));
});

final jamRepositoryProvider = Provider<JamRepository>((ref) {
  return JamRepositoryImpl(ref.watch(jamRemoteDataSourceProvider));
});

/// See `JamAssessmentRepository`'s doc comment for why this is a separate
/// provider from [jamRepositoryProvider] rather than folded into it.
final jamAssessmentRepositoryProvider = Provider<JamAssessmentRepository>((ref) {
  return JamAssessmentRepositoryImpl(ref.watch(jamRemoteDataSourceProvider));
});

/// See `JamHistoryRepository`'s doc comment for why this is a separate
/// provider.
final jamHistoryRepositoryProvider = Provider<JamHistoryRepository>((ref) {
  return JamHistoryRepositoryImpl(ref.watch(jamRemoteDataSourceProvider));
});

/// See `JamProfileRepository`'s doc comment for why this is a separate
/// provider.
final jamProfileRepositoryProvider = Provider<JamProfileRepository>((ref) {
  return JamProfileRepositoryImpl(ref.watch(jamRemoteDataSourceProvider));
});

final jamTopicsControllerProvider = AsyncNotifierProvider<JamTopicsController, JamTopicsState>(
  JamTopicsController.new,
  retry: (retryCount, error) => null,
);

final jamAssessmentEligibilityControllerProvider =
    AsyncNotifierProvider<JamAssessmentEligibilityController, JamAssessmentEligibility>(
      JamAssessmentEligibilityController.new,
      retry: (retryCount, error) => null,
    );

final jamSessionControllerProvider = NotifierProvider<JamSessionController, JamSessionState>(
  JamSessionController.new,
);

/// Reuses `ai_speaking`'s generic recorder-service seam directly rather
/// than adding a second thin wrapper around `package:record` — see this
/// batch's task doc comment/report for confirmation this abstraction has no
/// AI-Speaking-specific coupling (it's purely "start/pause/resume/stop/
/// cancel a recording to a temp file"). A new instance per read, same
/// reasoning as `audioRecorderServiceProvider` in `ai_speaking_providers.dart`.
final jamAudioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  return AudioRecorderServiceImpl();
});
