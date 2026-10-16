import '../../../../core/utils/result.dart';
import '../entities/level_common_suggestions.dart';
import '../entities/manual_resume_draft.dart';
import '../entities/manual_resume_page_preview_outcome.dart';
import '../entities/manual_resume_pdf_outcome.dart';
import '../entities/manual_resume_preview_outcome.dart';
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

  /// `manual_resume_roles`'s top-level `level_common` (Phase 26) — the same
  /// response [getRoles] reads, fetched with its own request since
  /// [getRoles]'s return type only carries the `roles` list. A genuine
  /// [Result]: the Manual Resume Builder's suggestion chips are a real,
  /// visible part of Career & Skills / Experience / Summary, so a failure
  /// here must be retryable rather than silently empty.
  Future<Result<Map<String, LevelCommonSuggestions>>>
  getLevelCommonSuggestions();

  /// `manual_resume_views.preview_api` (Phase 27) — submits the current
  /// draft and returns the server's own assembled resume. A [Success] here
  /// means the request round-tripped and the body was well-formed —
  /// [ManualResumePreviewOutcome] is itself the sealed "ready vs. rejected"
  /// branch, since a validation failure/rate-limit/unreadable-payload
  /// response from the server is a normal, meaningful result, never an
  /// exception on its own (see that type's own doc comment). [Failed] is
  /// reserved for a genuine transport failure or a response that doesn't
  /// match either known shape at all.
  Future<Result<ManualResumePreviewOutcome>> previewManualResume(
    ManualResumeDraft draft,
  );

  /// `manual_resume_views.preview_pages_api` (Phase 28) — same contract
  /// shape as [previewManualResume]: a well-formed rejection (validation/
  /// rate-limit/unreadable-payload, or the endpoint's own page-rendering
  /// failure) is a [Success] carrying [ManualResumePagePreviewRejected],
  /// never a [Failed] — only a genuine transport failure or an unparseable
  /// response is.
  Future<Result<ManualResumePagePreviewOutcome>> getManualResumePagePreview(
    ManualResumeDraft draft,
  );

  /// `manual_resume_views.pdf_download` (Phase 28) — same contract shape
  /// again: a well-formed rejection is [Success]-wrapped
  /// [ManualResumePdfRejected]; [Failed] means the request itself failed or
  /// the response couldn't be identified as either real PDF bytes or a
  /// well-formed JSON rejection. Never persists anything locally — the
  /// caller decides what to do with the returned bytes (Phase 28's own
  /// controller writes them to a temp file and opens it, exactly once per
  /// call, never into draft storage).
  Future<Result<ManualResumePdfOutcome>> generateManualResumePdf(
    ManualResumeDraft draft,
  );
}
