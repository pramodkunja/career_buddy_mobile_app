import 'package:career_buddy_lms/features/resume/data/manual_resume_preview_parser.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_document.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_preview_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

final _successBody = {
  'ok': true,
  'document': {
    'name': 'Anita Sharma',
    'title': 'QA Engineer',
    'contact': [
      {'text': '9876543210', 'href': 'tel:9876543210'},
      {'text': 'anita@example.com', 'href': 'mailto:anita@example.com'},
    ],
    'level': '1-3',
    'level_label': '1–3 Years',
    'role': 'QA Engineer',
    'sections': [
      {'key': 'summary', 'heading': 'Professional Summary', 'kind': 'text', 'text': 'Line one\nLine two'},
      {
        'key': 'experience',
        'heading': 'Work Experience',
        'kind': 'jobs',
        'items': [
          {
            'title': 'Engineer',
            'subtitle': 'Acme',
            'location': 'Remote',
            'dates': 'Jan 2022 – Present',
            'duration': '2 years',
            'bullets': ['Shipped features'],
          },
        ],
      },
      {
        'key': 'skills',
        'heading': 'Key Skills',
        'kind': 'skills',
        'groups': [
          {
            'label': 'Languages',
            'items': ['Python', 'Dart'],
          },
        ],
      },
      {
        'key': 'projects',
        'heading': 'Projects',
        'kind': 'projects',
        'items': [
          {'title': 'App', 'subtitle': 'Personal', 'dates': '2024', 'bullets': ['Built it'], 'tech': 'Flutter'},
        ],
      },
      {
        'key': 'achievements',
        'heading': 'Achievements',
        'kind': 'bullets',
        'items': ['Won an award'],
      },
      {
        'key': 'credentials',
        'heading': 'Certifications',
        'kind': 'compact',
        'items': [
          {'title': 'AWS', 'subtitle': 'Amazon', 'dates': '2023'},
        ],
      },
      {
        'key': 'education',
        'heading': 'Education',
        'kind': 'education',
        'items': [
          {'title': 'B.Tech', 'meta': 'ABC | HYD | 2022 | 8.5'},
        ],
      },
      {
        'key': 'declaration',
        'heading': 'Declaration',
        'kind': 'declaration',
        'text': 'I hereby declare...',
        'place': 'Hyderabad',
        'date': '01/01/2026',
        'name': 'Anita Sharma',
      },
    ],
  },
  'warnings': ['Add a short professional summary'],
  'completeness': {
    'overall': 72,
    'categories': [
      {'key': 'personal', 'label': 'Personal Information', 'value': 100, 'optional': false, 'step': 1},
    ],
  },
  'filename': 'Anita_Sharma_QA_Engineer_Resume.pdf',
};

