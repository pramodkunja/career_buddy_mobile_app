import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/employer_auth_remote_datasource.dart';
import '../../data/datasources/password_reset_remote_datasource.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/employer_auth_repository_impl.dart';
import '../../data/repositories/password_reset_repository_impl.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/employer_auth_repository.dart';
import '../../domain/repositories/password_reset_repository.dart';
import '../../domain/repositories/profile_repository.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(secureStorageProvider),
  );
});

final employerAuthRemoteDataSourceProvider = Provider<EmployerAuthRemoteDataSource>((ref) {
  return EmployerAuthRemoteDataSource(ref.watch(apiClientProvider));
});

final employerAuthRepositoryProvider = Provider<EmployerAuthRepository>((ref) {
  return EmployerAuthRepositoryImpl(
    ref.watch(employerAuthRemoteDataSourceProvider),
    ref.watch(secureStorageProvider),
  );
});

final passwordResetRemoteDataSourceProvider = Provider<PasswordResetRemoteDataSource>((ref) {
  return PasswordResetRemoteDataSource(ref.watch(apiClientProvider));
});

final passwordResetRepositoryProvider = Provider<PasswordResetRepository>((ref) {
  return PasswordResetRepositoryImpl(ref.watch(passwordResetRemoteDataSourceProvider));
});

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSource(ref.watch(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
});
