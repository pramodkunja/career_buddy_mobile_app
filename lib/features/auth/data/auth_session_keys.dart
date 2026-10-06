/// Local-cache keys shared by [AuthRepositoryImpl] (student login) and
/// [EmployerAuthRepositoryImpl] (employer login) — both write the *same*
/// two keys, because only one Django session can ever be active at a time
/// (a real browser-like session cookie, not per-flow state), so whichever
/// flow logged in most recently is what `restoreSession()` should return
/// regardless of which repository instance handled the login.
abstract final class AuthSessionKeys {
  static const String username = 'auth.cached_username';
  static const String isEmployer = 'auth.cached_is_employer';
}
