import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/employer_application_detail.dart';
import '../domain/repositories/employer_application_detail_repository.dart';
import 'employer_application_detail_remote_datasource.dart';

class EmployerApplicationDetailRepositoryImpl implements EmployerApplicationDetailRepository {
  EmployerApplicationDetailRepositoryImpl(this._remote);

  final EmployerApplicationDetailRemoteDataSource _remote;

  @override
  Future<Result<EmployerApplicationDetail>> getApplicationDetail(int applicationId) async {
    try {
      return Success(await _remote.getApplicationDetail(applicationId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> updateStatus({
    required int applicationId,
    required String status,
    required String employerNotes,
  }) async {
    try {
      await _remote.updateStatus(applicationId: applicationId, status: status, employerNotes: employerNotes);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
