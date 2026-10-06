import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'route_paths.dart';

/// Pure redirect logic, kept separate from [GoRouter] wiring so it can be
/// unit-tested without spinning up a router or widget tree.
///
/// [demoBypass] is `true` only when both `kDebugMode` and
/// `demoModeEnabledProvider` are true (checked by the caller,
/// `app_router.dart`, since this function stays free of Flutter-foundation
/// imports for easy testing) — it lets the debug-only Direct Demo Entry
/// flow (`lib/core/demo/demo_entry_screen.dart`) reach Activities/Exercise
/// screens without a real session, since Demo Mode never calls the real
/// API anyway (see `demo_mode.dart`). It never affects a release build,
/// where the caller always passes `false`.
String? computeRedirect({
  required AuthState authState,
  required String matchedLocation,
  bool demoBypass = false,
}) {
  if (demoBypass) return null;

  final goingToPublicRoute = RoutePaths.publicRoutes.contains(matchedLocation);
  final goingToUniversalRoute = RoutePaths.universalRoutes.contains(matchedLocation);
  final goingToSplash = matchedLocation == RoutePaths.splash;

  switch (authState) {
    case AuthUnknown():
      return goingToSplash ? null : RoutePaths.splash;
    case AuthUnauthenticated():
      if (goingToPublicRoute || goingToUniversalRoute) return null;
      // Mirrors each employer-only view's own `login_url=
      // 'employer_portal:employer_login'` — bounces to the employer login
      // screen instead of the student one, same as the real backend does.
      if (RoutePaths.employerProtectedRoutes.contains(matchedLocation)) return RoutePaths.employerLogin;
      return RoutePaths.login;
    case AuthAuthenticated():
      // A universal route (Home/Employer Home) is reachable while
      // authenticated too, unlike `publicRoutes`/`splash` — see
      // `RoutePaths.universalRoutes`'s doc comment.
      if (goingToUniversalRoute) return null;
      if (goingToPublicRoute || goingToSplash) {
        return authState.user.isEmployer ? RoutePaths.employerDashboard : RoutePaths.dashboard;
      }
      // Batch 10 — cross-role access: mirrors the real backend's own
      // two-way guard, confirmed directly against source. `employer_
      // dashboard()` (`jobs_app/views.py`) force-logs-out and redirects to
      // `job_home` when `request.session.get('portal') != 'employer'`;
      // `dashboard()` (`activities/views.py`) redirects (no logout) to
      // `job_home` when `_is_employer_session(request)`. This client
      // reproduces the redirect half of both (a student is bounced away
      // from every employer-only route, an employer is bounced away from
      // the student dashboard) — never the forced-logout side effect,
      // since that would need this otherwise-pure, router-agnostic
      // function to also mutate auth state, which is exactly what its own
      // doc comment above says it's deliberately kept free of. A redirect
      // alone already closes the actual bug (the wrong role's screen is
      // never shown), so no session mutation was added for this.
      if (RoutePaths.employerProtectedRoutes.contains(matchedLocation) && !authState.user.isEmployer) {
        return RoutePaths.dashboard;
      }
      if (matchedLocation == RoutePaths.dashboard && authState.user.isEmployer) {
        return RoutePaths.employerDashboard;
      }
      return null;
    case AuthRefreshing():
      return null;
  }
}
