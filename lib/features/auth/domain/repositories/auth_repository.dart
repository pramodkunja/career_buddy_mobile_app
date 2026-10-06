import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';
import '../entities/student_registration_data.dart';

abstract class AuthRepository {
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  });

  Future<Result<void>> logout();

  /// Returns the locally cached user if the last known login succeeded, or
  /// `null` otherwise. This does NOT confirm the server-side session is
  /// still valid — the backend has no endpoint to check that. An expired
  /// session is only discovered when a later request comes back
  /// unauthorized.
  Future<AuthUser?> restoreSession();

  /// `users/urls.py:'register/send-otp/'`/`'verify-otp/'` — the same shared
  /// email-OTP endpoints employer registration already uses (see
  /// `EmployerAuthRepository`), reused here rather than duplicated.
  Future<Result<String>> sendOtp(String email);

  Future<Result<String>> verifyOtp({required String email, required String code});

  Future<Result<AuthUser>> register(StudentRegistrationData data);
}
