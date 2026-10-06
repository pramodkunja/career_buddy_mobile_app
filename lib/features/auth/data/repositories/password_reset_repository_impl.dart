import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/password_reset_repository.dart';
import '../datasources/password_reset_remote_datasource.dart';

class PasswordResetRepositoryImpl implements PasswordResetRepository {
  PasswordResetRepositoryImpl(this._remote);

  final PasswordResetRemoteDataSource _remote;

  @override
  Future<Result<void>> requestReset(String email) async {
    try {
      await _remote.requestReset(email);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<bool>> checkResetLink({required String uidb64, required String token}) async {
    try {
      return Success(await _remote.checkResetLink(uidb64, token));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> confirmReset({
    required String uidb64,
    required String token,
    required String password1,
    required String password2,
  }) async {
    try {
      await _remote.confirmReset(uidb64: uidb64, token: token, password1: password1, password2: password2);
      return const Success(null);
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
