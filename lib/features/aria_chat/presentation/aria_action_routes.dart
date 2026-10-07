import '../../../app/router/route_paths.dart';

/// Maps a `reply.actions[].route` web path (`riya_bot/riya_assistant.py`'s
/// `ACTION_DEFINITIONS`, confirmed directly against source — see that
/// dict's literal `route` values) to this app's own in-app route, so
/// tapping an action chip — or the auto-navigate-after-speech behavior the
/// real main widget has for a single-action `intent`/`skillup` reply
/// (`commitNavigation`, `BOTscript.js`) — actually goes somewhere, instead
/// of the previous placeholder behavior of just re-sending the label as a
/// new chat message.
///
/// [isEmployer] disambiguates the handful of web routes that mean
/// different things depending on portal (`"/"`/`"/dashboard/"` is the
/// student dashboard for a job seeker but has no real employer equivalent
/// other than the employer dashboard itself).
///
/// Returns `null` for a route this app has no screen for (today: only
/// `about_app`'s deliberately empty `""` route, which is a text-only
/// response with nothing to navigate to) — callers fall back to their own
/// existing safe behavior (re-sending the action's label as a message)
/// rather than navigating nowhere.
String? ariaActionFlutterRoute(String webRoute, {required bool isEmployer}) {
  switch (webRoute) {
    case '/':
    case '/dashboard/':
      return isEmployer ? RoutePaths.employerDashboard : RoutePaths.dashboard;
    // The web's `#recommended-jobs` in-page anchor — this app's dashboard
    // has no separate scroll-target route, so this lands on the same
    // screen as the plain dashboard route above.
    case '/dashboard/#recommended-jobs':
      return RoutePaths.dashboard;

    case '/activities/':
      return RoutePaths.activities;
    case '/activities/?category=speaking':
      return RoutePaths.activitiesWithCategory('speaking');
    case '/activities/?category=writing':
      return RoutePaths.activitiesWithCategory('writing');
    case '/activities/?category=vocabulary':
      return RoutePaths.activitiesWithCategory('vocabulary');
    case '/activities/?category=negotiation':
      return RoutePaths.activitiesWithCategory('negotiation');
    case '/activities/?category=communication':
      return RoutePaths.activitiesWithCategory('communication');
    case '/activities/?category=analysis':
      return RoutePaths.activitiesWithCategory('analysis');
    // Workshop's real screen (`WorkshopDashboardScreen`) reads from a
    // Free-Plan-safe dedicated endpoint rather than the filtered activity
    // list a plain `?category=workshop` would hit — see
    // `ApiEndpoints.workshopDashboardHtml`'s doc comment.
    case '/activities/?category=workshop':
      return RoutePaths.workshopDashboard;
    case '/activities/?category=listening':
      return RoutePaths.activitiesWithCategory('listening');

    case '/employer/employer/profile/edit/':
      return RoutePaths.employerCompanyProfile;
    case '/employer/employer/candidates/search/':
      return RoutePaths.employerSearchCandidates;
    case '/employer/employer/jobs/new/':
      return RoutePaths.employerJobCreate;
    case '/employer/employer/applications/':
      return RoutePaths.employerAllApplications;
    case '/employer/employer/job-openings/':
      return RoutePaths.employerJobOpenings;

    case '/users/login/':
      return RoutePaths.login;
    case '/users/register/':
      return RoutePaths.register;
    case '/employer/accounts/employer/login/':
      return RoutePaths.employerLogin;
    case '/employer/accounts/employer/register/':
      return RoutePaths.employerRegister;

    // The real web's anchors (`#depth-english`/`#depth-aptitude`/`#depth-tech`
    // /`#section-depth`) all scroll within the same single Skill Up page —
    // this app's closest equivalent is the "Sections in depth" tab
    // (`RoutePaths.skillUpSections`), not a separate screen per anchor.
    case '/skill-up/#depth-english':
    case '/skill-up/#depth-aptitude':
    case '/skill-up/#depth-tech':
    case '/skill-up/#section-depth':
      return RoutePaths.skillUpSections;
    case '/skill-up/#section-sitemap':
      return RoutePaths.sitemap;
    case '/skill-up/#section-certifications':
      return RoutePaths.skillUpCertifications;

    case '/subject/':
      return RoutePaths.grammar;
    // The welcome-card feature's two grammar sub-topic actions
    // (`grammar_tenses`/`grammar_sentence_structure`, `aria_welcome_catalog.g.dart`)
    // — this app's own grammar topic slugs (`grammar_slide_deck.dart`'s
    // `kGrammarSlideDeckCounts`) match the web's `.html` filenames exactly.
    case '/subject/tenses.html':
      return RoutePaths.grammarTopic('tenses');
    case '/subject/sentence-structure.html':
      return RoutePaths.grammarTopic('sentence-structure');
    case '/roleplay/':
      return RoutePaths.roleplayHome;
    case '/gd/':
      return RoutePaths.groupDiscussion;
    case '/jam/':
      return RoutePaths.jamTopics;

    // `mock_interview`/`job_search` both point at `/resume-builder/`-rooted
    // web pages whose content (Job Recommendations, the AI Mock Interview
    // entry point) already lives inside this app's single
    // `ResumeBuilderScreen`, not a separate screen — matching the real
    // routes' own convergence on the same underlying page.
    case '/resume-builder/':
    case '/resume-builder/analytics/':
      return RoutePaths.resumeBuilder;

    case '/pro/':
      return RoutePaths.pro;

    default:
      return null;
  }
}
