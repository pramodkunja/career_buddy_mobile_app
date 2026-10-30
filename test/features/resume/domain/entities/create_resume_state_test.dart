import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreateResumeFormState', () {
    test(
      'toRequestJson() sends a blank form\'s Phase 70 sections as empty, never omitted',
      () {
        const state = CreateResumeFormState();
        final json = state.toRequestJson();

        expect(json['projects'], isEmpty);
        expect(json['certifications'], isEmpty);
        expect(json['achievements'], isEmpty);
        expect(json['internships'], isEmpty);
        expect(json['volunteering'], isEmpty);
        expect(json['languages'], isEmpty);
        // `additional` is a flat dict, not a repeatable list (see
        // `CreateResumeAdditionalInfo.toJson()`), so a blank form still
        // sends all 6 keys — each an empty string, never an empty map.
        expect(
          json['additional'],
          containsPair('memberships', ''),
        );
        expect(
          (json['additional'] as Map).values,
          everyElement(isEmpty),
        );
        expect(json['template'], 'classic');
      },
    );

    test(
      'toRequestJson() carries real Phase 70 section data through, matching the server\'s own field names',
      () {
        const state = CreateResumeFormState(
          projects: [
            CreateResumeProjectEntry(title: 'Inventory Tracker', type: 'Personal Project'),
          ],
          certifications: [
            CreateResumeCertificationEntry(name: 'AWS SAA', issuer: 'Amazon'),
          ],
          achievements: [CreateResumeAchievementEntry(title: 'Hackathon winner')],
          internships: [
            CreateResumeInternshipEntry(organization: 'Acme', title: 'SWE Intern'),
          ],
          volunteering: [
            CreateResumeVolunteeringEntry(organization: 'Red Cross', role: 'Volunteer'),
          ],
          languages: [CreateResumeLanguageEntry(name: 'Spanish', proficiency: 'Native')],
          additional: CreateResumeAdditionalInfo(hobbies: 'Chess'),
        );
        final json = state.toRequestJson();

        expect((json['projects'] as List).single, containsPair('title', 'Inventory Tracker'));
        expect((json['projects'] as List).single, containsPair('type', 'Personal Project'));
        expect((json['certifications'] as List).single, containsPair('name', 'AWS SAA'));
        expect((json['certifications'] as List).single, containsPair('issuer', 'Amazon'));
        expect((json['achievements'] as List).single, containsPair('title', 'Hackathon winner'));
        expect((json['internships'] as List).single, containsPair('organization', 'Acme'));
        expect((json['internships'] as List).single, containsPair('title', 'SWE Intern'));
        expect((json['volunteering'] as List).single, containsPair('organization', 'Red Cross'));
        expect((json['volunteering'] as List).single, containsPair('role', 'Volunteer'));
        expect((json['languages'] as List).single, containsPair('name', 'Spanish'));
        expect((json['languages'] as List).single, containsPair('proficiency', 'Native'));
        expect(json['additional'], containsPair('hobbies', 'Chess'));
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
      'fromDraftData() round-trips the Phase 70 sections (projects, certifications, '
      'achievements, internships, volunteering, languages, additional)',
      () {
        const original = CreateResumeFormState(
          projects: [CreateResumeProjectEntry(title: 'Portfolio Site', role: 'Solo dev')],
          certifications: [
            CreateResumeCertificationEntry(name: 'PMP', issuer: 'PMI'),
          ],
          achievements: [
            CreateResumeAchievementEntry(title: 'Dean\'s List', organization: 'State University'),
          ],
          internships: [
            CreateResumeInternshipEntry(organization: 'Beta Corp', title: 'Intern'),
          ],
          volunteering: [
            CreateResumeVolunteeringEntry(organization: 'Food Bank', role: 'Sorter'),
          ],
          languages: [CreateResumeLanguageEntry(name: 'French', proficiency: 'Basic')],
          additional: CreateResumeAdditionalInfo(publications: 'A paper on X'),
        );

        final restored = CreateResumeFormState.fromDraftData(original.toRequestJson());

        expect(restored.projects.single.title, 'Portfolio Site');
        expect(restored.projects.single.role, 'Solo dev');
        expect(restored.certifications.single.name, 'PMP');
        expect(restored.certifications.single.issuer, 'PMI');
        expect(restored.achievements.single.title, "Dean's List");
        expect(restored.internships.single.organization, 'Beta Corp');
        expect(restored.volunteering.single.organization, 'Food Bank');
        expect(restored.languages.single.name, 'French');
        expect(restored.languages.single.proficiency, 'Basic');
        expect(restored.additional.publications, 'A paper on X');
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

  group('CreateResumeProjectEntry', () {
    test('isBlank is true for a freshly-added entry', () {
      expect(const CreateResumeProjectEntry().isBlank, isTrue);
    });

    test('isBlank is false once a real field is entered', () {
      expect(const CreateResumeProjectEntry(title: 'Tracker').isBlank, isFalse);
    });

    test('isBlank stays true when only the "current"/"type" flag fields are set', () {
      expect(const CreateResumeProjectEntry(current: true).isBlank, isTrue);
      expect(const CreateResumeProjectEntry(type: 'Academic Project').isBlank, isTrue);
    });

    test('toJson()/fromJson() round-trip every field', () {
      const entry = CreateResumeProjectEntry(
        title: 'Inventory Tracker',
        type: 'Personal Project',
        organization: 'Self',
        startMonth: '3',
        startYear: '2021',
        endMonth: '6',
        endYear: '2021',
        current: false,
        overview: 'Tracks stock levels.',
        role: 'Sole developer',
        url: 'https://example.com',
        responsibilities: 'Built the backend',
        technologies: 'Python, Postgres',
        outcomes: 'Reduced stockouts',
      );
      final restored = CreateResumeProjectEntry.fromJson(entry.toJson());

      expect(restored.title, entry.title);
      expect(restored.type, entry.type);
      expect(restored.organization, entry.organization);
      expect(restored.startMonth, entry.startMonth);
      expect(restored.startYear, entry.startYear);
      expect(restored.endMonth, entry.endMonth);
      expect(restored.endYear, entry.endYear);
      expect(restored.current, entry.current);
      expect(restored.overview, entry.overview);
      expect(restored.role, entry.role);
      expect(restored.url, entry.url);
      expect(restored.responsibilities, entry.responsibilities);
      expect(restored.technologies, entry.technologies);
      expect(restored.outcomes, entry.outcomes);
    });
  });

  group('CreateResumeCertificationEntry', () {
    test('isBlank is true for a freshly-added entry', () {
      expect(const CreateResumeCertificationEntry().isBlank, isTrue);
    });

    test('isBlank is false once a real field is entered', () {
      expect(
        const CreateResumeCertificationEntry(name: 'AWS SAA').isBlank,
        isFalse,
      );
    });

    test('toJson()/fromJson() round-trip every field', () {
      const entry = CreateResumeCertificationEntry(
        name: 'AWS SAA',
        issuer: 'Amazon',
        issueMonth: '1',
        issueYear: '2022',
        expMonth: '1',
        expYear: '2025',
        credentialId: 'ABC123',
        url: 'https://example.com/cert',
        description: 'Solutions architect associate',
      );
      final restored = CreateResumeCertificationEntry.fromJson(entry.toJson());

      expect(restored.name, entry.name);
      expect(restored.issuer, entry.issuer);
      expect(restored.issueMonth, entry.issueMonth);
      expect(restored.issueYear, entry.issueYear);
      expect(restored.expMonth, entry.expMonth);
      expect(restored.expYear, entry.expYear);
      expect(restored.credentialId, entry.credentialId);
      expect(restored.url, entry.url);
      expect(restored.description, entry.description);
    });
  });

  group('CreateResumeAchievementEntry', () {
    test('isBlank is true for a freshly-added entry', () {
      expect(const CreateResumeAchievementEntry().isBlank, isTrue);
    });

    test('isBlank is false once a real field is entered', () {
      expect(
        const CreateResumeAchievementEntry(title: 'Hackathon winner').isBlank,
        isFalse,
      );
    });

    test('toJson()/fromJson() round-trip every field', () {
      const entry = CreateResumeAchievementEntry(
        title: 'Hackathon winner',
        organization: 'Acme',
        month: '5',
        year: '2023',
        url: 'https://example.com/award',
        description: 'Won first place',
      );
      final restored = CreateResumeAchievementEntry.fromJson(entry.toJson());

      expect(restored.title, entry.title);
      expect(restored.organization, entry.organization);
      expect(restored.month, entry.month);
      expect(restored.year, entry.year);
      expect(restored.url, entry.url);
      expect(restored.description, entry.description);
    });
  });

  group('CreateResumeInternshipEntry', () {
    test('isBlank is true for a freshly-added entry', () {
      expect(const CreateResumeInternshipEntry().isBlank, isTrue);
    });

    test('isBlank is false once a real field is entered', () {
      expect(
        const CreateResumeInternshipEntry(organization: 'Acme').isBlank,
        isFalse,
      );
    });

    test('isBlank stays true when only the "current" flag field is set', () {
      expect(const CreateResumeInternshipEntry(current: true).isBlank, isTrue);
    });

    test('toJson()/fromJson() round-trip every field', () {
      const entry = CreateResumeInternshipEntry(
        organization: 'Acme',
        title: 'SWE Intern',
        location: 'Remote',
        startMonth: '6',
        startYear: '2022',
        endMonth: '8',
        endYear: '2022',
        current: false,
        responsibilities: 'Built features',
        projects: 'Internal tool',
        skills: 'Dart, Flutter',
        achievements: 'Shipped on time',
      );
      final restored = CreateResumeInternshipEntry.fromJson(entry.toJson());

      expect(restored.organization, entry.organization);
      expect(restored.title, entry.title);
      expect(restored.location, entry.location);
      expect(restored.startMonth, entry.startMonth);
      expect(restored.startYear, entry.startYear);
      expect(restored.endMonth, entry.endMonth);
      expect(restored.endYear, entry.endYear);
      expect(restored.current, entry.current);
      expect(restored.responsibilities, entry.responsibilities);
      expect(restored.projects, entry.projects);
      expect(restored.skills, entry.skills);
      expect(restored.achievements, entry.achievements);
    });
  });

  group('CreateResumeVolunteeringEntry', () {
    test('isBlank is true for a freshly-added entry', () {
      expect(const CreateResumeVolunteeringEntry().isBlank, isTrue);
    });

    test('isBlank is false once a real field is entered', () {
      expect(
        const CreateResumeVolunteeringEntry(organization: 'Red Cross').isBlank,
        isFalse,
      );
    });

    test('isBlank stays true when only the "current" flag field is set', () {
      expect(const CreateResumeVolunteeringEntry(current: true).isBlank, isTrue);
    });

    test('toJson()/fromJson() round-trip every field', () {
      const entry = CreateResumeVolunteeringEntry(
        organization: 'Red Cross',
        role: 'Volunteer',
        location: 'Local chapter',
        startMonth: '1',
        startYear: '2021',
        endMonth: '12',
        endYear: '2021',
        current: false,
        responsibilities: 'Blood drives',
        contributions: 'Organized 5 events',
        achievements: 'Volunteer of the year',
      );
      final restored = CreateResumeVolunteeringEntry.fromJson(entry.toJson());

      expect(restored.organization, entry.organization);
      expect(restored.role, entry.role);
      expect(restored.location, entry.location);
      expect(restored.startMonth, entry.startMonth);
      expect(restored.startYear, entry.startYear);
      expect(restored.endMonth, entry.endMonth);
      expect(restored.endYear, entry.endYear);
      expect(restored.current, entry.current);
      expect(restored.responsibilities, entry.responsibilities);
      expect(restored.contributions, entry.contributions);
      expect(restored.achievements, entry.achievements);
    });
  });

  group('CreateResumeLanguageEntry', () {
    test('isBlank is true for a freshly-added entry', () {
      expect(const CreateResumeLanguageEntry().isBlank, isTrue);
    });

    test('isBlank requires BOTH name and proficiency to be empty', () {
      expect(const CreateResumeLanguageEntry(name: 'Spanish').isBlank, isFalse);
      expect(
        const CreateResumeLanguageEntry(proficiency: 'Native').isBlank,
        isFalse,
      );
    });

    test('toJson()/fromJson() round-trip every field', () {
      const entry = CreateResumeLanguageEntry(name: 'Spanish', proficiency: 'Native');
      final restored = CreateResumeLanguageEntry.fromJson(entry.toJson());

      expect(restored.name, entry.name);
      expect(restored.proficiency, entry.proficiency);
    });
  });

  group('CreateResumeAdditionalInfo', () {
    test('isBlank is true by default', () {
      expect(const CreateResumeAdditionalInfo().isBlank, isTrue);
    });

    test('isBlank is false once any field is entered', () {
      expect(
        const CreateResumeAdditionalInfo(hobbies: 'Chess').isBlank,
        isFalse,
      );
    });

    test('toJson()/fromJson() round-trip every field', () {
      const info = CreateResumeAdditionalInfo(
        memberships: 'IEEE',
        publications: 'A paper',
        research: 'ML research',
        activities: 'Debate club',
        hobbies: 'Chess',
        other: 'Fluent in sign language',
      );
      final restored = CreateResumeAdditionalInfo.fromJson(info.toJson());

      expect(restored.memberships, info.memberships);
      expect(restored.publications, info.publications);
      expect(restored.research, info.research);
      expect(restored.activities, info.activities);
      expect(restored.hobbies, info.hobbies);
      expect(restored.other, info.other);
    });
  });
}
