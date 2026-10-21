import 'package:career_buddy_lms/features/resume/data/career_departments_asset_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerDepartmentsAssetDataSource dataSource;

  setUp(() {
    dataSource = CareerDepartmentsAssetDataSource();
  });

  group('IT departments (assets/data/it_departments.json)', () {
    test('loads exactly the real 2 groups with their real department counts', () async {
      final groups = await dataSource.load('it');

      expect(groups, hasLength(2));
      expect(groups[0].label, 'Product and Engineering');
      expect(groups[0].departments, hasLength(6));
      expect(groups[1].label, 'Business and Support');
      expect(groups[1].departments, hasLength(4));
    });

    test('every department role carries the real category and multiple labeled skill groups', () async {
      final groups = await dataSource.load('it');
      final development = groups[0].departments.firstWhere((d) => d.name == 'Development');

      expect(development.category, 'it');
      final softwareDeveloper = development.roles.firstWhere((r) => r.name == 'Software Developer');
      expect(softwareDeveloper.skillGroups, isNotEmpty);
      // IT roles have one labeled group per source "Category: a, b" line —
      // never collapsed into a single flat list.
      expect(softwareDeveloper.skillGroups.length, greaterThan(1));
      expect(softwareDeveloper.skillGroups.first.label, isNotEmpty);
      expect(softwareDeveloper.skillGroups.first.skills, isNotEmpty);
    });

    test('a skills line like "Core Languages: Python, Java, C++, or C#" splits correctly', () async {
      final groups = await dataSource.load('it');
      final development = groups[0].departments.firstWhere((d) => d.name == 'Development');
      final softwareDeveloper = development.roles.firstWhere((r) => r.name == 'Software Developer');
      final coreLanguages = softwareDeveloper.skillGroups.firstWhere((g) => g.label == 'Core Languages');

      // splitSk() strips a leading "or "/"and " and capitalizes the first
      // letter — "or C#" becomes "C#", confirmed against the real source.
      expect(coreLanguages.skills, contains('Python'));
      expect(coreLanguages.skills, contains('Java'));
      expect(coreLanguages.skills, contains('C++'));
      expect(coreLanguages.skills, contains('C#'));
      expect(coreLanguages.skills.any((s) => s.startsWith('or ')), isFalse);
    });

    test('caches after the first load (same instance returned)', () async {
      final first = await dataSource.load('it');
      final second = await dataSource.load('it');
      expect(identical(first, second), isTrue);
    });
  });

  group('Non-IT departments (extracted verbatim from the real inline DEPTS array)', () {
    test('loads exactly the real 2 tracks with their real department and role counts', () async {
      final groups = await dataSource.load('non-it');

      expect(groups, hasLength(2));
      expect(groups[0].label, 'Non-IT · Technical');
      expect(groups[0].departments, hasLength(15));
      expect(groups[1].label, 'Non-IT · Non-Technical');
      expect(groups[1].departments, hasLength(6));

      final totalRoles = [
        for (final g in groups) for (final d in g.departments) ...d.roles,
      ].length;
      expect(totalRoles, 202);
    });

    test('every Non-IT role has exactly one skill group labeled "Role skills"', () async {
      final groups = await dataSource.load('non-it');
      final engineering = groups[0].departments.first;
      final firstRole = engineering.roles.first;

      expect(firstRole.skillGroups, hasLength(1));
      expect(firstRole.skillGroups.single.label, 'Role skills');
      expect(firstRole.skillGroups.single.skills, isNotEmpty);
    });

    test('skills inside parentheses are not split on their internal comma', () async {
      final groups = await dataSource.load('non-it');
      final engineering = groups[0].departments.first;
      final recruiter = engineering.roles.firstWhere(
        (r) => r.name == 'Lead Technical Recruiter (Engineering)',
      );
      final skills = recruiter.skillGroups.single.skills;

      // Source: "... ATS management (Workday/Bullhorn), candidate vetting ..."
      // — the comma inside "(Workday/Bullhorn)" must not split that phrase.
      expect(skills.any((s) => s.contains('Workday/Bullhorn')), isTrue);
    });
  });
}
