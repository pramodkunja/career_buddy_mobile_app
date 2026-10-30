import 'package:career_buddy_lms/app/router/skill_up_sections_route.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_nonit_deep_link_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/skill_up_screen.dart';
import 'package:career_buddy_lms/features/skill_up/presentation/screens/tech_center_roles_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 79 — exercises the actual navigation-target logic behind
/// `RoutePaths.skillUpSections`'s `GoRoute` builder directly (kept in its
/// own pure function, `buildSkillUpSectionsScreen`, for exactly this reason
/// — see its own doc comment), rather than only checking that an id string
/// contains a particular prefix.
void main() {
  group('buildSkillUpSectionsScreen', () {
    test(
      'a real Tech Center department id builds TechCenterRolesScreen for the correct department',
      () {
        final widget = buildSkillUpSectionsScreen('grp-tech-development');

        expect(widget, isA<TechCenterRolesScreen>());
        final screen = widget as TechCenterRolesScreen;
        expect(screen.department.slug, 'development');
        expect(screen.highlightRoleSlug, isNull);
      },
    );

    test(
      'a real Tech Center role id builds TechCenterRolesScreen for the correct department, highlighting '
      'the correct role',
      () {
        final widget = buildSkillUpSectionsScreen(
          'role-tech-development--software-developer',
        );

        expect(widget, isA<TechCenterRolesScreen>());
        final screen = widget as TechCenterRolesScreen;
        expect(screen.department.slug, 'development');
        expect(screen.highlightRoleSlug, 'software-developer');
      },
    );

    test(
      'a reused Tech Center role slug resolves to its own distinct department, not a different one sharing '
      'the same role slug',
      () {
        final inDevelopment =
            buildSkillUpSectionsScreen('role-tech-development--devops-engineer')
                as TechCenterRolesScreen;
        final inInfrastructure =
            buildSkillUpSectionsScreen(
                  'role-tech-devops-infrastructure--devops-engineer',
                )
                as TechCenterRolesScreen;

        expect(inDevelopment.department.slug, 'development');
        expect(inInfrastructure.department.slug, 'devops-infrastructure');
      },
    );

    test(
      'a real Non-IT department id builds the Non-IT deep-link resolver',
      () {
        final widget = buildSkillUpSectionsScreen('grp-nonit-development');

        expect(widget, isA<SkillUpNonItDeepLinkScreen>());
      },
    );

    test('a real Non-IT role id also builds the Non-IT deep-link resolver', () {
      final widget = buildSkillUpSectionsScreen(
        'role-nonit-development--some-role',
      );

      expect(widget, isA<SkillUpNonItDeepLinkScreen>());
    });

    test(
      'a well-formed Tech Center department id that does not exist in the catalog falls back to '
      'SkillUpScreen — the same safe fallback an unrecognized depth-* id already gets',
      () {
        final widget = buildSkillUpSectionsScreen(
          'grp-tech-this-department-does-not-exist',
        );

        expect(widget, isA<SkillUpScreen>());
      },
    );

    test(
      'a well-formed Tech Center role id whose department exists but role does not falls back to '
      'SkillUpScreen',
      () {
        final widget = buildSkillUpSectionsScreen(
          'role-tech-development--this-role-does-not-exist',
        );

        expect(widget, isA<SkillUpScreen>());
      },
    );

    test(
      'the existing depth-* section ids still build SkillUpScreen with the same initialSectionId, unchanged',
      () {
        for (final id in ['depth-english', 'depth-aptitude', 'depth-tech']) {
          final widget = buildSkillUpSectionsScreen(id) as SkillUpScreen;
          expect(widget.initialSectionId, id);
          expect(widget.initialTabIndex, 1);
        }
      },
    );

    test(
      'a missing section id builds SkillUpScreen with a null initialSectionId, unchanged',
      () {
        final widget = buildSkillUpSectionsScreen(null) as SkillUpScreen;
        expect(widget.initialSectionId, isNull);
      },
    );

    test(
      'a malformed/unknown id does not crash and falls back to SkillUpScreen',
      () {
        for (final id in [
          '',
          'not-a-real-id',
          'GRP-TECH-development',
          'role-tech-onlyonepart',
        ]) {
          expect(() => buildSkillUpSectionsScreen(id), returnsNormally);
          expect(buildSkillUpSectionsScreen(id), isA<SkillUpScreen>());
        }
      },
    );
  });
}
