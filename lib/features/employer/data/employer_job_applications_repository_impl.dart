import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/employer_job_applications.dart';
import '../domain/repositories/employer_job_applications_repository.dart';
import 'employer_job_applications_remote_datasource.dart';

class EmployerJobApplicationsRepositoryImpl implements EmployerJobApplicationsRepository {
  EmployerJobApplicationsRepositoryImpl(this._remote);

  final EmployerJobApplicationsRemoteDataSource _remote;

  @override
  Future<Result<EmployerJobApplicationsPage>> getApplications(int jobId, {String statusFilter = ''}) async {
    try {
      return Success(await _remote.getApplications(jobId, statusFilter: statusFilter));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
