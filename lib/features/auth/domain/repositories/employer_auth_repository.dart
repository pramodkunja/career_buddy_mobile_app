import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';
import '../entities/employer_registration_data.dart';

/// Deliberately a separate interface from [AuthRepository], not an extra
/// method bolted onto it — employer auth is a genuinely different Django
/// view/form (see `EmployerAuthRemoteDataSource`'s doc comment), and a new
/// interface means the ~20 existing fakes of [AuthRepository] across the
/// test suite (unrelated features that only need student login) don't all
/// need updating for a feature they don't touch.
abstract class EmployerAuthRepository {
  Future<Result<AuthUser>> login({
    required String usernameOrEmail,
    required String password,
  });

  /// `users.views.send_email_otp` — sends a 6-digit code to [email], valid
  /// 10 minutes, at most one per 60s per address (`core/otp_utils.py`).
  /// Returns the server's own status message on success.
  Future<Result<String>> sendOtp(String email);

  /// `users.views.verify_email_otp` — up to 5 attempts before the code is
  /// burned. Success marks [email] verified in the *session* this
  /// repository's `ApiClient` cookie jar carries — [register] depends on
  /// that same session still being current.
  Future<Result<String>> verifyOtp({required String email, required String code});

  /// `accounts_app.views.employer_register` — both [EmployerRegistrationData.email]
  /// and [EmployerRegistrationData.hrMail] must already be verified (via
  /// [sendOtp]/[verifyOtp], same session) or the server rejects the
  /// submission the same way the web's own JS-gated form would.
  Future<Result<AuthUser>> register(EmployerRegistrationData data);
}
