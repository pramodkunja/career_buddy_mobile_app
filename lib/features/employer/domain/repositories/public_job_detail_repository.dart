import '../../../../core/utils/result.dart';
import '../entities/public_job_detail.dart';

abstract class PublicJobDetailRepository {
  Future<Result<PublicJobDetail>> getJobDetail(int jobId);
  Future<Result<void>> apply(int jobId, PublicJobApplicationSubmission data);
}
