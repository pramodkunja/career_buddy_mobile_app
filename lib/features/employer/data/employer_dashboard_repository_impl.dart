import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/employer_dashboard_summary.dart';
import '../domain/repositories/employer_dashboard_repository.dart';
import 'employer_dashboard_remote_datasource.dart';

class EmployerDashboardRepositoryImpl implements EmployerDashboardRepository {
  EmployerDashboardRepositoryImpl(this._remote);

  final EmployerDashboardRemoteDataSource _remote;

  @override
  Future<Result<EmployerDashboardSummary>> getDashboard() async {
    try {
      return Success(await _remote.getDashboard());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> deleteJob(int jobId) async {
    try {
      await _remote.deleteJob(jobId);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
