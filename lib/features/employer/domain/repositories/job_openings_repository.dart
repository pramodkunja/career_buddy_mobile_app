import '../../../../core/utils/result.dart';
import '../entities/job_openings.dart';

abstract class JobOpeningsRepository {
  Future<Result<JobOpeningsPage>> getJobOpenings();
}
