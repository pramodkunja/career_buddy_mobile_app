import 'package:career_buddy_lms/features/skill_up/data/tech_center_catalog.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 76 — validates the GENERATED catalog's own internal consistency
/// (uniqueness, non-empty fields, correct path nesting). The cross-check
/// against the real on-disk `TechCenter/<dept>/<role>/*.html` files happens
/// once, at generation time, inside `tool/generate_tech_center_catalog
/// .dart` itself (printed there as "Parsed 10 departments, 93 roles, 383
/// courses... Cross-validation: every on-disk nested file is linked, and
/// every linked path exists on disk. Exact match.") — this test suite does
/// not re-read the Django reference tree, so it runs in a normal
/// `flutter test` with no dependency on that separate checkout's location.
void main() {
  group('kTechCenterDepartments', () {
    test('has exactly the counts confirmed by the generator at generation time '
        '(10 departments, 93 roles, 383 courses — matching Phase 75\'s own confirmed file count)', () {
      expect(kTechCenterDepartments.length, 10);
      final roleCount = kTechCenterDepartments.fold(0, (n, d) => n + d.roles.length);
      expect(roleCount, 93);
      final courseCount = kTechCenterDepartments.fold(0, (n, d) => n + d.roles.fold(0, (m, r) => m + r.courses.length));
      expect(courseCount, 383);
    });

    test('every department slug is unique', () {
      final slugs = kTechCenterDepartments.map((d) => d.slug).toList();
      expect(slugs.toSet().length, slugs.length);
    });

    test('every (department slug, role slug) pair is unique, even though a small number of role '
        'slugs are intentionally reused across two different departments on the real site '
        '(e.g. "devops-engineer" under both Development and DevOps/Infrastructure)', () {
      final compoundKeys = [
        for (final d in kTechCenterDepartments) for (final r in d.roles) '${d.slug}/${r.slug}',
      ];
      expect(compoundKeys.toSet().length, compoundKeys.length);
    });

    test('every course relativePath is globally unique — no lesson is listed under two roles', () {
      final paths = [
        for (final d in kTechCenterDepartments) for (final r in d.roles) for (final c in r.courses) c.relativePath,
      ];
      expect(paths.toSet().length, paths.length);
    });

    test('every course relativePath is correctly nested under its own department/role '
        '(TechCenter/<deptSlug>/<roleSlug>/...) — catches a mismatched parent reference', () {
      for (final department in kTechCenterDepartments) {
        for (final role in department.roles) {
          for (final course in role.courses) {
            expect(
              course.relativePath,
              startsWith('TechCenter/${department.slug}/${role.slug}/'),
              reason: '"${course.relativePath}" should be nested under '
                  'TechCenter/${department.slug}/${role.slug}/',
            );
          }
        }
      }
    });

    test('no department, role, or course has a blank title/slug/category', () {
      for (final department in kTechCenterDepartments) {
        expect(department.slug, isNotEmpty);
        expect(department.title.trim(), isNotEmpty);
        expect(department.roles, isNotEmpty, reason: '"${department.title}" has no roles');
        for (final role in department.roles) {
          expect(role.slug, isNotEmpty);
          expect(role.title.trim(), isNotEmpty);
          expect(role.category.trim(), isNotEmpty);
          expect(role.courses, isNotEmpty, reason: '"${role.title}" has no courses');
          for (final course in role.courses) {
            expect(course.title.trim(), isNotEmpty);
            expect(course.relativePath, isNotEmpty);
          }
        }
      }
    });

    test('every role\'s category is one of the real page\'s own 2 top-level groupings', () {
      const knownCategories = {'Product and Engineering', 'Business and Support'};
      for (final department in kTechCenterDepartments) {
        for (final role in department.roles) {
          expect(
            knownCategories.contains(role.category),
            isTrue,
            reason: 'Unexpected category "${role.category}" for "${role.title}" — if the real site added a new '
                'category this is a real change to re-verify, not necessarily a bug.',
          );
        }
      }
    });
  });
}
