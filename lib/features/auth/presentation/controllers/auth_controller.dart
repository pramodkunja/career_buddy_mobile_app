import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../activities/presentation/controllers/activity_detail_controller.dart';
import '../../../activities/presentation/controllers/activity_list_controller.dart';
import '../../../activities/presentation/controllers/sub_activity_detail_controller.dart';
import '../../../activities/presentation/controllers/workshop_dashboard_controller.dart';
import '../../../aria_chat/presentation/controllers/aria_chat_controller.dart';
import '../../../certifications/presentation/providers/certifications_providers.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';
import '../../../employer/presentation/controllers/employer_all_applications_controller.dart';
import '../../../employer/presentation/controllers/employer_application_detail_controller.dart';
import '../../../employer/presentation/controllers/employer_candidate_search_controller.dart';
import '../../../employer/presentation/controllers/employer_job_applications_controller.dart';
import '../../../employer/presentation/controllers/employer_profile_controller.dart';
import '../../../employer/presentation/controllers/job_openings_controller.dart';
import '../../../employer/presentation/controllers/my_application_detail_controller.dart';
import '../../../employer/presentation/controllers/public_job_detail_controller.dart';
import '../../../employer/presentation/providers/employer_dashboard_providers.dart';
import '../../../group_discussion/presentation/controllers/gd_history_controller.dart';
import '../../../jam/presentation/controllers/jam_history_controller.dart';
import '../../../jam/presentation/controllers/jam_history_detail_controller.dart';
import '../../../jam/presentation/controllers/jam_profile_controller.dart';
import '../../../jam/presentation/providers/jam_providers.dart';
import '../../../resume/presentation/providers/resume_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/employer_registration_data.dart';
import '../../domain/entities/student_registration_data.dart';
import '../../../../core/utils/result.dart';
import '../providers/auth_providers.dart';
import 'profile_controller.dart';

sealed class AuthState {
  const AuthState();
}

/// Session state not yet determined (checking local cache at startup).
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AuthUser user;
}

