import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../shared/widgets/app_footer.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../widgets/authenticated_home_body.dart';
import '../widgets/public_home_body.dart';

/// W024 — Home (`templates/landing.html`, `activities/views.py:78 home()`
/// — the updated web's current template; see
/// `docs/PHASE_20_HOME_LANDING_PARITY_AUDIT.md` for the full discovery
/// behind Phase 21's hero changes below). A [Scaffold] wired with the
/// shared global shell ([AppTopBar]/[AppNavDrawer]/[AppFooter]/
/// [BuddyChatbotOverlay]) around a body that branches on
/// [authControllerProvider].
///
/// Phase 21: the 3 unified-hero CTAs (Get Started/Find Jobs/Create Resume)
/// share destinations across the anonymous and authenticated-student
/// branches wherever the underlying action is genuinely the same
/// (`resumeBuilder` for Create Resume either way); where it can't be —
/// "Get Started" must never re-register an already-authenticated user —
/// the authenticated branch points at sensible existing navigation instead
/// (`dashboard`), per this phase's own explicit instruction. An
/// authenticated employer still never sees these CTAs at all (see
/// `AuthenticatedHomeBody`'s own doc comment for why that's faithful to
/// the real web, not an oversight).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      drawer: const AppNavDrawer(),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                if (user != null)
                  AuthenticatedHomeBody(
                    isEmployer: user.isEmployer,
                    // Already authenticated — "Get Started" would make no
                    // sense as a re-registration prompt, so this (like Find
                    // Jobs) goes to the student's own Dashboard instead,
                    // which already surfaces both overall progress and any
                    // job recommendations (`RecommendedJobsSection`) in one
                    // place — there is no separate, single-purpose "jobs"
                    // screen for this to point at instead.
                    onGetStarted: () => context.go(RoutePaths.dashboard),
                    onFindJobs: () => context.go(RoutePaths.dashboard),
                    onCreateResume: () => context.push(RoutePaths.resumeBuilder),
                    onEmployerDashboard: () => context.go(RoutePaths.employerDashboard),
                    onFindCandidates: () => context.push(RoutePaths.employerSearchCandidates),
                  )
                else
                  PublicHomeBody(
                    onGetStarted: () => context.push(RoutePaths.register),
                    // Both of these push a route that requires a session —
                    // `RoutePaths.dashboard`/`resumeBuilder` are neither in
                    // `publicRoutes` nor `universalRoutes`, so the existing
                    // auth guard (`route_guards.dart`) already redirects an
                    // anonymous visitor to `/login` first, exactly mirroring
                    // the real `dashboard`/`resume_builder_home` views' own
                    // `@login_required` (confirmed directly in the updated
                    // Django source) — no separate login-check is added here.
                    onFindJobs: () => context.push(RoutePaths.dashboard),
                    onCreateResume: () => context.push(RoutePaths.resumeBuilder),
                    onLogin: () => context.go(RoutePaths.login),
                    onRegister: () => context.push(RoutePaths.register),
                    onEmployerLogin: () => context.push(RoutePaths.employerLogin),
                    onEmployerRegister: () => context.push(RoutePaths.employerRegister),
                  ),
                const AppFooter(),
              ],
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}
