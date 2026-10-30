import 'package:career_buddy_lms/features/resume/domain/entities/career_department.dart';
import 'package:career_buddy_lms/features/skill_up/domain/entities/tech_center_catalog.dart';
import 'package:career_buddy_lms/features/skill_up/domain/skill_up_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _techDepartments = [
  TechCenterDepartment(
    slug: 'development',
    title: 'Development',
    roles: [
      TechCenterRole(
        slug: 'software-developer',
        title: 'Software Developer',
        category: 'Product and Engineering',
        courses: [
          TechCenterCourse(title: 'Core Languages', relativePath: 'a/b/c.html'),
        ],
      ),
      TechCenterRole(
        slug: 'devops-engineer',
        title: 'DevOps Engineer',
        category: 'Product and Engineering',
        courses: [TechCenterCourse(title: 'CI/CD', relativePath: 'a/b/d.html')],
      ),
    ],
  ),
  TechCenterDepartment(
    slug: 'devops-infrastructure',
    title: 'DevOps / Infrastructure',
    roles: [
      // Phase 76/77 — a real, confirmed role-slug reuse across departments.
      TechCenterRole(
        slug: 'devops-engineer',
        title: 'DevOps Engineer',
        category: 'Product and Engineering',
        courses: [
          TechCenterCourse(title: 'Infra as Code', relativePath: 'a/e/f.html'),
        ],
      ),
    ],
  ),
];

const _nonItGroups = [
  CareerDepartmentGroup(
    label: 'Non-IT · Technical',
    departments: [
      CareerDepartment(
        category: 'tech',
        icon: 'search',
        name: 'Engineering Recruitment & Technical Staffing',
        roles: [
          CareerRole(
            name: 'Lead Technical Recruiter (Engineering)',
            skillGroups: [
              CareerRoleSkillGroup(label: 'Role skills', skills: ['Sourcing']),
            ],
            coursePath: 'NonITCenter/technical/x/01.html',
          ),
        ],
      ),
    ],
  ),
];

