import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/public_job_detail.dart';
import '../domain/repositories/public_job_detail_repository.dart';
import 'public_job_detail_remote_datasource.dart';

class PublicJobDetailRepositoryImpl implements PublicJobDetailRepository {
  PublicJobDetailRepositoryImpl(this._remote);

  final PublicJobDetailRemoteDataSource _remote;

  @override
  Future<Result<PublicJobDetail>> getJobDetail(int jobId) async {
    try {
      return Success(await _remote.getJobDetail(jobId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> apply(int jobId, PublicJobApplicationSubmission data) async {
    try {
      await _remote.apply(jobId, data);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
