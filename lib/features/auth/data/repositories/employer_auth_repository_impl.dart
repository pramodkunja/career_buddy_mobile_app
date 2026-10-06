import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/employer_registration_data.dart';
import '../../domain/repositories/employer_auth_repository.dart';
import '../auth_session_keys.dart';
import '../datasources/employer_auth_remote_datasource.dart';

class EmployerAuthRepositoryImpl implements EmployerAuthRepository {
  EmployerAuthRepositoryImpl(this._remote, this._storage);

  final EmployerAuthRemoteDataSource _remote;
  final SecureStorageService _storage;

  @override
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final username = await _remote.login(usernameOrEmail: usernameOrEmail, password: password);
      await _storage.write(AuthSessionKeys.username, username);
      await _storage.write(AuthSessionKeys.isEmployer, 'true');
      return Success(AuthUser(username: username, isEmployer: true));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<String>> sendOtp(String email) async {
    try {
      return Success(await _remote.sendOtp(email));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async {
    try {
      return Success(await _remote.verifyOtp(email: email, code: code));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<AuthUser>> register(EmployerRegistrationData data) async {
    try {
      final username = await _remote.register(data);
      await _storage.write(AuthSessionKeys.username, username);
      await _storage.write(AuthSessionKeys.isEmployer, 'true');
      return Success(AuthUser(username: username, isEmployer: true));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
