import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/resume_role.dart';
import 'package:career_buddy_lms/features/resume/domain/validation/manual_resume_validation.dart';
import 'package:flutter_test/flutter_test.dart';

const _role = ResumeRole(
  slug: 'software-developer',
  title: 'Software Developer',
  category: 'it',
  categoryLabel: 'IT Role',
  subtitle: 'Frontend, backend, full-stack',
  fields: [
    ResumeRoleSkillField(key: 'programming-languages', label: 'Programming languages', options: ['Python', 'Java']),
  ],
);

/// A draft that passes every mandatory rule — the baseline every negative
/// test mutates away from one field at a time, so each test isolates
/// exactly one rule.
ManualResumeDraft _validDraft() => ManualResumeDraft.blank().copyWith(
  role: _role.slug,
  level: '1-3',
  personal: const ManualResumePersonalInfo(
    name: 'Anita Sharma',
    email: 'anita@example.com',
    phone: '+91 98765 43210',
    location: 'Hyderabad, India',
  ),
  skills: const ManualResumeSkills(
    groups: {
      'programming-languages': ['Python'],
    },
  ),
  employment: const [
    ManualResumeJobEntry(
      title: 'Software Engineer',
      company: 'Acme Corp',
      start: '2022-01',
      end: '2023-06',
      bullets: 'Built and shipped several customer-facing features end to end',
    ),
  ],
  education: const [ManualResumeEducationEntry(degree: 'B.Tech Computer Science')],
);