void main() {
  group('a successful response', () {
    test('parses the full document, warnings, completeness, and filename', () {
      final outcome = parseManualResumePreviewResponse(_successBody);

      expect(outcome, isA<ManualResumePreviewReady>());
      final ready = outcome as ManualResumePreviewReady;
      expect(ready.document.name, 'Anita Sharma');
      expect(ready.document.title, 'QA Engineer');
      expect(ready.document.contact, hasLength(2));
      expect(ready.document.contact.first.href, 'tel:9876543210');
      expect(ready.document.sections, hasLength(8));
      expect(ready.warnings, ['Add a short professional summary']);
      expect(ready.completeness.overall, 72);
      expect(ready.filename, 'Anita_Sharma_QA_Engineer_Resume.pdf');
    });

    test('parses each section kind into its correctly-typed body', () {
      final ready = parseManualResumePreviewResponse(_successBody) as ManualResumePreviewReady;
      final sections = {for (final s in ready.document.sections) s.key: s};

      expect(sections['summary']!.body, isA<ManualResumeTextBody>());
      expect((sections['summary']!.body as ManualResumeTextBody).text, 'Line one\nLine two');

      expect(sections['experience']!.body, isA<ManualResumeJobsBody>());
      final jobs = (sections['experience']!.body as ManualResumeJobsBody).items;
      expect(jobs.single.title, 'Engineer');
      expect(jobs.single.bullets, ['Shipped features']);

      expect(sections['skills']!.body, isA<ManualResumeSkillsBody>());
      expect((sections['skills']!.body as ManualResumeSkillsBody).groups.single.label, 'Languages');

      expect(sections['projects']!.body, isA<ManualResumeProjectsBody>());
      expect((sections['projects']!.body as ManualResumeProjectsBody).items.single.tech, 'Flutter');

      expect(sections['achievements']!.body, isA<ManualResumeBulletsBody>());
      expect(sections['credentials']!.body, isA<ManualResumeCompactBody>());
      expect(sections['education']!.body, isA<ManualResumeEducationBody>());

      expect(sections['declaration']!.body, isA<ManualResumeDeclarationSectionBody>());
      final decl = (sections['declaration']!.body as ManualResumeDeclarationSectionBody).declaration;
      expect(decl.place, 'Hyderabad');
      expect(decl.name, 'Anita Sharma');
    });

    test('an unrecognised section kind degrades to ManualResumeUnknownBody, not a crash', () {
      final body = <String, dynamic>{
        'ok': true,
        'document': <String, dynamic>{
          'name': 'Anita Sharma',
          'title': '',
          'contact': <dynamic>[],
          'level': '',
          'level_label': '',
          'role': '',
          'sections': <dynamic>[
            {'key': 'mystery', 'heading': 'Mystery', 'kind': 'something-new'},
          ],
        },
        'warnings': <dynamic>[],
        'completeness': <String, dynamic>{'overall': 0, 'categories': <dynamic>[]},
        'filename': '',
      };
      final ready = parseManualResumePreviewResponse(body) as ManualResumePreviewReady;
      expect(ready.document.sections.single.body, isA<ManualResumeUnknownBody>());
    });
  });

  group('a validation-rejection response', () {
    test('parses field/step/message errors and the accompanying completeness', () {
      final body = {
        'ok': false,
        'errors': [
          {'field': 'personal.name', 'step': 1, 'message': 'Please enter your full name.'},
          {'field': 'role', 'step': 2, 'message': 'Please select a job role.'},
        ],
        'completeness': {'overall': 20, 'categories': []},
      };

      final outcome = parseManualResumePreviewResponse(body);

      expect(outcome, isA<ManualResumePreviewRejected>());
      final rejected = outcome as ManualResumePreviewRejected;
      expect(rejected.errors, hasLength(2));
      expect(rejected.errors.first.field, 'personal.name');
      expect(rejected.errors.first.step, 1);
      expect(rejected.completeness?.overall, 20);
    });

    test('a rate-limit/unreadable-payload response (no completeness key) parses fine', () {
      final body = {
        'ok': false,
        'errors': [
          {'field': '', 'step': 0, 'message': 'Too many requests. Please wait a few minutes and try again.'},
        ],
      };

      final outcome = parseManualResumePreviewResponse(body) as ManualResumePreviewRejected;

      expect(outcome.errors.single.field, '');
      expect(outcome.errors.single.step, 0);
      expect(outcome.completeness, isNull);
    });
  });

  group('malformed / unexpected responses', () {
    test('a non-map body is unparseable', () {
      expect(parseManualResumePreviewResponse('not a map'), isNull);
      expect(parseManualResumePreviewResponse(null), isNull);
      expect(parseManualResumePreviewResponse([1, 2, 3]), isNull);
    });

    test('a missing/non-bool "ok" key is unparseable', () {
      expect(parseManualResumePreviewResponse({'document': {}}), isNull);
      expect(parseManualResumePreviewResponse({'ok': 'yes'}), isNull);
    });

    test('ok:true with a missing/malformed document is unparseable, never a fabricated success', () {
      expect(parseManualResumePreviewResponse({'ok': true}), isNull);
      expect(parseManualResumePreviewResponse({'ok': true, 'document': 'not a map'}), isNull);
    });

    test('ok:false with an empty/missing errors list is unparseable', () {
      expect(parseManualResumePreviewResponse({'ok': false}), isNull);
      expect(parseManualResumePreviewResponse({'ok': false, 'errors': []}), isNull);
    });

    test('an empty document (zero sections) still parses, not treated as malformed', () {
      final body = {
        'ok': true,
        'document': {
          'name': 'Anita Sharma',
          'title': '',
          'contact': [],
          'level': '',
          'level_label': '',
          'role': '',
          'sections': [],
        },
        'warnings': [],
        'completeness': {'overall': 0, 'categories': []},
        'filename': '',
      };

      final outcome = parseManualResumePreviewResponse(body) as ManualResumePreviewReady;

      expect(outcome.document.sections, isEmpty);
      expect(outcome.warnings, isEmpty);
    });
  });
}
