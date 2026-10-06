import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/resume_analysis.dart';
import '../providers/resume_providers.dart';

/// `resume_builder_home`/`resume_job_match`/`resume_reanalyze` all end up
/// rendering ONE of two possible pages at the SAME URL on the web (the
/// upload form, or the result) — there's no second route to navigate to
/// for the result, so this controller's state directly drives which body
/// `ResumeBuilderScreen` shows, rather than the screen navigating anywhere.
sealed class ResumeBuilderState {
  const ResumeBuilderState();
}

/// The upload form, optionally with an error from a previous failed
/// attempt (`resume_builder.html`'s `{% if error %}` block).
final class ResumeIdle extends ResumeBuilderState {
  const ResumeIdle([this.errorMessage]);
  final String? errorMessage;
}

/// `.loading-overlay` (`resume_builder.html:122-133`) — shown while the
/// upload/reanalyze request is in flight.
final class ResumeUploading extends ResumeBuilderState {
  const ResumeUploading();
}

final class ResumeResultState extends ResumeBuilderState {
  const ResumeResultState(this.result);
  final ResumeAnalysisResult result;
}

class ResumeBuilderController extends Notifier<ResumeBuilderState> {
  @override
  ResumeBuilderState build() => const ResumeIdle();

  Future<void> uploadAndAnalyze({required String filePath, required String fileName}) async {
    state = const ResumeUploading();
    final result = await ref
        .read(resumeRepositoryProvider)
        .uploadAndAnalyze(filePath: filePath, fileName: fileName);
    state = switch (result) {
      Success(value: final analysis) => ResumeResultState(analysis),
      Failed(failure: final failure) => ResumeIdle(failure.message),
    };
  }

  Future<void> reanalyze(int resumeId) async {
    state = const ResumeUploading();
    final result = await ref.read(resumeRepositoryProvider).reanalyze(resumeId);
    state = switch (result) {
      Success(value: final analysis) => ResumeResultState(analysis),
      Failed(failure: final failure) => ResumeIdle(failure.message),
    };
  }

  /// "Analyze Another Resume" (`resume_match_result.html:228-230`) — back
  /// to a clean upload form, same as navigating to `resume_builder`
  /// fresh on the web.
  void reset() => state = const ResumeIdle();
}
