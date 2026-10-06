/// The backend has no profile/"me" endpoint (session-cookie auth only, no
/// JSON API — see `ARCHITECTURE.md` notes on `users/views.py`), so this only
/// carries what was submitted at login. Extend it once a real profile
/// endpoint exists instead of guessing fields now.
class AuthUser {
  const AuthUser({required this.username, this.isEmployer = false});

  final String username;

  /// Whether this session was established through the employer login/
  /// registration flow (`employer_portal:employer_login`/
  /// `employer_register`) rather than the student one (`/users/login/`).
  /// Mirrors the web's own `request.session['portal'] == 'employer'` /
  /// `user.employer_profile` check (`templates/base.html:131`) — there is
  /// no bit of JSON this can be read back from, so it's set once, at
  /// login time, by whichever flow authenticated this session, and cached
  /// alongside the username (see `AuthSessionKeys`).
  final bool isEmployer;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.username == username && other.isEmployer == isEmployer;

  @override
  int get hashCode => Object.hash(username, isEmployer);
}
