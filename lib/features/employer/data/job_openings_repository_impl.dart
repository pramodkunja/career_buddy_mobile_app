import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/job_openings.dart';
import '../domain/repositories/job_openings_repository.dart';
import 'job_openings_remote_datasource.dart';

class JobOpeningsRepositoryImpl implements JobOpeningsRepository {
  JobOpeningsRepositoryImpl(this._remote);

  final JobOpeningsRemoteDataSource _remote;

  @override
  Future<Result<JobOpeningsPage>> getJobOpenings() async {
    try {
      return Success(await _remote.getJobOpenings());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
