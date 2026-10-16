import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManualResumeDraft.blank', () {
    test('every field defaults to an empty-but-present value, never null', () {
      final draft = ManualResumeDraft.blank();
      expect(draft.toJson(), {
        'role': '',
        'roleDef': <String, dynamic>{},
        'level': '',
        'personal': {
          'name': '',
          'email': '',
          'phone': '',
          'location': '',
          'linkedin': '',
          'website': '',
          'dob': '',
          'passport': '',
        },
        'targetTitle': '',
        'domain': '',
        'years': '',
        'skills': {'groups': <String, dynamic>{}, 'suggested': <String>[], 'soft': <String>[], 'other': <String>[]},
        'employment': <Map<String, dynamic>>[],
        'internships': <Map<String, dynamic>>[],
        'projects': <Map<String, dynamic>>[],
        'education': <Map<String, dynamic>>[],
        'certifications': <Map<String, dynamic>>[],
        'training': <Map<String, dynamic>>[],
        'achievements': '',
        'languages': '',
        'additional': '',
        'summary': '',
        'declaration': false,
        'place': '',
        'declDate': '',
        'currentStep': 1,
      });
    });
  });

  group('round-trip', () {
    test('fromJson(toJson()) reproduces every field, including nested lists', () {
      final original = ManualResumeDraft.blank().copyWith(
        role: 'software-engineer',
        level: '1-3',
        personal: const ManualResumePersonalInfo(name: 'A Candidate', email: 'a@example.com'),
        skills: const ManualResumeSkills(groups: {'languages': ['Dart', 'Python']}, soft: ['Teamwork']),
        employment: const [
          ManualResumeJobEntry(title: 'Engineer', company: 'Acme', current: true, bullets: 'Shipped things'),
        ],
        internships: const [ManualResumeJobEntry(title: 'Intern', company: 'Acme Labs')],
        projects: const [ManualResumeProjectEntry(name: 'App', tools: 'Flutter')],
        education: const [ManualResumeEducationEntry(degree: 'B.Tech', institution: 'ABC', year: '2022')],
        certifications: const [ManualResumeCertificationEntry(name: 'AWS', issuer: 'Amazon', year: '2023')],
        training: const [ManualResumeTrainingEntry(name: 'Leadership', provider: 'Internal', year: '2024')],
        declaration: true,
        currentStep: 3,
      );

      final restored = ManualResumeDraft.fromJson(original.toJson());

      expect(restored.toJson(), original.toJson());
    });

    test('certifications use "issuer" and training uses "provider" — never confused with each other', () {
      final draft = ManualResumeDraft.blank().copyWith(
        certifications: const [ManualResumeCertificationEntry(name: 'X', issuer: 'Issuer Co', year: '2024')],
        training: const [ManualResumeTrainingEntry(name: 'Y', provider: 'Provider Co', year: '2024')],
      );
      expect(draft.toJson()['certifications'], [
        {'name': 'X', 'issuer': 'Issuer Co', 'year': '2024'},
      ]);
      expect(draft.toJson()['training'], [
        {'name': 'Y', 'provider': 'Provider Co', 'year': '2024'},
      ]);
    });
  });

  group('defensive fromJson', () {
    test('an empty map produces the same thing as .blank()', () {
      expect(ManualResumeDraft.fromJson({}).toJson(), ManualResumeDraft.blank().toJson());
    });

    test('wrong-typed fields fall back to their safe defaults instead of throwing', () {
      final draft = ManualResumeDraft.fromJson({
        'role': 42,
        'personal': 'not a map',
        'employment': 'not a list',
        'declaration': 'not a bool',
        'currentStep': 'not an int',
      });
      expect(draft.role, '');
      expect(draft.personal.name, '');
      expect(draft.employment, isEmpty);
      expect(draft.declaration, false);
      expect(draft.currentStep, kManualResumeFirstStep);
    });

    test('a non-map entry inside a repeatable list is skipped, not thrown', () {
      final draft = ManualResumeDraft.fromJson({
        'employment': [
          {'title': 'Real Entry', 'company': 'Acme'},
          'not a map',
          42,
        ],
      });
      expect(draft.employment, hasLength(1));
      expect(draft.employment.single.title, 'Real Entry');
    });
  });

  group('currentStep bounds', () {
    test('fromJson clamps an out-of-range step into 1..5', () {
      expect(ManualResumeDraft.fromJson({'currentStep': 0}).currentStep, kManualResumeFirstStep);
      expect(ManualResumeDraft.fromJson({'currentStep': 99}).currentStep, kManualResumeLastStep);
    });

    test('copyWith clamps an out-of-range step into 1..5', () {
      final draft = ManualResumeDraft.blank();
      expect(draft.copyWith(currentStep: 0).currentStep, kManualResumeFirstStep);
      expect(draft.copyWith(currentStep: 99).currentStep, kManualResumeLastStep);
      expect(draft.copyWith(currentStep: 3).currentStep, 3);
    });
  });

  group('schema version', () {
    test('kManualResumeDraftSchemaVersion is 1', () {
      expect(kManualResumeDraftSchemaVersion, 1);
    });
  });
}
