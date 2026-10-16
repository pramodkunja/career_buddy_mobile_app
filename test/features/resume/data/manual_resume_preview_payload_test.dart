import 'package:career_buddy_lms/features/resume/data/manual_resume_preview_payload.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toManualResumePreviewPayload', () {
    test('uses snake_case keys matching normalize_state(), not toJson()\'s camelCase local schema', () {
      final draft = ManualResumeDraft.blank().copyWith(
        role: 'software-developer',
        level: '1-3',
        targetTitle: 'Senior Developer',
        domain: 'Fintech',
        declDate: '2026-01-01',
      );

      final payload = toManualResumePreviewPayload(draft);

      expect(payload.containsKey('target_title'), isTrue);
      expect(payload.containsKey('targetTitle'), isFalse);
      expect(payload['target_title'], 'Senior Developer');
      expect(payload.containsKey('decl_date'), isTrue);
      expect(payload.containsKey('declDate'), isFalse);
      expect(payload['decl_date'], '2026-01-01');
      expect(payload.containsKey('role_def'), isTrue);
      expect(payload.containsKey('roleDef'), isFalse);
    });

    test('never includes currentStep — the server has no such concept', () {
      final draft = ManualResumeDraft.blank().copyWith(currentStep: 4);
      final payload = toManualResumePreviewPayload(draft);
      expect(payload.containsKey('currentStep'), isFalse);
      expect(payload.containsKey('current_step'), isFalse);
    });

    test('maps personal info fields exactly', () {
      final draft = ManualResumeDraft.blank().copyWith(
        personal: const ManualResumePersonalInfo(
          name: 'Anita Sharma',
          email: 'anita@example.com',
          phone: '9876543210',
          location: 'Hyderabad',
          linkedin: 'linkedin.com/in/anita',
          website: 'anita.dev',
          dob: '1995-01-01',
          passport: 'A1234567',
        ),
      );

      final payload = toManualResumePreviewPayload(draft);

      expect(payload['personal'], {
        'name': 'Anita Sharma',
        'email': 'anita@example.com',
        'phone': '9876543210',
        'location': 'Hyderabad',
        'linkedin': 'linkedin.com/in/anita',
        'website': 'anita.dev',
        'dob': '1995-01-01',
        'passport': 'A1234567',
      });
    });

    test('maps skills groups/suggested/soft/other exactly', () {
      final draft = ManualResumeDraft.blank().copyWith(
        skills: const ManualResumeSkills(
          groups: {
            'languages': ['Python', 'Dart'],
          },
          suggested: ['Leadership'],
          soft: ['Communication'],
          other: ['Jira'],
        ),
      );

      final payload = toManualResumePreviewPayload(draft);

      expect(payload['skills'], {
        'groups': {
          'languages': ['Python', 'Dart'],
        },
        'suggested': ['Leadership'],
        'soft': ['Communication'],
        'other': ['Jira'],
      });
    });

    test('maps employment entries including the current flag', () {
      final draft = ManualResumeDraft.blank().copyWith(
        employment: const [
          ManualResumeJobEntry(
            title: 'Engineer',
            company: 'Acme',
            location: 'Remote',
            start: '2022-01',
            end: '2023-06',
            current: true,
            bullets: 'Shipped features',
          ),
        ],
      );

      final payload = toManualResumePreviewPayload(draft);

      expect(payload['employment'], [
        {
          'title': 'Engineer',
          'company': 'Acme',
          'location': 'Remote',
          'start': '2022-01',
          'end': '2023-06',
          'current': true,
          'bullets': 'Shipped features',
        },
      ]);
    });

    test('maps projects (no current flag — the server never defines one for projects)', () {
      final draft = ManualResumeDraft.blank().copyWith(
        projects: const [
          ManualResumeProjectEntry(name: 'Portfolio', context: 'Personal', tools: 'Flutter', start: '2024-01', end: '2024-03', bullets: 'Built it'),
        ],
      );

      final payload = toManualResumePreviewPayload(draft);

      expect(payload['projects'], [
        {
          'name': 'Portfolio',
          'context': 'Personal',
          'tools': 'Flutter',
          'start': '2024-01',
          'end': '2024-03',
          'bullets': 'Built it',
        },
      ]);
      expect((payload['projects'] as List).single, isNot(contains('current')));
    });

    test('maps education/certifications/training exactly', () {
      final draft = ManualResumeDraft.blank().copyWith(
        education: const [ManualResumeEducationEntry(degree: 'B.Tech', institution: 'ABC', location: 'HYD', year: '2022', score: '8.5')],
        certifications: const [ManualResumeCertificationEntry(name: 'AWS', issuer: 'Amazon', year: '2023')],
        training: const [ManualResumeTrainingEntry(name: 'Leadership', provider: 'Internal', year: '2024')],
      );

      final payload = toManualResumePreviewPayload(draft);

      expect(payload['education'], [
        {'degree': 'B.Tech', 'institution': 'ABC', 'location': 'HYD', 'year': '2022', 'score': '8.5'},
      ]);
      expect(payload['certifications'], [
        {'name': 'AWS', 'issuer': 'Amazon', 'year': '2023'},
      ]);
      expect(payload['training'], [
        {'name': 'Leadership', 'provider': 'Internal', 'year': '2024'},
      ]);
    });

    test('maps the remaining top-level text/bool fields exactly', () {
      final draft = ManualResumeDraft.blank().copyWith(
        achievements: 'Won award',
        languages: 'English, Hindi',
        additional: 'Volunteer work',
        summary: 'A dependable engineer',
        declaration: true,
        place: 'Hyderabad',
      );

      final payload = toManualResumePreviewPayload(draft);

      expect(payload['achievements'], 'Won award');
      expect(payload['languages'], 'English, Hindi');
      expect(payload['additional'], 'Volunteer work');
      expect(payload['summary'], 'A dependable engineer');
      expect(payload['declaration'], true);
      expect(payload['place'], 'Hyderabad');
    });

    test('a blank draft maps to a complete payload with every key present and empty', () {
      final payload = toManualResumePreviewPayload(ManualResumeDraft.blank());

      expect(payload.keys.toSet(), {
        'role', 'role_def', 'level', 'personal', 'target_title', 'domain', 'years', 'skills',
        'employment', 'internships', 'projects', 'education', 'certifications', 'training',
        'achievements', 'languages', 'additional', 'summary', 'declaration', 'place', 'decl_date',
      });
      expect(payload['role'], '');
      expect(payload['employment'], isEmpty);
      expect(payload['declaration'], false);
    });
  });
}
