import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/theme_provider.dart';
import '../../core/media/media_url_resolver.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/employer/domain/entities/employer_profile_form.dart';
import '../../features/employer/presentation/controllers/employer_profile_controller.dart';
import '../../features/home/presentation/providers/home_scroll_request_provider.dart';

/// The web nav's collapsed mobile-menu content
/// (`templates/includes/site_nav.html:192-258`, `cbMobileMenu`),
/// reproduced as a `Drawer` — see [AppTopBar]'s doc comment for why a
/// drawer is the faithful mobile equivalent, not an invented pattern.
///
/// Phase 71 — correcting Phase 67's own structural assumption: the real
/// site does **not** show a guest a stripped-down menu and a signed-in
/// candidate a different, richer one. `site_nav.html`'s `{% else %}`
/// branch (`:205`) covers **both** an anonymous guest and an authenticated
/// non-employer candidate with almost the identical item list — the one
/// and only difference is an extra "Dashboard" link inserted once
/// authenticated (`:236-238`). This drawer's non-employer branch mirrors
/// that: one shared list of items, with "Dashboard" conditional on
/// [user] being non-null and the trailing area switching between the 2
/// login tiles (guest) and Profile/Logout (authenticated) — not two
/// separate, differently-structured branches the way this file had before.
///
/// Every Skill Up/Resources item resolves through the real site's
/// `{% url 'nav_go' key %}` gateway (`core/navigation.py`'s `NAV_MAP`),
/// and **every one of those keys is server-side `@login_required`**
/// (confirmed directly: `NAV_MAP`'s `protected` flag defaults to `True`
/// with no override in the file, plus the underlying views themselves are
/// independently decorated). So on the real site, a guest sees the full
/// Skill Up/Resources menus but is redirected to login the moment they tap
/// almost anything in them — the menu's *visibility* isn't gated, only the
/// destination is. This drawer matches that exactly for free: none of
/// [RoutePaths.skillUp]/[RoutePaths.skillUpSections]/
/// [RoutePaths.skillUpCertifications]/[RoutePaths.grammar]/
/// [RoutePaths.activities]/[RoutePaths.pro]/[RoutePaths.sitemap] are in
/// [RoutePaths.publicRoutes] or [RoutePaths.universalRoutes], so the
/// existing route guard already bounces an unauthenticated tap to
/// `/login` — no separate guest/authenticated branching had to be added
/// here to reproduce that.
///
/// "About Us"/"Industries"/the Resources submenu's "Tutorials: How
/// CareerBuddy Works" are same-page anchors on the real landing page
/// (`#why`/`#choose-path`/`#videos`) with no dedicated screen — see
/// [homeScrollRequestProvider]'s own doc comment for how this drawer asks
/// [HomeScreen] to scroll to the matching, already-built section instead
/// of inventing a new destination. "Contact Us" (`#contact`) is a fourth
/// such anchor, but to the page's own footer rather than a distinct
/// section — the real footer has no phone/email/contact form either, just
/// the same link columns [HomeLandingFooter] already reproduces, so
/// scrolling there is a complete, faithful match, not a partial one.
///
/// Phase 73 — the employer branch (`user.isEmployer`), audited for the
/// first time since Phase 67's own stale claim ("only 'Post New Job'
/// still routes to a ComingSoonScreen placeholder"): re-verified directly
/// against `app_router.dart` that **all 6 destinations are real, built
/// screens** — that claim was already wrong before this phase even
/// started (`_goComingSoon` is just a generic pop-then-push helper with a
/// misleading name, not a placeholder marker; see `UI-A-009`).
///
/// Confirmed the real site has **two** employer nav surfaces, not one:
/// `site_nav.html`'s own 3-item employer branch (`:199-204` — "Employer
/// Dashboard"/"Jobs"/"Company Profile") and `templates/employer_base.html`'s
/// 6-item sidebar (`:214-238` — Dashboard/Post New Job/All Applications/
/// Company Profile/Job Openings/Candidate Search), stacked on every
/// employer page that extends that layout. Read that template's own CSS
/// (`:138-170`) directly: at mobile widths the sidebar is **not** hidden —
/// `.employer-shell` just stacks it above the page content and its own
/// `.nav` reflows into a full-width button grid, still fully visible and
/// tappable. So a real mobile employer already sees both surfaces'
/// content; consolidating them into one drawer (a deliberate choice since
/// Phase authoring began, confirmed still correct) is a faithful mobile
/// adaptation, not an invented structure.
///
/// **New this phase**: "Jobs" (`site_nav.html`'s own `{% url 'job_home' %}`
/// link) was missing entirely — confirmed a real, distinct destination
/// from "Job Openings" (`jobs_app.views.home`, "Recruiter Portal Landing
/// Page", `jobs/employer_home.html`, vs. `jobs_app.views.job_openings`'s
/// actual openings list) — Flutter already had the matching, already-built
/// [RoutePaths.employerHome]/`EmployerHomeScreen` (the real post-login/
/// -registration redirect target) wired into the router and
/// [RoutePaths.universalRoutes], just never linked from this drawer. Added
/// here, reusing that existing screen — no new screen, route, or backend
/// call introduced.
///
/// "Company Profile" appears on the real site in both surfaces pointing at
/// the identical `employer_portal:employer_profile_edit` destination — this
/// drawer already had exactly one entry for it, correctly deduplicated,
/// unchanged this phase. "Employer Dashboard" (this drawer's existing
/// label) vs. the sidebar's own shorter "Dashboard" are two different real
/// labels the site itself uses for the same destination; kept as-is — not
/// a staleness to correct, just two valid real wordings for one feature.
///
/// **Phase 74 — the identity tile now shows the real company name/logo**,
/// closing the gap Phase 73 found and deliberately deferred. The real
/// sidebar's own identity block (`templates/employer_base.html:198-213`)
/// shows the employer's company name and logo
/// (`request.user.employer_profile.company_name`/`.company_logo`, with a
/// static "Recruiter Account" badge) rather than a personal username.
/// Investigated first whether this data already reaches Flutter through any
/// existing fetch: `employer/profile_form.html` (parsed by
/// `parseEmployerProfileFormHtml` for the existing Company Profile screen)
/// itself `{% extends 'employer_base.html' %}`, so the exact same response
/// already fetched for that screen — reached from this very drawer's own
/// "Company Profile" tap — already carries the sidebar's identity markup
/// too. [EmployerProfileFormData.companyLogoUrl] scrapes it from that same
/// response (see that parser's own doc comment); the company name reuses
/// the field [EmployerProfileFormData] already parsed. No new endpoint, no
/// new request pattern, and no second competing data source were
/// introduced — this drawer watches the same
/// [employerProfileControllerProvider] the Company Profile screen already
/// uses, which [AuthController] already invalidates on every
/// login/logout/register transition, so a stale company identity cannot
/// leak across sessions. While unresolved (still loading, or no profile
/// saved yet) the tile shows the real site's own fallback — a generic
/// business icon and the literal "Employer Portal" text
/// (`employer_base.html:207-209`'s own `|default:"Employer Portal"`) —
/// never a blank, invented, or stale value.
///
/// **Re-checked this phase, not a bug**: logging out while on
/// [RoutePaths.employerJobOpenings] does land on the candidate login
/// screen rather than the employer one — but that is already a deliberate,
/// pre-existing, independently-tested choice from an earlier phase (Phase
/// 1 Critical Fixes, `route_guards_test.dart`'s own
/// `'employerJobOpenings is not a member of employerProtectedRoutes'` and
/// `'an unauthenticated hit on employerJobOpenings bounces to the student
/// login, not the employer one'`), matching the real backend's own
/// `jobs_app.views.job_openings` being plain `@login_required` with no
/// employer-portal-session check — confirmed directly, not inferred. It is
/// not a logout-specific defect this phase introduces or needs to fix.
/// [RoutePaths.employerHome] has no such case at all: it is a member of
/// [RoutePaths.universalRoutes], so an unauthenticated hit renders the same
/// public page for every session rather than redirecting anywhere
/// (`'Employer Home is reachable by both auth states, same as Home'`,
/// same test file) — this matches `jobs_app.views.home`'s own real
/// behavior (no `@login_required` at all, confirmed directly in source).
class AppNavDrawer extends ConsumerWidget {
  const AppNavDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    // Phase 74 — the same already-fetched response the drawer's own
    // "Company Profile" tap already targets (`RoutePaths.employerCompanyProfile`
    // -> `isCreate: false`), reused here for the identity tile below rather
    // than a second request. Collapsing "still loading" and "failed" (e.g.
    // no profile saved yet) to the same `null` the fallback below already
    // handles is never a crash or a stale cross-session value, since
    // [employerProfileControllerProvider] is a `.family` provider
    // `AuthController` already invalidates on every login/logout/register
    // transition (`_invalidateUserScopedProviders`).
    final employerProfile = user != null && user.isEmployer
        ? switch (ref.watch(employerProfileControllerProvider(false))) {
            AsyncData(:final value) => value,
            _ => null,
          }
        : null;

