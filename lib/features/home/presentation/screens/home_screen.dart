import 'dart:async';

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
import '../widgets/home_landing_footer.dart';
import '../widgets/home_path_picker_popup.dart';
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
/// branches wherever the underlying action is genuinely the same; where it
/// can't be — "Get Started" must never re-register an already-authenticated
/// user — the authenticated branch points at sensible existing navigation
/// instead (`dashboard`), per this phase's own explicit instruction. An
/// authenticated employer still never sees these CTAs at all (see
/// `AuthenticatedHomeBody`'s own doc comment for why that's faithful to
/// the real web, not an oversight).
///
/// Phase 34 (superseded by Phase 39): "Create Resume" stopped pushing
/// straight to [RoutePaths.resumeBuilder] once it was confirmed the real
/// web's own hero "Create Resume" button (`landing.html:6552`) scrolls to a
/// `#create-resume` anchor that is a **third, entirely separate** free-form
/// resume builder (`career_app/create_resume_views.py`), distinct from both
/// the role-driven Manual Resume Builder (Phases 24-32) and the AI
/// parsing/ATS flow this CTA used to point at alone. Phase 34's interim fix
/// — a choice sheet between those other two existing features — was an
/// explicitly acknowledged compromise for a then-missing feature, not the
/// real destination. Phase 39 implements that free-form builder
/// ([RoutePaths.createResumeBuilder]), so this CTA now goes exactly where
/// the real hero button does. The Manual Resume Builder remains fully
/// reachable as before, unchanged, via its own separate entry point (the
/// Role Picker's "Build Resume" tile) — this phase only corrects what this
/// one hero/portal CTA itself does.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Phase 49 — `templates/landing.html:7575-7584`'s path-picker popup:
  /// `var t = setTimeout(function () { ... m.showModal() }, 5000);`, fired
  /// on every landing-page load (confirmed no `localStorage`/cookie
  /// suppression exists anywhere in that script — reshowing on every fresh
  /// visit is the real, verified behavior, not an oversight to "fix" with
  /// invented persistence). `canceled`/`_popupHandled` mirror the web's own
  /// `clearTimeout(t)` (fired there only by the Non-IT card's click
  /// handler) and its `if (!document.querySelector('dialog[open]')) `
  /// guard respectively — the Flutter equivalent of "the page already
  /// navigated away" is checking the route is still on top, since
  /// `context.push` (unlike a real page navigation) does not unmount this
  /// screen or its pending timer.
  Timer? _popupTimer;
  bool _popupHandled = false;

  @override
  void initState() {
    super.initState();
    _popupTimer = Timer(const Duration(seconds: 5), _maybeShowPathPicker);
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    super.dispose();
  }

  void _maybeShowPathPicker() {
    if (_popupHandled || !mounted) return;
    // Authenticated users render `AuthenticatedHomeBody`, which has no
    // "Choose Your Path" section to begin with (a pre-existing, separate
    // scope decision, not this phase's to revisit) — matching that, the
    // popup only ever applies to the guest branch below.
    final authState = ref.read(authControllerProvider);
    if (authState is AuthAuthenticated) return;
    // Equivalent of the web's "a dialog is already open" guard: if this
    // screen is no longer the topmost route (the user already pushed
    // somewhere else, e.g. via a path card), don't pop this up over it.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _popupHandled = true;
    showDialog<void>(
      context: context,
      // Phase 50 — the real `<dialog>` has no backdrop click handler
      // (confirmed directly: `cpModal`'s own script never listens for a
      // click on it, and native `<dialog>` does not close on backdrop
      // click by default either), so tapping outside it does nothing on
      // the web. `showDialog` defaults to the opposite (`barrierDismissible:
      // true`); this is the one-line fix for that mismatch. Android system
      // back is deliberately left at its own default (which still closes
      // this route) — the closest native match to the real `<dialog>`
      // closing on Escape, which `cpModal` also never prevents.
      barrierDismissible: false,
      builder: (_) => HomePathPickerPopup(
        onItJobSeeker: () => context.push(RoutePaths.careerDepartments, extra: 'it'),
        onNonIt: () => context.push(RoutePaths.careerDepartments, extra: 'non-it'),
      ),
    );
  }

  /// Wraps a path-card tap so choosing a path directly (without waiting for
  /// the popup) also cancels the pending auto-popup — the Flutter
  /// equivalent of the web's `clearTimeout(t)` on the Non-IT card's click
  /// handler, applied to both cards since either one means the choice has
  /// already been made.
  void _choosePath(VoidCallback navigate) {
    _popupHandled = true;
    _popupTimer?.cancel();
    navigate();
  }

  @override
  Widget build(BuildContext context) {
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
                    onCreateResume: () =>
                        context.push(RoutePaths.createResumeBuilder),
                    onEmployerDashboard: () =>
                        context.go(RoutePaths.employerDashboard),
                    onFindCandidates: () =>
                        context.push(RoutePaths.employerSearchCandidates),
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
                    onCreateResume: () =>
                        context.push(RoutePaths.createResumeBuilder),
                    onLogin: () => context.go(RoutePaths.login),
                    onRegister: () => context.push(RoutePaths.register),
                    onEmployerLogin: () =>
                        context.push(RoutePaths.employerLogin),
                    onEmployerRegister: () =>
                        context.push(RoutePaths.employerRegister),
                    onAskBuddy: () => ref
                        .read(buddyOverlayOpenRequestProvider.notifier)
                        .requestOpen(),
                    onItJobSeeker: () => _choosePath(
                      () => context.push(RoutePaths.careerDepartments, extra: 'it'),
                    ),
                    onNonItJobSeeker: () => _choosePath(
                      () => context.push(RoutePaths.careerDepartments, extra: 'non-it'),
                    ),
                  ),
                // Phase 37: `landing.html` has no `{% extends %}` — it is
                // standalone, with its own `<footer id="contact">`, never
                // `base.html`'s shared one. An authenticated employer never
                // reaches this template at all (`home()` redirects an
                // employer session to `job_home`, which *does* extend
                // `base.html`, before `landing.html` ever renders) — so
                // [AppFooter] stays exactly where it already was for that
                // one case, and only that case.
                if (user != null && user.isEmployer)
                  const AppFooter()
                else
                  HomeLandingFooter(
                    // Same distinction as each branch's own hero above:
                    // `go` (replace) once authenticated, `push` as a guest —
                    // not a new rule invented for the footer.
                    onFindJobs: () => user != null
                        ? context.go(RoutePaths.dashboard)
                        : context.push(RoutePaths.dashboard),
                    onRegister: () => user != null
                        ? context.go(RoutePaths.dashboard)
                        : context.push(RoutePaths.register),
                    onEmployerLogin: () =>
                        context.push(RoutePaths.employerLogin),
                    onEmployerRegister: () =>
                        context.push(RoutePaths.employerRegister),
                  ),
                // Phase 44: the floating Buddy launcher is fixed to the
                // *viewport*, not to this scrollable content (see
                // `BuddyChatbotOverlay`'s own doc comment) — without this,
                // once a user scrolls all the way down, the last footer
                // links sit permanently underneath it for as long as they
                // stay scrolled to the bottom. 140 ≈ the launcher's own
                // 110px plus its 15px offset plus a small margin, not an
                // arbitrary number.
                const SizedBox(height: 140),
              ],
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}
