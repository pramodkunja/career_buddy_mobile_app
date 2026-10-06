import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/student_registration_data.dart';
import '../../domain/repositories/auth_repository.dart';
import '../auth_session_keys.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;

  @override
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final username = await _remote.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      await _storage.write(AuthSessionKeys.username, username);
      await _storage.write(AuthSessionKeys.isEmployer, 'false');
      return Success(AuthUser(username: username));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _remote.logout();
      await _clearCache();
      return const Success(null);
    } on AppException catch (e) {
      // Still drop the local session even if the server call failed, so the
      // user isn't stuck "logged in" locally against a dead session.
      await _clearCache();
      return Failed(ExceptionMapper.map(e));
    }
  }

  Future<void> _clearCache() async {
    await _storage.delete(AuthSessionKeys.username);
    await _storage.delete(AuthSessionKeys.isEmployer);
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final cachedUsername = await _storage.read(AuthSessionKeys.username);
    if (cachedUsername == null) return null;
    final isEmployer = await _storage.read(AuthSessionKeys.isEmployer) == 'true';
    return AuthUser(username: cachedUsername, isEmployer: isEmployer);
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
  Future<Result<AuthUser>> register(StudentRegistrationData data) async {
    try {
      final username = await _remote.register(data);
      await _storage.write(AuthSessionKeys.username, username);
      await _storage.write(AuthSessionKeys.isEmployer, 'false');
      return Success(AuthUser(username: username));
    } on AppException catch (e) {
      return Failed(ExceptionMapper.map(e));
    }
  }
}