void main() {
  group('parseSkillUpDeepLinkId', () {
    test('parses a valid Tech Center department identifier', () {
      expect(
        parseSkillUpDeepLinkId('grp-tech-development'),
        const TechCenterDepartmentId('development'),
      );
    });

    test('parses a valid Tech Center role identifier', () {
      expect(
        parseSkillUpDeepLinkId('role-tech-development--software-developer'),
        const TechCenterRoleId('development', 'software-developer'),
      );
    });

    test('parses a valid Non-IT department identifier', () {
      expect(
        parseSkillUpDeepLinkId(
          'grp-nonit-engineering-recruitment-technical-staffing',
        ),
        const NonItDepartmentId('engineering-recruitment-technical-staffing'),
      );
    });

    test('parses a valid Non-IT role identifier', () {
      expect(
        parseSkillUpDeepLinkId(
          'role-nonit-engineering-recruitment-technical-staffing--lead-technical-recruiter-engineering',
        ),
        const NonItRoleId(
          'engineering-recruitment-technical-staffing',
          'lead-technical-recruiter-engineering',
        ),
      );
    });

    test(
      'returns null for an unknown identifier (a depth-* section id, handled elsewhere)',
      () {
        expect(parseSkillUpDeepLinkId('depth-tech'), isNull);
        expect(parseSkillUpDeepLinkId('depth-english'), isNull);
      },
    );

    test('returns null for an empty or missing query parameter', () {
      expect(parseSkillUpDeepLinkId(null), isNull);
      expect(parseSkillUpDeepLinkId(''), isNull);
    });

    test(
      'returns null for malformed identifiers, matching the real _TECH_ROLE_RE.fullmatch contract',
      () {
        // Wrong casing — the real regex has no re.I flag.
        expect(parseSkillUpDeepLinkId('GRP-TECH-development'), isNull);
        expect(parseSkillUpDeepLinkId('Grp-Tech-Development'), isNull);
        // Wrong catalog/kind keywords.
        expect(parseSkillUpDeepLinkId('grp-web-development'), isNull);
        expect(parseSkillUpDeepLinkId('dept-tech-development'), isNull);
        // A role id missing the "--" department/role separator entirely.
        expect(parseSkillUpDeepLinkId('role-tech-onlyonepart'), isNull);
        // A role id with an empty department or role half.
        expect(
          parseSkillUpDeepLinkId('role-tech---software-developer'),
          isNull,
        );
        expect(parseSkillUpDeepLinkId('role-tech-development--'), isNull);
        // Disallowed characters (spaces, underscores, uppercase).
        expect(parseSkillUpDeepLinkId('grp-tech-dev elopment'), isNull);
        expect(parseSkillUpDeepLinkId('grp-tech-dev_elopment'), isNull);
      },
    );

    test(
      'a reused Tech Center role slug parses the same way regardless of which department it belongs to — '
      'the department half of the id is what actually disambiguates it, not the parser',
      () {
        expect(
          parseSkillUpDeepLinkId('role-tech-development--devops-engineer'),
          const TechCenterRoleId('development', 'devops-engineer'),
        );
        expect(
          parseSkillUpDeepLinkId(
            'role-tech-devops-infrastructure--devops-engineer',
          ),
          const TechCenterRoleId('devops-infrastructure', 'devops-engineer'),
        );
      },
    );
  });

  group('findTechCenterDepartment / findTechCenterRole', () {
    test('resolves a known department', () {
      final department = findTechCenterDepartment(
        _techDepartments,
        'development',
      );
      expect(department?.title, 'Development');
    });

    test('returns null for an unknown department slug', () {
      expect(findTechCenterDepartment(_techDepartments, 'nonexistent'), isNull);
    });

    test(
      'resolves a role scoped to its own department, not the same-named role in a different one',
      () {
        final inDevelopment = findTechCenterRole(
          _techDepartments,
          'development',
          'devops-engineer',
        );
        final inInfrastructure = findTechCenterRole(
          _techDepartments,
          'devops-infrastructure',
          'devops-engineer',
        );

        expect(inDevelopment?.department.slug, 'development');
        expect(inDevelopment?.role.courses.single.title, 'CI/CD');
        expect(inInfrastructure?.department.slug, 'devops-infrastructure');
        expect(inInfrastructure?.role.courses.single.title, 'Infra as Code');
      },
    );

    test(
      'returns null for a role slug that exists, but not under the claimed department',
      () {
        // "software-developer" is only a role under "development", not "devops-infrastructure".
        expect(
          findTechCenterRole(
            _techDepartments,
            'devops-infrastructure',
            'software-developer',
          ),
          isNull,
        );
      },
    );

    test('returns null when the department itself does not exist', () {
      expect(
        findTechCenterRole(
          _techDepartments,
          'nonexistent',
          'software-developer',
        ),
        isNull,
      );
    });
  });

  group('slugifyNonItName', () {
    test(
      'matches the real site\'s own JS slugify function exactly for real department/role names',
      () {
        expect(
          slugifyNonItName('Engineering Recruitment & Technical Staffing'),
          'engineering-recruitment-technical-staffing',
        );
        expect(
          slugifyNonItName('Lead Technical Recruiter (Engineering)'),
          'lead-technical-recruiter-engineering',
        );
      },
    );
  });

  group('findNonItDepartment / findNonItRole', () {
    test('resolves a known Non-IT department by its derived slug', () {
      final department = findNonItDepartment(
        _nonItGroups,
        'engineering-recruitment-technical-staffing',
      );
      expect(department?.name, 'Engineering Recruitment & Technical Staffing');
    });

    test('returns null for an unknown Non-IT department slug', () {
      expect(findNonItDepartment(_nonItGroups, 'nonexistent'), isNull);
    });

    test('resolves a Non-IT role scoped to its own department', () {
      final found = findNonItRole(
        _nonItGroups,
        'engineering-recruitment-technical-staffing',
        'lead-technical-recruiter-engineering',
      );
      expect(
        found?.department.name,
        'Engineering Recruitment & Technical Staffing',
      );
      expect(found?.role.name, 'Lead Technical Recruiter (Engineering)');
    });

    test(
      'returns null when the Non-IT role slug does not exist under the claimed department',
      () {
        expect(
          findNonItRole(
            _nonItGroups,
            'engineering-recruitment-technical-staffing',
            'nonexistent-role',
          ),
          isNull,
        );
      },
    );
  });
}
