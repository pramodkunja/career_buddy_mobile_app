import '../../../../core/utils/result.dart';
import '../entities/employer_job_applications.dart';

abstract class EmployerJobApplicationsRepository {
  Future<Result<EmployerJobApplicationsPage>> getApplications(int jobId, {String statusFilter = ''});
}
