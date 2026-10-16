import 'package:career_buddy_lms/features/resume/data/create_resume_preview_parser.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCreateResumePreviewResponse', () {
    test(
      'parses a success response even when errors is non-empty — preview_api never rejects',
      () {
        final outcome = parseCreateResumePreviewResponse({
          'ok': true,
          'document': {
            'template': 'classic',
            'name': 'Asha Rao',
            'title': 'Backend Engineer',
            'contact': [
              {'text': 'asha@example.com', 'href': 'mailto:asha@example.com'},
            ],
            'links': [],
            'address': '',
            'sections': [
              {
                'key': 'summary',
                'heading': 'Professional Summary',
                'kind': 'text',
                'text': 'A short summary.',
              },
            ],
          },
          'errors': [
            {
              'field': 'personal.phone',
              'section': 'personal',
              'message': 'Please enter your contact number.',
            },
          ],
          'filename': 'Asha_Rao_Backend_Engineer_Resume.pdf',
        });

        expect(outcome, isNotNull);
        expect(outcome!.document.name, 'Asha Rao');
        expect(
          outcome.document.sections.single.body,
          isA<CreateResumeTextBody>(),
        );
        expect(outcome.errors.single.field, 'personal.phone');
        expect(outcome.filename, 'Asha_Rao_Backend_Engineer_Resume.pdf');
      },
    );

    test(
      'parses every section kind this app renders (text/lines/entries/items)',
      () {
        final outcome = parseCreateResumePreviewResponse({
          'ok': true,
          'document': {
            'template': 'classic',
            'name': 'Asha Rao',
            'title': '',
            'contact': [],
            'links': [],
            'address': '',
            'sections': [
              {
                'key': 'summary',
                'heading': 'Summary',
                'kind': 'text',
                'text': 'Hello',
              },
              {
                'key': 'skills',
                'heading': 'Skills',
                'kind': 'lines',
                'items': [
                  {'label': 'Technical Skills', 'text': 'Python, SQL'},
                ],
              },
              {
                'key': 'experience',
                'heading': 'Professional Experience',
                'kind': 'entries',
                'items': [
                  {
                    'title': 'Engineer',
                    'subtitle': 'Acme',
                    'meta': 'Full-time | 2020 – Present',
                    'bullets': ['Built things'],
                    'groups': [],
                    'notes': [],
                  },
                ],
              },
              {
                'key': 'certifications',
                'heading': 'Certifications & Training',
                'kind': 'items',
                'items': [
                  {
                    'title': 'AWS Certified',
                    'text': 'Amazon',
                    'detail': '',
                    'link': null,
                  },
                ],
              },
              {
                'key': 'unknown',
                'heading': 'Mystery',
                'kind': 'not-a-real-kind',
              },
            ],
          },
          'errors': [],
          'filename': 'resume.pdf',
        });

        final sections = outcome!.document.sections;
        expect(sections[0].body, isA<CreateResumeTextBody>());
        expect(sections[1].body, isA<CreateResumeLinesBody>());
        expect(sections[2].body, isA<CreateResumeEntriesBody>());
        expect(sections[3].body, isA<CreateResumeItemsBody>());
        // An unrecognized kind degrades to CreateResumeUnknownBody rather than
        // being dropped or crashing the whole parse.
        expect(sections[4].body, isA<CreateResumeUnknownBody>());
      },
    );

    test(
      'returns null for an ok:false response — this endpoint is never expected to reject',
      () {
        final outcome = parseCreateResumePreviewResponse({
          'ok': false,
          'errors': [
            {'field': '', 'section': '', 'message': 'Too many requests.'},
          ],
        });
        expect(outcome, isNull);
      },
    );

    test('returns null for a malformed/unexpected body', () {
      expect(parseCreateResumePreviewResponse(null), isNull);
      expect(parseCreateResumePreviewResponse('not a map'), isNull);
      expect(parseCreateResumePreviewResponse({'ok': true}), isNull);
    });
  });
}
