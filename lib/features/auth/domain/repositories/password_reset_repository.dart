import '../../../../core/utils/result.dart';

abstract interface class PasswordResetRepository {
  Future<Result<void>> requestReset(String email);

  /// `true` if the link is still valid (unused, unexpired, well-formed).
  Future<Result<bool>> checkResetLink({required String uidb64, required String token});

  Future<Result<void>> confirmReset({
    required String uidb64,
    required String token,
    required String password1,
    required String password2,
  });
}