    return Drawer(
      child: SafeArea(
        // A plain, eager `Column` rather than a `ListView` — this menu is a
        // small, bounded list (at most ~30 tiles with both submenus open),
        // never an unbounded feed, so there's nothing to gain from a
        // `ListView`'s lazy sliver virtualization, and eagerly building
        // every tile avoids any pop-in once a submenu is expanded and
        // scrolled into view.
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavTile(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(RoutePaths.home);
                },
              ),
              if (user != null && user.isEmployer) ...[
                _NavTile(
                  icon: Icons.dashboard_outlined,
                  label: 'Employer Dashboard',
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(RoutePaths.employerDashboard);
                  },
                ),
                // Phase 73 — matches `site_nav.html`'s own employer-branch
                // "Jobs" link (`{% url 'job_home' %}`) — a real, distinct
                // destination (the Recruiter Portal landing page,
                // `EmployerHomeScreen`) that already existed in Flutter's
                // router but had no drawer entry point until now.
                _NavTile(
                  icon: Icons.home_outlined,
                  label: 'Jobs',
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(RoutePaths.employerHome);
                  },
                ),
                _NavTile(
                  icon: Icons.post_add_outlined,
                  label: 'Post New Job',
                  onTap: () =>
                      _goComingSoon(context, RoutePaths.employerJobCreate),
                ),
                _NavTile(
                  icon: Icons.description_outlined,
                  label: 'All Applications',
                  onTap: () => _goComingSoon(
                    context,
                    RoutePaths.employerAllApplications,
                  ),
                ),
                _NavTile(
                  icon: Icons.business_outlined,
                  label: 'Company Profile',
                  onTap: () =>
                      _goComingSoon(context, RoutePaths.employerCompanyProfile),
                ),
                _NavTile(
                  icon: Icons.work_outline,
                  label: 'Job Openings',
                  onTap: () =>
                      _goComingSoon(context, RoutePaths.employerJobOpenings),
                ),
                _NavTile(
                  icon: Icons.search,
                  label: 'Candidate Search',
                  onTap: () => _goComingSoon(
                    context,
                    RoutePaths.employerSearchCandidates,
                  ),
                ),
                const Divider(height: 1),
                const _ThemeToggleTile(),
                _EmployerIdentityTile(
                  profile: employerProfile,
                  onTap: () =>
                      _goComingSoon(context, RoutePaths.employerCompanyProfile),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(authControllerProvider.notifier).logout();
                  },
                ),
              ] else ...[
                // Phase 71 — matches `site_nav.html:206-242`'s exact item
                // list and order for BOTH a guest and an authenticated
                // non-employer candidate (see this class's own doc comment
                // for why these are one shared branch now, not two).
                _NavTile(
                  icon: Icons.info_outline,
                  label: 'About Us',
                  onTap: () =>
                      _scrollHome(context, ref, HomeScrollTarget.about),
                ),
                ExpansionTile(
                  leading: const Icon(
                    Icons.layers_outlined,
                    color: AppColors.textMuted,
                  ),
                  title: const Text('Skill Up'),
                  childrenPadding: const EdgeInsets.only(left: AppSpacing.md),
                  children: [
                    _NavTile(
                      icon: Icons.language_outlined,
                      label: 'English Learning',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.skillUpSectionsFor('depth-english'),
                      ),
                    ),
                    _NavTile(
                      icon: Icons.spellcheck_outlined,
                      label: 'Grammar',
                      onTap: () => _goComingSoon(context, RoutePaths.grammar),
                    ),
                    // Deliberately the same destination as "English
                    // Learning" above — `navigation.py:57-65`'s own comment
                    // confirms this pairing is intentional on the real site
                    // too ("'English & Vocabulary' is the depth-english
                    // article on the hub"), not a mistake to "fix" by
                    // inventing a distinct vocabulary screen.
                    _NavTile(
                      icon: Icons.menu_book_outlined,
                      label: 'Vocabulary & Idioms',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.skillUpSectionsFor('depth-english'),
                      ),
                    ),
                    _NavTile(
                      icon: Icons.record_voice_over_outlined,
                      label: 'Speaking & Presentation',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.activitiesWithCategory('speaking'),
                      ),
                    ),
                    _NavTile(
                      icon: Icons.edit_note_outlined,
                      label: 'Writing & Correspondence',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.activitiesWithCategory('writing'),
                      ),
                    ),
                    _NavTile(
                      icon: Icons.handshake_outlined,
                      label: 'Negotiation & Meetings',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.activitiesWithCategory('negotiation'),
                      ),
                    ),
                    // `site_nav.html`'s own visible label for this item —
                    // `core/navigation.py`'s internal label for the same key
                    // is "Interactive Workshop" instead; the template's text
                    // is what a user actually sees, so that's what this tile
                    // uses.
                    _NavTile(
                      icon: Icons.theater_comedy_outlined,
                      label: 'Interactive Roleplay',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.activitiesWithCategory('workshop'),
                      ),
                    ),
                    // Phase 72 — "Aptitude"/"Tech" now scroll straight to
                    // their own distinct `depth-aptitude`/`depth-tech`
                    // articles within the "Sections in depth" tab, matching
                    // the real site's own `?section=` targets exactly (see
                    // `RoutePaths.skillUpSectionsFor`'s own doc comment).
                    _NavTile(
                      icon: Icons.psychology_outlined,
                      label: 'Aptitude',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.skillUpSectionsFor('depth-aptitude'),
                      ),
                    ),
                    _NavTile(
                      icon: Icons.code_outlined,
                      label: 'Tech',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.skillUpSectionsFor('depth-tech'),
                      ),
                    ),
                    _NavTile(
                      icon: Icons.verified_outlined,
                      label: 'Certifications',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.skillUpCertifications,
                      ),
                    ),
                  ],
                ),
                ExpansionTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: AppColors.textMuted,
                  ),
                  title: const Text('Resources'),
                  childrenPadding: const EdgeInsets.only(left: AppSpacing.md),
                  children: [
                    _NavTile(
                      icon: Icons.hub_outlined,
                      label: 'Skill Up Hub',
                      onTap: () => _goComingSoon(context, RoutePaths.skillUp),
                    ),
                    _NavTile(
                      icon: Icons.grid_view_rounded,
                      label: 'Activities',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(RoutePaths.activities);
                      },
                    ),
                    _NavTile(
                      icon: Icons.verified_outlined,
                      label: 'Certifications',
                      onTap: () => _goComingSoon(
                        context,
                        RoutePaths.skillUpCertifications,
                      ),
                    ),
                    _NavTile(
                      icon: Icons.play_circle_outline,
                      label: 'Tutorials: How CareerBuddy Works',
                      onTap: () =>
                          _scrollHome(context, ref, HomeScrollTarget.tutorials),
                    ),
                    _NavTile(
                      icon: Icons.account_tree_outlined,
                      label: 'Sitemap',
                      onTap: () => _goComingSoon(context, RoutePaths.sitemap),
                    ),
                    _NavTile(
                      icon: Icons.workspace_premium_outlined,
                      label: 'CareerBuddy Pro',
                      onTap: () => _goComingSoon(context, RoutePaths.pro),
                    ),
                  ],
                ),
                // The one and only item that differs between guest and
                // authenticated in this entire branch on the real site
                // (`site_nav.html:236-238`).
                if (user != null)
                  _NavTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'Dashboard',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(RoutePaths.dashboard);
                    },
                  ),
                _NavTile(
                  icon: Icons.groups_outlined,
                  label: 'Industries',
                  onTap: () =>
                      _scrollHome(context, ref, HomeScrollTarget.choosePath),
                ),
                _NavTile(
                  icon: Icons.description_outlined,
                  label: 'Create Resume',
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push(RoutePaths.createResumeBuilder);
                  },
                ),
                _NavTile(
                  icon: Icons.mail_outline,
                  label: 'Contact Us',
                  onTap: () =>
                      _scrollHome(context, ref, HomeScrollTarget.contact),
                ),
                const Divider(height: 1),
                const _ThemeToggleTile(),
                if (user != null) ...[
                  ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        user.username.length >= 2
                            ? user.username.substring(0, 2).toUpperCase()
                            : user.username.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(user.username),
                    onTap: () => _goComingSoon(context, RoutePaths.profile),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.danger),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      ref.read(authControllerProvider.notifier).logout();
                    },
                  ),
                ] else ...[
                  _NavTile(
                    icon: Icons.person_outline,
                    label: 'Job Seeker Login',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(RoutePaths.login);
                    },
                  ),
                  _NavTile(
                    icon: Icons.apartment_outlined,
                    label: 'Employer Login',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(RoutePaths.employerLogin);
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _goComingSoon(BuildContext context, String path) {
    Navigator.of(context).pop();
    context.push(path);
  }

  /// Backs "About Us"/"Industries"/"Tutorials: How CareerBuddy Works"/
  /// "Contact Us" — see [homeScrollRequestProvider]'s own doc comment.
  /// `go`, not `push`: these are anchors on the one Home page, not a new
  /// stack entry, matching how a real in-page anchor never adds browser
  /// history either.
  void _scrollHome(
    BuildContext context,
    WidgetRef ref,
    HomeScrollTarget target,
  ) {
    Navigator.of(context).pop();
    ref.read(homeScrollRequestProvider.notifier).request(target);
    context.go(RoutePaths.home);
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textMuted),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _ThemeToggleTile extends ConsumerWidget {
  const _ThemeToggleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      secondary: const Icon(Icons.dark_mode_outlined),
      title: const Text('Dark Mode'),
      value: isDark,
      onChanged: (_) => ref
          .read(themeModeProvider.notifier)
          .toggle(Theme.of(context).brightness),
    );
  }
}

/// Phase 74 — `employer_base.html:198-213`'s own sidebar identity block:
/// the company logo (a generic icon when none is on file, or while
/// [profile] hasn't resolved yet), the company name (falling back to the
/// real site's own literal `|default:"Employer Portal"` text the same way),
/// and the real site's own static "Recruiter Account" label.
class _EmployerIdentityTile extends StatelessWidget {
  const _EmployerIdentityTile({required this.profile, required this.onTap});

  final EmployerProfileFormData? profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logoUrl = resolveMediaUrl(profile?.companyLogoUrl);
    final companyName = profile?.companyName.trim();
    final displayName = (companyName == null || companyName.isEmpty)
        ? 'Employer Portal'
        : companyName;

    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primary,
        child: logoUrl == null
            ? const Icon(Icons.business, color: Colors.white, size: 16)
            : ClipOval(
                child: Image.network(
                  logoUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.business, color: Colors.white, size: 16),
                ),
              ),
      ),
      title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: const Text('Recruiter Account'),
      onTap: onTap,
    );
  }
}
