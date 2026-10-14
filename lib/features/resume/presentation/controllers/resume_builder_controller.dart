import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/resume_analysis.dart';
import '../../domain/repositories/resume_repository.dart' show ResumeParseQuota, ResumeRoleSelection;
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
  const ResumeIdle([this.errorMessage, this.parseQuota, this.targetRole]);
  final String? errorMessage;

  /// `null` until [ResumeBuilderController.loadParseQuota] resolves, or
  /// whenever it couldn't be read (paid plan, fetch failure) — the screen
  /// simply shows no counter in that case, never a guessed one.
  final ResumeParseQuota? parseQuota;

  /// `null` until [ResumeBuilderController.setTargetRole] is called with a
  /// server-confirmed selection (Phase 23's role-fit picker) — never set
  /// from a mere UI tap, only from what the server actually echoed back.
  final ResumeRoleSelection? targetRole;
}

/// `.loading-overlay` (`resume_builder.html:122-133`) — shown while the
/// upload/reanalyze request is in flight.
final class ResumeUploading extends ResumeBuilderState {
  const ResumeUploading([this.parseQuota, this.targetRole]);
  final ResumeParseQuota? parseQuota;
  final ResumeRoleSelection? targetRole;
}

final class ResumeResultState extends ResumeBuilderState {
  const ResumeResultState(this.result, [this.targetRole]);
  final ResumeAnalysisResult result;

  /// Carried through from whichever role (if any) was selected before this
  /// analysis ran — the result view itself has no use for it, but [reset]
  /// needs to recover it afterwards; see [reset]'s own doc comment for why
  /// a successful analysis must not silently drop it.
  final ResumeRoleSelection? targetRole;
}

class ResumeBuilderController extends Notifier<ResumeBuilderState> {
  @override
  ResumeBuilderState build() => const ResumeIdle();

  Future<void> uploadAndAnalyze({required String filePath, required String fileName}) async {
    final quota = _currentQuota();
    final role = _currentTargetRole();
    state = ResumeUploading(quota, role);
    final result = await ref
        .read(resumeRepositoryProvider)
        .uploadAndAnalyze(filePath: filePath, fileName: fileName);
    state = switch (result) {
      Success(value: final analysis) => ResumeResultState(analysis, role),
      Failed(failure: final failure) => ResumeIdle(failure.message, quota, role),
    };
  }

  Future<void> reanalyze(int resumeId) async {
    final quota = _currentQuota();
    final role = _currentTargetRole();
    state = ResumeUploading(quota, role);
    final result = await ref.read(resumeRepositoryProvider).reanalyze(resumeId);
    state = switch (result) {
      Success(value: final analysis) => ResumeResultState(analysis, role),
      Failed(failure: final failure) => ResumeIdle(failure.message, quota, role),
    };
  }

  /// "Analyze Another Resume" (`resume_match_result.html:228-230`) — back
  /// to a clean upload form, same as navigating to `resume_builder`
  /// fresh on the web. The quota is deliberately not carried over here —
  /// an analysis was just completed, so the old count is stale; the fresh
  /// `_UploadForm` this returns to calls [loadParseQuota] again on mount.
  /// [targetRole] **is** carried over, unlike the quota: it reflects
  /// `request.session['rb_role']`, which the server does not clear between
  /// analyses — showing "no target role" here while the server would still
  /// silently apply one to the next analysis would be a false display, not
  /// a reset.
  void reset() => state = ResumeIdle(null, null, _currentTargetRole());

  /// Called once when the upload screen's form mounts (see
  /// `ResumeBuilderScreen`'s `_UploadFormState.initState`) — also exactly
  /// when it remounts fresh after [reset], which is what keeps the
  /// displayed count from going stale after a completed analysis. A
  /// result already showing (or a different one now showing, if this
  /// resolves late) is left alone; this only ever updates the idle/
  /// uploading state it's relevant to.
  Future<void> loadParseQuota() async {
    final quota = await ref.read(resumeRepositoryProvider).getParseQuota();
    state = switch (state) {
      ResumeIdle(errorMessage: final err, targetRole: final role) => ResumeIdle(err, quota, role),
      ResumeUploading(targetRole: final role) => ResumeUploading(quota, role),
      ResumeResultState() => state,
    };
  }

  /// Called by the role-picker screen once it returns a server-confirmed
  /// selection (see `RolePickerScreen`'s own doc comment) — this method
  /// itself makes no network call; the confirmation already happened
  /// inside the picker's own flow (`ResumeRemoteDataSource.selectTargetRole`).
  void setTargetRole(ResumeRoleSelection role) {
    final quota = _currentQuota();
    state = switch (state) {
      ResumeIdle(errorMessage: final err) => ResumeIdle(err, quota, role),
      ResumeUploading() => ResumeUploading(quota, role),
      ResumeResultState(result: final result) => ResumeResultState(result, role),
    };
  }

  ResumeParseQuota? _currentQuota() => switch (state) {
    ResumeIdle(parseQuota: final quota) => quota,
    ResumeUploading(parseQuota: final quota) => quota,
    ResumeResultState() => null,
  };

  ResumeRoleSelection? _currentTargetRole() => switch (state) {
    ResumeIdle(targetRole: final role) => role,
    ResumeUploading(targetRole: final role) => role,
    ResumeResultState(targetRole: final role) => role,
  };
}
