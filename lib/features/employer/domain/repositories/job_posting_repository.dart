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
}
