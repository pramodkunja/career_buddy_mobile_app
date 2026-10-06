import '../../../core/errors/exception_mapper.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/result.dart';
import '../domain/entities/jam_history_profile.dart';
import '../domain/repositories/jam_profile_repository.dart';
import 'jam_remote_datasource.dart';

class JamProfileRepositoryImpl implements JamProfileRepository {
  JamProfileRepositoryImpl(this._remote);

  final JamRemoteDataSource _remote;

  @override
  Future<Result<JamProfile>> getProfile() async {
    try {
      return Success(await _remote.getProfile());
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> updateProfile(JamProfileUpdate data) async {
    try {
      await _remote.updateProfile(data);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> resetProgress() async {
    try {
      await _remote.resetProgress();
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