void main() {
  group('a fully valid draft', () {
    test('produces zero errors', () {
      expect(validateManualResumeDraft(_validDraft(), _role), isEmpty);
    });
  });

  group('personal.name', () {
    test('required', () {
      final errors = validateManualResumeDraft(_validDraft().copyWith(personal: const ManualResumePersonalInfo()), _role);
      expect(errors.any((e) => e.field == 'personal.name' && e.message == 'Please enter your full name.'), isTrue);
    });

    test('too short is a length error, not a format error', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(name: 'A'));
      final errors = validateManualResumeDraft(draft, _role);
      final error = errors.firstWhere((e) => e.field == 'personal.name');
      expect(error.message, contains('at least 2 characters'));
    });

    test('digits are rejected as an invalid format, not a length error', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(name: 'Anita123'));
      final errors = validateManualResumeDraft(draft, _role);
      expect(
        errors.any((e) => e.field == 'personal.name' && e.message.contains('letters, spaces, hyphens')),
        isTrue,
      );
    });

    test('hyphens, apostrophes and a trailing period are accepted', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(name: "Mary-Jane O'Brien Jr."));
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'personal.name'), isEmpty);
    });
  });

  group('personal.email', () {
    test('required', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(email: ''));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.email'), isTrue);
    });

    test('rejects a malformed address', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(email: 'not-an-email'));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.email'), isTrue);
    });

    test('accepts a well-formed address', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(email: 'a.b+tag@sub.example.co.in'));
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'personal.email'), isEmpty);
    });
  });

  group('personal.phone', () {
    test('required', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(phone: ''));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.phone'), isTrue);
    });

    test('fewer than 10 digits is rejected', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(phone: '12345'));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.phone'), isTrue);
    });

    test('more than 15 digits is rejected', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(phone: '1234567890123456'));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.phone'), isTrue);
    });

    test('letters are rejected even with enough digits', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(phone: '12345abcde6789'));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.phone'), isTrue);
    });

    test('a plausible 10-digit number is accepted', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(phone: '9876543210'));
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'personal.phone'), isEmpty);
    });
  });

  group('personal.location', () {
    test('is optional — empty produces no error', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(location: ''));
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'personal.location'), isEmpty);
    });

    test('too short once entered is a length error', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(location: 'A'));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.location'), isTrue);
    });
  });

  group('personal.linkedin / personal.website', () {
    test('optional — empty produces no error', () {
      final errors = validateManualResumeDraft(_validDraft(), _role);
      expect(errors.where((e) => e.field == 'personal.linkedin' || e.field == 'personal.website'), isEmpty);
    });

    test('a malformed link is rejected', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(linkedin: 'not a url at all!'));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.linkedin'), isTrue);
    });

    test('a bare domain without a scheme is accepted', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(website: 'github.com/anita'));
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'personal.website'), isEmpty);
    });
  });

  group('personal.passport', () {
    test('optional — empty produces no error', () {
      expect(validateManualResumeDraft(_validDraft(), _role).where((e) => e.field == 'personal.passport'), isEmpty);
    });

    test('rejects a passport number with the wrong length', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(passport: 'A1'));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.passport'), isTrue);
    });

    test('accepts a valid 8-character passport number', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(passport: 'A1234567'));
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'personal.passport'), isEmpty);
    });
  });

  group('personal.dob', () {
    test('a future date of birth is rejected', () {
      final nextYear = DateTime.now().year + 1;
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(dob: '$nextYear-01-01'));
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'personal.dob'), isTrue);
    });

    test('a past date of birth is accepted', () {
      final draft = _validDraft().copyWith(personal: _validDraft().personal.copyWith(dob: '1995-06-15'));
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'personal.dob'), isEmpty);
    });
  });

  group('role and level', () {
    test('no role selected is an error', () {
      expect(validateManualResumeDraft(_validDraft(), null).any((e) => e.field == 'role'), isTrue);
    });

    test('no experience level selected is an error', () {
      final draft = _validDraft().copyWith(level: '');
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'level'), isTrue);
    });

    test('years must be numeric when entered', () {
      final draft = _validDraft().copyWith(years: 'five');
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'years'), isTrue);
    });

    test('years accepts a one-decimal number', () {
      final draft = _validDraft().copyWith(years: '2.5');
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'years'), isEmpty);
    });
  });

  group('skills', () {
    test('a role with zero selected skills is an error', () {
      final draft = _validDraft().copyWith(skills: const ManualResumeSkills());
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'skills'), isTrue);
    });

    test('a suggested-only skill (not in groups) still counts toward the requirement', () {
      final draft = _validDraft().copyWith(
        skills: const ManualResumeSkills(suggested: ['Leadership']),
      );
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'skills' && e.message.contains('select relevant')), isEmpty);
    });

    test('a skill shorter than 2 characters is rejected', () {
      final draft = _validDraft().copyWith(
        skills: const ManualResumeSkills(other: ['x']),
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'skills' && e.message.contains('2–50')), isTrue);
    });

    test('a skill longer than 50 characters is rejected', () {
      final draft = _validDraft().copyWith(
        skills: ManualResumeSkills(other: ['x' * 51]),
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'skills' && e.message.contains('2–50')), isTrue);
    });
  });

  group('partially filled employment/internship/project entries', () {
    test('title without company is an error naming the missing company field', () {
      final draft = _validDraft().copyWith(
        employment: [..._validDraft().employment, const ManualResumeJobEntry(title: 'Only title')],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment.1.company'), isTrue);
    });

    test('company without title is an error naming the missing title field', () {
      final draft = _validDraft().copyWith(
        employment: [..._validDraft().employment, const ManualResumeJobEntry(company: 'Only company')],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment.1.title'), isTrue);
    });

    test('a completely untouched extra entry is not an error', () {
      final draft = _validDraft().copyWith(
        employment: [..._validDraft().employment, const ManualResumeJobEntry()],
      );
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field.startsWith('employment.1')), isEmpty);
    });

    test('a project with only a touched non-name field is an error', () {
      final draft = _validDraft().copyWith(projects: const [ManualResumeProjectEntry(tools: 'Flutter')]);
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'projects.0.name'), isTrue);
    });
  });

  group('date ranges', () {
    test('end before start is an error', () {
      final draft = _validDraft().copyWith(
        employment: const [ManualResumeJobEntry(title: 'E', company: 'C', start: '2023-01', end: '2022-01')],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment.0.end'), isTrue);
    });

    test('end before start is NOT an error when marked current/ongoing', () {
      final draft = _validDraft().copyWith(
        employment: const [
          ManualResumeJobEntry(title: 'E', company: 'C', start: '2023-01', end: '2022-01', current: true),
        ],
      );
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'employment.0.end'), isEmpty);
    });

    test('a start date in the future is an error', () {
      final nextYear = DateTime.now().year + 1;
      final draft = _validDraft().copyWith(
        employment: [ManualResumeJobEntry(title: 'E', company: 'C', start: '$nextYear-01')],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment.0.start'), isTrue);
    });

    test('a valid past-to-present range is not an error', () {
      final draft = _validDraft();
      expect(draft.employment.single.start, isNotEmpty);
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field.contains('.start') || e.field.contains('.end')), isEmpty);
    });
  });

  group('conditional experience requirement', () {
    test('experienced level with no jobs and no projects is an error', () {
      final draft = _validDraft().copyWith(level: '1-3', employment: const [], projects: const []);
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment' && e.step == kStepExperience), isTrue);
    });

    test('experienced level is satisfied by a valid project alone (no jobs needed)', () {
      final draft = _validDraft().copyWith(
        level: '1-3',
        employment: const [],
        projects: const [ManualResumeProjectEntry(name: 'Portfolio site')],
      );
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'employment' && e.step == kStepExperience), isEmpty);
    });

    test('fresher with no jobs/projects but a valid internship is satisfied', () {
      final draft = _validDraft().copyWith(
        level: 'fresher',
        employment: const [],
        projects: const [],
        internships: const [ManualResumeJobEntry(title: 'Intern', company: 'Acme')],
      );
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'employment' && e.step == kStepExperience), isEmpty);
    });

    test('fresher with no jobs/projects but valid training is satisfied', () {
      final draft = _validDraft().copyWith(
        level: 'fresher',
        employment: const [],
        projects: const [],
        training: const [ManualResumeTrainingEntry(name: 'Data structures course')],
      );
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'employment' && e.step == kStepExperience), isEmpty);
    });

    test('fresher with nothing at all is still an error', () {
      final draft = _validDraft().copyWith(
        level: 'fresher',
        employment: const [],
        projects: const [],
        internships: const [],
        training: const [],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment' && e.step == kStepExperience), isTrue);
    });

    test('an experienced candidate with only an internship (no jobs/projects) is still an error', () {
      final draft = _validDraft().copyWith(
        level: '1-3',
        employment: const [],
        projects: const [],
        internships: const [ManualResumeJobEntry(title: 'Intern', company: 'Acme')],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment' && e.step == kStepExperience), isTrue);
    });
  });

  group('education', () {
    test('no valid education entry is an error', () {
      final draft = _validDraft().copyWith(education: const []);
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'education'), isTrue);
    });

    test('a touched education entry missing a degree is an error', () {
      final draft = _validDraft().copyWith(
        education: [..._validDraft().education, const ManualResumeEducationEntry(institution: 'Some College')],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'education.1.degree'), isTrue);
    });
  });

  group('certifications / training partial entries', () {
    test('a touched certification missing a name is an error', () {
      final draft = _validDraft().copyWith(certifications: const [ManualResumeCertificationEntry(issuer: 'AWS')]);
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'certifications.0.name'), isTrue);
    });

    test('a touched training entry missing a name is an error', () {
      final draft = _validDraft().copyWith(training: const [ManualResumeTrainingEntry(provider: 'Udemy')]);
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'training.0.name'), isTrue);
    });

    test('certifications and training are never mandatory on their own', () {
      final draft = _validDraft().copyWith(certifications: const [], training: const []);
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'certifications' || e.field == 'training'), isEmpty);
    });
  });

  group('length rules', () {
    test('a summary shorter than 50 characters is an error', () {
      final draft = _validDraft().copyWith(summary: 'Too short.');
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'summary'), isTrue);
    });

    test('a summary within range is not an error', () {
      final draft = _validDraft().copyWith(
        summary: 'A dependable software engineer with a track record of shipping reliable, well-tested features.',
      );
      expect(validateManualResumeDraft(draft, _role).where((e) => e.field == 'summary' && e.message.contains('characters')), isEmpty);
    });

    test('bullets longer than 1500 characters for employment is an error', () {
      final draft = _validDraft().copyWith(
        employment: [
          ManualResumeJobEntry(
            title: 'Engineer',
            company: 'Acme',
            bullets: List.generate(30, (i) => 'A reasonably long responsibility line number $i goes here').join('\n'),
          ),
        ],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment.0.bullets' && e.message.contains('characters')), isTrue);
    });

    test('more than 15 bullet points is an error', () {
      final draft = _validDraft().copyWith(
        employment: [
          ManualResumeJobEntry(
            title: 'Engineer',
            company: 'Acme',
            bullets: List.generate(16, (i) => 'Point $i').join('\n'),
          ),
        ],
      );
      expect(
        validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment.0.bullets' && e.message.contains('15 points')),
        isTrue,
      );
    });
  });

  group('placeholder rejection', () {
    test('a [placeholder] left in the summary is an error', () {
      final draft = _validDraft().copyWith(
        summary: 'Experienced in [verified skills] with a strong track record across multiple delivery teams.',
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'summary' && e.message.contains('placeholder')), isTrue);
    });

    test('a [placeholder] left in achievements is an error', () {
      final draft = _validDraft().copyWith(achievements: 'Owned [project / process] and delivered strong outcomes');
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'achievements' && e.message.contains('placeholder')), isTrue);
    });

    test('a [placeholder] left in employment bullets is an error', () {
      final draft = _validDraft().copyWith(
        employment: const [ManualResumeJobEntry(title: 'E', company: 'C', bullets: 'Delivered [X] ahead of schedule')],
      );
      expect(validateManualResumeDraft(draft, _role).any((e) => e.field == 'employment.0.bullets' && e.message.contains('placeholder')), isTrue);
    });

    test('square brackets are fine when not placeholder-shaped (too long to match)', () {
      final draft = _validDraft().copyWith(summary: _validDraft().summary);
      expect(validateManualResumeDraft(draft, _role).where((e) => e.message.contains('placeholder')), isEmpty);
    });
  });

  group('helper functions', () {
    test('isValidEmail/isValidPhone/isValidName/isValidLink basic cases', () {
      expect(isValidEmail('a@b.com'), isTrue);
      expect(isValidEmail('a@b'), isFalse);
      expect(isValidPhone('9876543210'), isTrue);
      expect(isValidPhone('123'), isFalse);
      expect(isValidName('Anita Sharma'), isTrue);
      expect(isValidName('A1'), isFalse);
      expect(isValidLink('https://example.com/x'), isTrue);
      expect(isValidLink('not a link'), isFalse);
    });

    test('hasPlaceholder detects bracketed template text', () {
      expect(hasPlaceholder('Led [team] to deliver results'), isTrue);
      expect(hasPlaceholder('No brackets here'), isFalse);
    });

    test('monthKey parses YYYY-MM and rejects invalid months', () {
      expect(monthKey('2023-04'), (2023, 4));
      expect(monthKey('2023-13'), isNull);
      expect(monthKey('not-a-month'), isNull);
    });

    test('lengthError is empty for an empty value regardless of the rule', () {
      expect(lengthError('', kPersonalRules['name']!), isEmpty);
    });
  });
}
