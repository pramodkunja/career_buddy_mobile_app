import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreateResumeFormState', () {
    test(
      'toRequestJson() sends the not-yet-editable sections as empty, never omitted',
      () {
        const state = CreateResumeFormState();
        final json = state.toRequestJson();

        expect(json['projects'], isEmpty);
        expect(json['certifications'], isEmpty);
        expect(json['achievements'], isEmpty);
        expect(json['internships'], isEmpty);
        expect(json['volunteering'], isEmpty);
        expect(json['languages'], isEmpty);
        expect(json['additional'], isEmpty);
        expect(json['template'], 'classic');
      },
    );

    test(
      'toRequestJson() uses snake_case field names matching normalize()\'s own raw.get(...) calls',
      () {
        const state = CreateResumeFormState(
          personal: CreateResumePersonalInfo(
            name: 'Asha Rao',
            title: 'Backend Engineer',
          ),
          experience: [
            CreateResumeExperienceEntry(
              company: 'Acme',
              startYear: '2020',
              startMonth: '3',
            ),
          ],
        );
        final json = state.toRequestJson();

        expect(json['personal'], containsPair('name', 'Asha Rao'));
        expect(json['personal'], containsPair('title', 'Backend Engineer'));
        final experience = json['experience'] as List;
        expect(experience.single, containsPair('start_year', '2020'));
        expect(experience.single, containsPair('start_month', '3'));
      },
    );

    test(
      'fromDraftData() round-trips a draft_detail response back into editable form state',
      () {
        const original = CreateResumeFormState(
          template: 'modern',
          personal: CreateResumePersonalInfo(
            name: 'Asha Rao',
            email: 'asha@example.com',
          ),
          summary: 'A short summary of my experience building backend systems.',
          skills: CreateResumeSkills(technical: ['Python', 'SQL']),
          experience: [
            CreateResumeExperienceEntry(
              company: 'Acme',
              title: 'Engineer',
              startYear: '2020',
            ),
          ],
          education: [
            CreateResumeEducationEntry(
              qualification: "Bachelor's Degree",
              institution: 'State University',
            ),
          ],
        );

        final restored = CreateResumeFormState.fromDraftData(
          original.toRequestJson(),
          draftId: 7,
        );

        expect(restored.draftId, 7);
        expect(restored.template, 'modern');
        expect(restored.personal.name, 'Asha Rao');
        expect(restored.personal.email, 'asha@example.com');
        expect(restored.summary, original.summary);
        expect(restored.skills.technical, ['Python', 'SQL']);
        expect(restored.experience.single.company, 'Acme');
        expect(restored.education.single.institution, 'State University');
      },
    );

    test(
      'fromDraftData() falls back to "classic" for an unrecognized or missing template, never invents one',
      () {
        final restored = CreateResumeFormState.fromDraftData({
          'template': 'not-a-real-template',
        });
        expect(restored.template, 'classic');

        final restoredMissing = CreateResumeFormState.fromDraftData({});
        expect(restoredMissing.template, 'classic');
      },
    );
  });

  group('CreateResumeExperienceEntry.isBlank', () {
    test('is true for a freshly-added entry', () {
      expect(const CreateResumeExperienceEntry().isBlank, isTrue);
    });

    test('is false once any real field is entered', () {
      expect(
        const CreateResumeExperienceEntry(company: 'Acme').isBlank,
        isFalse,
      );
    });

    test(
      'is still true when only the current/type flag fields are set — matches the server\'s own '
      '_touched() convention of excluding flag-only fields (current/type/qualification/proficiency) '
      'from the "has real content" check',
      () {
        expect(
          const CreateResumeExperienceEntry(current: true).isBlank,
          isTrue,
        );
        expect(
          const CreateResumeExperienceEntry(type: 'Full-time').isBlank,
          isTrue,
        );
      },
    );
  });

  group('CreateResumeEducationEntry.isBlank', () {
    test('is true for a freshly-added entry', () {
      expect(const CreateResumeEducationEntry().isBlank, isTrue);
    });

    test('is false once any real field is entered', () {
      expect(
        const CreateResumeEducationEntry(
          institution: 'State University',
        ).isBlank,
        isFalse,
      );
    });
  });
}
