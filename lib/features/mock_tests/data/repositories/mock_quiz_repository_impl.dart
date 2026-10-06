import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/mock_test_question.dart';
import '../../domain/entities/mock_test_submission_result.dart';
import '../../domain/repositories/mock_quiz_repository.dart';
import '../datasources/mock_quiz_remote_datasource.dart';

class MockQuizRepositoryImpl implements MockQuizRepository {
  MockQuizRepositoryImpl(this._remote);

  final MockQuizRemoteDataSource _remote;

  @override
  Future<Result<List<MockTestQuestion>>> getQuestions() async {
    try {
      final data = await _remote.getQuestions();
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<MockTestSubmissionResult>> submitAnswers(Map<int, int> answers) async {
    try {
      final data = await _remote.submitAnswers(answers);
      return Success(data);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
