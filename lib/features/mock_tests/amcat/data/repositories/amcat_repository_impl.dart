import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/exceptions.dart';
import '../../../../../core/utils/result.dart';
import '../../domain/entities/amcat_section.dart';
import '../../domain/entities/amcat_submission_result.dart';
import '../../domain/repositories/amcat_repository.dart';
import '../datasources/amcat_remote_datasource.dart';

class AmcatRepositoryImpl implements AmcatRepository {
  AmcatRepositoryImpl(this._remote);

  final AmcatRemoteDataSource _remote;

  @override
  Future<Result<List<AmcatSection>>> getSections() async {
    try {
      final data = await _remote.getSections();
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<AmcatSubmissionResult>> submit(Map<int, int> answers) async {
    try {
      final data = await _remote.submit(answers);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
