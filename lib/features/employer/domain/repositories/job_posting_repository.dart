import '../../../../core/utils/result.dart';
import '../entities/job_posting_submission.dart';

abstract class JobPostingRepository {
  /// Posts [data] to the real production endpoint
  /// (`ApiEndpoints.employerJobCreate`). `Success` means the server actually
  /// accepted and saved the job (a real 302 redirect, same success
  /// convention proven for every other session-authenticated form in this
  /// app) — never a locally-assumed success. A `Failed` with a
  /// `ValidationFailure` carries the server's own per-field error messages,
  /// keyed by the same Django field names as [JobPostingSubmission]'s
  /// fields.
  Future<Result<void>> submit(JobPostingSubmission data);

  /// Posts [data] to `ApiEndpoints.employerJobEdit(jobId)` instead — same
  /// success/failure contract as [submit].
  Future<Result<void>> submitEdit(int jobId, JobPostingSubmission data);

  /// Fetches [jobId]'s current values from its real Edit page, to seed the
  /// same form [submit]/[submitEdit] both post from. `Failed` on a 404/403
  /// (job not found, or not owned by this employer) surfaces as an ordinary
  /// error the Edit screen can show with a retry, same as any other fetch.
  Future<Result<JobPostingSubmission>> getJobForEdit(int jobId);
}
