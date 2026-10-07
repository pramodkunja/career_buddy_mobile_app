import '../../../app/router/route_paths.dart';

/// Maps the current in-app route to one of `SECTION_CONTEXT`'s keys —
/// mirrors `getAssistantSection()` (`static/js/BOTscript.js`), re-read
/// directly against the live, deployed copy of that file (this function
/// doesn't exist in the checked-out Django repo's stale copy — see
/// `aria_welcome_card.dart`'s doc comment).
///
/// Not a literal 1:1 port — the real function keys off Django URL
/// prefixes/in-page hashes (`#recommended-jobs`, `#depth-english`,
/// `#section-certifications`, ...) that have no Flutter route equivalent,
/// since this app's screens don't carry that extra state in the URL the
/// way the web's own hash-routed single-page sections do. Two deliberate,
/// honest simplifications follow from that:
/// - `jobs` (the dashboard's `#recommended-jobs` anchor) is folded into
///   plain `dashboard` — this app's dashboard is one screen, not a page the
///   assistant can detect a scroll position within.
/// - `skillup_english`/`skillup_aptitude`/`skillup_tech`/`skillup_certs`
///   collapse to plain `skillup`, except for the one sub-route that *does*
///   have its own distinct screen/path in this app
///   ([RoutePaths.skillUpCertifications]).
///
/// [path] is a route path as `BuddyChatbotOverlay._currentRoute()` already
/// produces it (may include a query string, e.g.
/// `/activities?category=workshop` — matching this app's own
/// [RoutePaths.activitiesWithCategory]).
String ariaWelcomeSection({required String path, required bool isEmployer}) {
  final uri = Uri.tryParse(path) ?? Uri();
  final p = uri.path;

  if (isEmployer) {
    if (p.startsWith(RoutePaths.employerAllApplications)) return 'employer_applications';
    if (p.startsWith(RoutePaths.employerSearchCandidates)) return 'employer_candidates';
    if (p.startsWith(RoutePaths.employerJobCreate) || p.startsWith(RoutePaths.employerJobOpenings)) {
      return 'employer_jobs';
    }
    if (p.startsWith('/employer-jobs/')) return 'employer_jobs';
    if (p.startsWith(RoutePaths.employerHome) ||
        p.startsWith(RoutePaths.employerDashboard) ||
        p.startsWith(RoutePaths.employerCompanyProfile)) {
      return 'employer';
    }
  }

  // Checked before the general activities prefix below — `/activities/workshop`
  // would otherwise also match `RoutePaths.activities`.
  if (p.startsWith(RoutePaths.workshopDashboard)) return 'workshop';
  if (p.startsWith(RoutePaths.activities)) return 'activities';

  if (p.startsWith(RoutePaths.skillUpCertifications)) return 'skillup_certs';
  if (p.startsWith(RoutePaths.skillUp)) return 'skillup';

  if (p.startsWith(RoutePaths.dashboard)) return 'dashboard';
  if (p.startsWith(RoutePaths.resumeBuilder)) return 'resume';
  if (p.startsWith(RoutePaths.grammar)) return 'grammar';
  if (p.startsWith(RoutePaths.groupDiscussion) ||
      p.startsWith(RoutePaths.jamTopics) ||
      p.startsWith(RoutePaths.roleplayHome)) {
    return 'workshop';
  }
  if (p.startsWith(RoutePaths.profile)) return 'profile';
  if (p.startsWith(RoutePaths.pro)) return 'pro';
  if (p == RoutePaths.home || p == RoutePaths.splash) return 'home';
  return '';
}
