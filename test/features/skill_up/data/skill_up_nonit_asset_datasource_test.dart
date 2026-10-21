import 'package:career_buddy_lms/features/skill_up/data/skill_up_nonit_asset_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 47 — curriculum data tests for the real Non-IT Skill Up catalog
/// (`assets/data/nonit_skillup_departments.json`, a byte-for-byte copy of
/// the real `static/data/nonit_departments.json`). Counts/titles below are
/// taken directly from inspecting that source file, not from any older
/// approximation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SkillUpNonItAssetDataSource dataSource;

  setUp(() {
    dataSource = SkillUpNonItAssetDataSource();
  });

  test('loads exactly the real 2 tracks with their real department counts', () async {
    final groups = await dataSource.load();

    expect(groups, hasLength(2));
    expect(groups[0].label, 'Non-IT · Technical');
    expect(groups[0].departments, hasLength(15));
    expect(groups[1].label, 'Non-IT · Non-Technical');
    expect(groups[1].departments, hasLength(6));
  });

  test('every department maps to its real category, and the real 202 total roles', () async {
    final groups = await dataSource.load();

    for (final department in groups[0].departments) {
      expect(department.category, 'tech');
    }
    for (final department in groups[1].departments) {
      expect(department.category, 'nt');
    }
    final totalRoles = [
      for (final g in groups) for (final d in g.departments) ...d.roles,
    ].length;
    expect(totalRoles, 202);
  });

  test('every role carries a non-null coursePath (all 202 real roles link to a lesson)', () async {
    final groups = await dataSource.load();
    final allRoles = [
      for (final g in groups) for (final d in g.departments) ...d.roles,
    ];

    expect(allRoles, hasLength(202));
    expect(allRoles.every((r) => r.coursePath != null && r.coursePath!.isNotEmpty), isTrue);
  });

  test('no duplicate role names within the same department', () async {
    final groups = await dataSource.load();

    for (final group in groups) {
      for (final department in group.departments) {
        final names = department.roles.map((r) => r.name).toList();
        expect(names.toSet().length, names.length, reason: 'duplicate role name in ${department.name}');
      }
    }
  });

  test('a known role has its real skills and real lesson coursePath, verified against the source', () async {
    final groups = await dataSource.load();
    final engineering = groups[0].departments.firstWhere(
      (d) => d.name == 'Engineering Recruitment & Technical Staffing',
    );
    final recruiter = engineering.roles.firstWhere(
      (r) => r.name == 'Lead Technical Recruiter (Engineering)',
    );

    expect(recruiter.skillGroups, hasLength(1));
    expect(recruiter.skillGroups.single.label, 'Role skills');
    expect(recruiter.skillGroups.single.skills, contains('Full-cycle technical sourcing'));
    expect(recruiter.skillGroups.single.skills, contains('ATS management (Workday/Bullhorn)'));
    expect(
      recruiter.coursePath,
      'NonITCenter/technical/engineering-recruitment-technical-staffing/01_lead_technical_recruiter_engineering.html',
    );
  });

  test('caches after the first load (same instance returned)', () async {
    final first = await dataSource.load();
    final second = await dataSource.load();
    expect(identical(first, second), isTrue);
  });
}
