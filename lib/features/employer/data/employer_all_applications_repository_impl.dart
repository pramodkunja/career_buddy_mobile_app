import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/employer_all_applications.dart';
import '../domain/repositories/employer_all_applications_repository.dart';
import 'employer_all_applications_remote_datasource.dart';

class EmployerAllApplicationsRepositoryImpl implements EmployerAllApplicationsRepository {
  EmployerAllApplicationsRepositoryImpl(this._remote);

  final EmployerAllApplicationsRemoteDataSource _remote;

  @override
  Future<Result<EmployerAllApplicationsPage>> getApplications({
    String query = '',
    String statusFilter = '',
    String sourceFilter = '',
  }) async {
    try {
      return Success(await _remote.getApplications(query: query, statusFilter: statusFilter, sourceFilter: sourceFilter));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
