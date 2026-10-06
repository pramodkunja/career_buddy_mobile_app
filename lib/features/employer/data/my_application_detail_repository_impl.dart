import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/my_application_detail.dart';
import '../domain/repositories/my_application_detail_repository.dart';
import 'my_application_detail_remote_datasource.dart';

class MyApplicationDetailRepositoryImpl implements MyApplicationDetailRepository {
  MyApplicationDetailRepositoryImpl(this._remote);

  final MyApplicationDetailRemoteDataSource _remote;

  @override
  Future<Result<MyApplicationDetail>> getApplicationDetail(int applicationId) async {
    try {
      return Success(await _remote.getApplicationDetail(applicationId));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
