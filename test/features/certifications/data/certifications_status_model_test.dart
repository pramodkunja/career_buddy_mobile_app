import 'package:career_buddy_lms/features/certifications/data/models/certifications_status_model.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certification_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors `api_certifications_status`'s exact real JSON shape
/// (`skillup_assessment/views.py:301-327`, `_subject_state_json`/
/// `_certificate_json`) — every field name here was read directly from the
/// Django view/serializer source, not guessed.
const _notAttemptedSubjectJson = {
  'subject': 'dsa',
  'label': 'DSA',
  'category': 'tech',
  'state': 'not_attempted',
  'pass_threshold': 70,
  'result': {'score': null, 'total': null, 'completed': false},
  'certificate': null,
  'prefill_name': 'Jane Doe',
  'name_url': '/skill-up/assessment/dsa/certificate/name/',
};

const _certifiedSubjectJson = {
  'subject': 'python',
  'label': 'Python',
  'category': 'tech',
  'state': 'certified',
  'pass_threshold': 70,
  'result': {'score': 18, 'total': 20, 'completed': true},
  'certificate': {
    'certificate_name': 'Jane Doe',
    'score': 18,
    'total': 20,
    'certificate_number': 'CB-PYTHON-0001',
    'generated_at': '2026-09-20T10:15:00Z',
    'download_url': '/skill-up/assessment/python/certificate/download/',
    'edit_url': '/skill-up/assessment/python/certificate/edit/',
  },
  'prefill_name': 'Jane Doe',
  'name_url': '/skill-up/assessment/python/certificate/name/',
};

const _validStatusJson = {
  'categories': [
    {
      'key': 'tech',
      'label': 'Tech Center',
      'total': 2,
      'attempted': 1,
      'earned': 1,
      'subjects': [_notAttemptedSubjectJson, _certifiedSubjectJson],
    },
  ],
  'total_count': 2,
  'attempted_count': 1,
  'earned_count': 1,
};

void main() {
  group('CertificationsStatusParsing.fromJson', () {
    test('parses a full valid payload, including a not_attempted subject with null result/certificate fields', () {
      final status = CertificationsStatusParsing.fromJson(_validStatusJson);

      expect(status.totalCount, 2);
      expect(status.attemptedCount, 1);
      expect(status.earnedCount, 1);
      expect(status.categories, hasLength(1));

      final category = status.categories.single;
      expect(category.key, 'tech');
      expect(category.label, 'Tech Center');
      expect(category.total, 2);
      expect(category.attempted, 1);
      expect(category.earned, 1);
      expect(category.subjects, hasLength(2));

      final notAttempted = category.subjects[0];
      expect(notAttempted.subject, 'dsa');
      expect(notAttempted.state, CertificationState.notAttempted);
      expect(notAttempted.result.score, isNull);
      expect(notAttempted.result.total, isNull);
      expect(notAttempted.result.completed, isFalse);
      expect(notAttempted.result.percentage, isNull);
      expect(notAttempted.certificate, isNull);
      expect(notAttempted.prefillName, 'Jane Doe');
    });

    test('parses a certified subject with its nested certificate fields', () {
      final status = CertificationsStatusParsing.fromJson(_validStatusJson);
      final certified = status.categories.single.subjects[1];

      expect(certified.state, CertificationState.certified);
      expect(certified.result.score, 18);
      expect(certified.result.total, 20);
      expect(certified.result.percentage, 90.0);

      final certificate = certified.certificate;
      expect(certificate, isNotNull);
      expect(certificate!.certificateName, 'Jane Doe');
      expect(certificate.certificateNumber, 'CB-PYTHON-0001');
      expect(certificate.score, 18);
      expect(certificate.total, 20);
      expect(certificate.downloadUrl, '/skill-up/assessment/python/certificate/download/');
      expect(certificate.editUrl, '/skill-up/assessment/python/certificate/edit/');
      expect(certificate.generatedAt, DateTime.parse('2026-09-20T10:15:00Z'));
    });

    test('throws FormatException when a required field is missing', () {
      final malformed = {
        'categories': <Map<String, dynamic>>[],
        'total_count': 0,
        // missing 'attempted_count'/'earned_count'
      };

      expect(() => CertificationsStatusParsing.fromJson(malformed), throwsFormatException);
    });

    test('throws FormatException when a subject is missing a required (non-nullable) field', () {
      final malformed = {
        'categories': [
          {
            'key': 'tech',
            'label': 'Tech Center',
            'total': 1,
            'attempted': 0,
            'earned': 0,
            'subjects': [
              {
                'subject': 'dsa',
                'label': 'DSA',
                'category': 'tech',
                'state': 'not_attempted',
                'pass_threshold': 70,
                // missing 'result'
                'certificate': null,
                'prefill_name': 'Jane Doe',
                'name_url': '/skill-up/assessment/dsa/certificate/name/',
              },
            ],
          },
        ],
        'total_count': 1,
        'attempted_count': 0,
        'earned_count': 0,
      };

      expect(() => CertificationsStatusParsing.fromJson(malformed), throwsFormatException);
    });

    test('throws FormatException for an unknown state value rather than silently accepting it', () {
      final malformed = {
        'categories': [
          {
            'key': 'tech',
            'label': 'Tech Center',
            'total': 1,
            'attempted': 0,
            'earned': 0,
            'subjects': [
              {..._notAttemptedSubjectJson, 'state': 'something_new'},
            ],
          },
        ],
        'total_count': 1,
        'attempted_count': 0,
        'earned_count': 0,
      };

      expect(() => CertificationsStatusParsing.fromJson(malformed), throwsFormatException);
    });
  });
}
