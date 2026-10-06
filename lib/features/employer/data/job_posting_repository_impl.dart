import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/job_posting_submission.dart';
import '../domain/repositories/job_posting_repository.dart';
import 'job_posting_remote_datasource.dart';

class JobPostingRepositoryImpl implements JobPostingRepository {
  JobPostingRepositoryImpl(this._remote);

  final JobPostingRemoteDataSource _remote;

  @override
  Future<Result<void>> submit(JobPostingSubmission data) async {
    try {
      await _remote.submit(data);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