/// A login/logout call is in flight.
final class AuthRefreshing extends AuthState {
  const AuthRefreshing();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated([this.errorMessage]);
  final String? errorMessage;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    final user = await ref.read(authRepositoryProvider).restoreSession();
    state = user != null ? AuthAuthenticated(user) : const AuthUnauthenticated();
  }

  /// None of the controllers below are `.autoDispose` (each needs to
  /// survive its own screen being popped and reopened without refetching
  /// every time — pull-to-refresh/`retry()` already covers that case), so
  /// every one of them stays alive in the single app-wide `ProviderContainer`
  /// for as long as the process runs, holding whichever user's data it last
  /// fetched. Confirmed live on-device (two different real accounts, same
  /// app session, no process restart): without this, logging out and
  /// logging back in as someone else showed the PREVIOUS account's
  /// Dashboard stats/recommended job verbatim under the new account's own
  /// name — a real cross-account data leak, not a cosmetic bug. Called at
  /// the start of every method below that crosses a session boundary
  /// (logging out, or logging in as whoever's credentials were just
  /// submitted, replacing whatever was cached from a prior session in this
  /// same process) so stale data can never outlive the session it belongs
  /// to. `ref.invalidate` on a `.family` provider (several of these are)
  /// invalidates every live instance of it, not just one.
  void _invalidateUserScopedProviders() {
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(activityListControllerProvider);
    ref.invalidate(activityDetailControllerProvider);
    ref.invalidate(subActivityDetailControllerProvider);
    ref.invalidate(workshopDashboardControllerProvider);
    ref.invalidate(resumeHistoryControllerProvider);
    ref.invalidate(certificateFormControllerProvider);
    ref.invalidate(ariaChatControllerProvider);
    ref.invalidate(gdHistoryControllerProvider);
    ref.invalidate(jamTopicsControllerProvider);
    ref.invalidate(jamProfileControllerProvider);
    ref.invalidate(jamHistoryControllerProvider);
    ref.invalidate(jamSessionDetailControllerProvider);
    ref.invalidate(jamAssessmentEligibilityControllerProvider);
    ref.invalidate(employerDashboardControllerProvider);
    ref.invalidate(employerProfileControllerProvider);
    ref.invalidate(jobOpeningsControllerProvider);
    ref.invalidate(employerAllApplicationsControllerProvider);
    ref.invalidate(employerJobApplicationsControllerProvider);
    ref.invalidate(employerApplicationDetailControllerProvider);
    ref.invalidate(myApplicationDetailControllerProvider);
    ref.invalidate(publicJobDetailControllerProvider);
    ref.invalidate(employerCandidateSearchControllerProvider);
  }

  Future<void> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    _invalidateUserScopedProviders();
    state = const AuthRefreshing();
    final result = await ref
        .read(authRepositoryProvider)
        .login(usernameOrEmail: usernameOrEmail, password: password);
    state = switch (result) {
      Success(value: final user) => AuthAuthenticated(user),
      Failed(failure: final failure) => AuthUnauthenticated(failure.message),
    };
  }

  /// `users/views.py:register_view` — same shared [AuthState] machine as
  /// [login]; a successful registration logs the user in immediately on
  /// the web too (`login(request, user)` right after `form.save()`).
  Future<void> register(StudentRegistrationData data) async {
    _invalidateUserScopedProviders();
    state = const AuthRefreshing();
    final result = await ref.read(authRepositoryProvider).register(data);
    state = switch (result) {
      Success(value: final user) => AuthAuthenticated(user),
      Failed(failure: final failure) => AuthUnauthenticated(failure.message),
    };
  }

  Future<void> logout() async {
    // Idempotency guard: invalidating a user-scoped provider below can
    // itself be watched by the very screen whose `UnauthorizedFailure`
    // called this method (e.g. `DashboardScreen`'s `ref.listen`) — while
    // that screen is still mounted (briefly, until the router guard reacts
    // to the state change below and navigates away), invalidating it
    // triggers a refetch, which can fail with another 401 and call
    // `logout()` again. A plain in-flight check isn't enough — by the time
    // that *second* call arrives, the *first* one may have already finished
    // and moved `state` on to `AuthUnauthenticated`, so the second call
    // would see a clean slate and genuinely re-run (test-confirmed: a real
    // cascade, repeating once per rebuild until the fake repository's
    // pump loop ran out). Logging out when already logged out — or already
    // logging out — is a no-op either way, so guarding on both states is
    // both safe and sufficient to break the cascade.
    if (state is AuthRefreshing || state is AuthUnauthenticated) return;
    state = const AuthRefreshing();
    _invalidateUserScopedProviders();
    final result = await ref.read(authRepositoryProvider).logout();
    state = switch (result) {
      Success() => const AuthUnauthenticated(),
      Failed(failure: final failure) => AuthUnauthenticated(failure.message),
    };
  }

  /// Employer Portal sign-in — a genuinely different Django view/form from
  /// [login] (see `EmployerAuthRemoteDataSource`'s doc comment), but the
  /// same shared [AuthState] machine: routing guards, the nav drawer, and
  /// Home all need to see "signed in" regardless of which flow got there.
  Future<void> loginEmployer({
    required String usernameOrEmail,
    required String password,
  }) async {
    _invalidateUserScopedProviders();
    state = const AuthRefreshing();
    final result = await ref
        .read(employerAuthRepositoryProvider)
        .login(usernameOrEmail: usernameOrEmail, password: password);
    state = switch (result) {
      Success(value: final user) => AuthAuthenticated(user),
      Failed(failure: final failure) => AuthUnauthenticated(failure.message),
    };
  }

  /// `accounts_app.views.employer_register` — same success/failure state
  /// transition as [loginEmployer]; the OTP send/verify steps that must
  /// precede this are their own controller-less repository calls (see
  /// `EmployerRegisterScreen`), since their outcome is per-field UI state,
  /// not a session-wide auth state change.
  Future<void> registerEmployer(EmployerRegistrationData data) async {
    _invalidateUserScopedProviders();
    state = const AuthRefreshing();
    final result = await ref.read(employerAuthRepositoryProvider).register(data);
    state = switch (result) {
      Success(value: final user) => AuthAuthenticated(user),
      Failed(failure: final failure) => AuthUnauthenticated(failure.message),
    };
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
