import '../../../../core/utils/result.dart';
import '../entities/resume_analysis.dart';
import '../entities/resume_history_item.dart';
import '../entities/resume_role.dart';

/// `resume_builder_home`'s Free-plan usage badge (`resume_builder.html:
/// 191-195`) — `left` is `parses_left`, `limit` is `parse_limit`. Never
/// constructed from local upload history; always the server's own count
/// for this exact request.
typedef ResumeParseQuota = ({int left, int limit});

/// A role selection the server has already confirmed (via the "Target
/// role" badge, see `resume_html_parser.dart`'s `parseTargetRoleBadge` doc
/// comment) — `role`/`dept` are exactly [ResumeRole.title]/
/// [ResumeRole.subtitle] as echoed back, not re-derived locally.
typedef ResumeRoleSelection = ({String role, String dept});

abstract class ResumeRepository {
  Future<Result<ResumeAnalysisResult>> uploadAndAnalyze({
    required String filePath,
    required String fileName,
  });

  Future<Result<ResumeAnalysisResult>> reanalyze(int resumeId);

  Future<Result<List<ResumeHistoryItem>>> getHistory();

  /// Best-effort read of the Free-plan analyses-remaining badge off
  /// `resume_builder_home`'s own page. `null` whenever the count isn't
  /// available — a paid plan (the badge is server-omitted entirely), a
  /// failed request, or unexpected page markup — never a [Result]/[Failed]:
  /// a missing count is not an error condition for this screen, it's a
  /// normal, expected outcome for most users.
  Future<ResumeParseQuota?> getParseQuota();

  /// `manual_resume_roles` (Phase 22's "Option B" catalog) — unlike
  /// [getParseQuota], a genuine [Result]: an empty or failed catalog is
  /// something the role-picker screen must show as a real, retryable
  /// error/empty state, not silently hide.
  Future<Result<List<ResumeRole>>> getRoles();

  /// Sets `request.session['rb_role']` via `resume_builder_home`'s own
  /// `?role=&dept=&track=` mechanism (confirmed directly,
  /// `career_app/views.py`'s `_remember_target_role`) — the exact
  /// mechanism the real landing page's role-picker modal uses, never a
  /// dedicated new endpoint. A [Success] here means the server actually
  /// echoed this exact selection back (see `parseTargetRoleBadge`'s doc
  /// comment) — never merely that an HTTP request completed.
  Future<Result<ResumeRoleSelection>> selectTargetRole({
    required String role,
    required String dept,
    required String track,
  });
}
