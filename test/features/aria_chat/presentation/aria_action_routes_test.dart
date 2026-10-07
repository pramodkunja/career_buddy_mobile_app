import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/aria_chat/presentation/aria_action_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ariaActionFlutterRoute', () {
    test('maps every real ACTION_DEFINITIONS route this app has a screen for (riya_bot/riya_assistant.py)', () {
      final cases = <String, String>{
        '/dashboard/': RoutePaths.dashboard,
        '/activities/': RoutePaths.activities,
        '/activities/?category=speaking': '/activities?category=speaking',
        '/activities/?category=writing': '/activities?category=writing',
        '/activities/?category=vocabulary': '/activities?category=vocabulary',
        '/activities/?category=negotiation': '/activities?category=negotiation',
        '/activities/?category=communication': '/activities?category=communication',
        '/activities/?category=analysis': '/activities?category=analysis',
        '/activities/?category=workshop': RoutePaths.workshopDashboard,
        '/activities/?category=listening': '/activities?category=listening',
        '/dashboard/#recommended-jobs': RoutePaths.dashboard,
        '/subject/tenses.html': RoutePaths.grammarTopic('tenses'),
        '/subject/sentence-structure.html': RoutePaths.grammarTopic('sentence-structure'),
        '/employer/employer/profile/edit/': RoutePaths.employerCompanyProfile,
        '/employer/employer/candidates/search/': RoutePaths.employerSearchCandidates,
        '/employer/employer/jobs/new/': RoutePaths.employerJobCreate,
        '/employer/employer/applications/': RoutePaths.employerAllApplications,
        '/employer/employer/job-openings/': RoutePaths.employerJobOpenings,
        '/users/login/': RoutePaths.login,
        '/users/register/': RoutePaths.register,
        '/employer/accounts/employer/login/': RoutePaths.employerLogin,
        '/employer/accounts/employer/register/': RoutePaths.employerRegister,
        '/skill-up/#depth-english': RoutePaths.skillUpSections,
        '/skill-up/#depth-aptitude': RoutePaths.skillUpSections,
        '/skill-up/#depth-tech': RoutePaths.skillUpSections,
        '/skill-up/#section-depth': RoutePaths.skillUpSections,
        '/skill-up/#section-sitemap': RoutePaths.sitemap,
        '/skill-up/#section-certifications': RoutePaths.skillUpCertifications,
        '/subject/': RoutePaths.grammar,
        '/roleplay/': RoutePaths.roleplayHome,
        '/gd/': RoutePaths.groupDiscussion,
        '/jam/': RoutePaths.jamTopics,
        '/resume-builder/': RoutePaths.resumeBuilder,
        '/resume-builder/analytics/': RoutePaths.resumeBuilder,
        '/pro/': RoutePaths.pro,
      };

      cases.forEach((webRoute, expected) {
        expect(
          ariaActionFlutterRoute(webRoute, isEmployer: false),
          expected,
          reason: 'web route $webRoute',
        );
      });
    });

    test('"/" (home) resolves to the student dashboard for a job seeker and the employer dashboard for an employer', () {
      expect(ariaActionFlutterRoute('/', isEmployer: false), RoutePaths.dashboard);
      expect(ariaActionFlutterRoute('/', isEmployer: true), RoutePaths.employerDashboard);
      expect(ariaActionFlutterRoute('/dashboard/', isEmployer: true), RoutePaths.employerDashboard);
    });

    test('returns null for a route with no in-app screen (about_app\'s deliberately empty route)', () {
      expect(ariaActionFlutterRoute('', isEmployer: false), isNull);
    });

    test('returns null for an unrecognized route instead of guessing', () {
      expect(ariaActionFlutterRoute('/something/not/in/the/catalog/', isEmployer: false), isNull);
    });
  });
}
