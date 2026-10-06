import 'package:career_buddy_lms/features/mock_tests/amcat/data/models/amcat_section_model.dart';
import 'package:career_buddy_lms/features/mock_tests/amcat/data/models/amcat_submission_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validSectionJson() => {
  'key': 'quant',
  'name': 'Quantitative Ability',
  'timeSec': 1080,
  'type': 'mcq',
  'questions': [
    {'id': 1, 'q': 'What is 15% of 795?', 'options': ['121', '113', '139', '119.25']},
  ],
};

Map<String, dynamic> _validSubmissionJson() => {
  'score': 40,
  'total': 153,
  'sections': {
    'quant': {'name': 'Quantitative Ability', 'correct': 10, 'total': 16},
  },
  'results': {
    '1': {'correct': true, 'section': 'quant', 'answer': 3, 'explanation': 'because'},
    '2': {'correct': false, 'section': 'quant'}, // unattempted: no answer/explanation
  },
};

void main() {
  group('AmcatSectionParsing.fromJson', () {
    test('parses a full valid section, ignoring the always-"mcq" type field', () {
      final section = AmcatSectionParsing.fromJson(_validSectionJson());

      expect(section.key, 'quant');
      expect(section.name, 'Quantitative Ability');
      expect(section.timeSeconds, 1080);
      expect(section.questions, hasLength(1));
      expect(section.questions.single.options, ['121', '113', '139', '119.25']);
    });

    test('throws when a required field (timeSec) is missing', () {
      final json = _validSectionJson()..remove('timeSec');
      expect(() => AmcatSectionParsing.fromJson(json), throwsFormatException);
    });

    test('throws on a malformed questions value', () {
      final json = _validSectionJson();
      json['questions'] = 'not-a-list';
      expect(() => AmcatSectionParsing.fromJson(json), throwsFormatException);
    });
  });

  group('AmcatSubmissionResultParsing.fromJson', () {
    test('parses score/total, per-section scores, and per-question results', () {
      final result = AmcatSubmissionResultParsing.fromJson(_validSubmissionJson());

      expect(result.score, 40);
      expect(result.total, 153);
      expect(result.sectionScores['quant']!.correct, 10);
      expect(result.sectionScores['quant']!.total, 16);
      expect(result.questionResults[1]!.isCorrect, isTrue);
      expect(result.questionResults[1]!.correctAnswerIndex, 3);
    });

    test('an unattempted question has no correctAnswerIndex revealed', () {
      final result = AmcatSubmissionResultParsing.fromJson(_validSubmissionJson());
      expect(result.questionResults[2]!.isCorrect, isFalse);
      expect(result.questionResults[2]!.correctAnswerIndex, isNull);
    });

    // W023: overallPercentage was changed to read the top-level score/total
    // fields directly, matching cocubes_mock_test.html's own explicit
    // preference for them over summing `sections` (see
    // AmcatSubmissionResult.overallPercentage's doc comment) — a
    // free-text "code" section would inflate a per-section sum without
    // the global `total` reflecting it, so the top-level fields are the
    // only value that's always correct for both AMCAT and CoCubes. This
    // replaces the old "derived from section tallies" test, which
    // asserted the opposite (and deliberately-wrong top-level 0/0) on
    // purpose to prove the old behavior.
    test('overallPercentage reads score/total directly, ignoring section tallies entirely', () {
      final result = AmcatSubmissionResultParsing.fromJson({
        'score': 17,
        'total': 34,
        'sections': {
          // Deliberately inconsistent with score/total, to prove this
          // isn't derived from section tallies.
          'quant': {'name': 'Quantitative Ability', 'correct': 999, 'total': 999},
        },
        'results': <String, dynamic>{},
      });
      expect(result.overallPercentage, 50.0);
    });

    test('overallPercentage is 0 when total is 0', () {
      final result = AmcatSubmissionResultParsing.fromJson({
        'score': 0,
        'total': 0,
        'sections': <String, dynamic>{},
        'results': <String, dynamic>{},
      });
      expect(result.overallPercentage, 0.0);
    });

    test('throws when a required field (score) is missing', () {
      final json = _validSubmissionJson()..remove('score');
      expect(() => AmcatSubmissionResultParsing.fromJson(json), throwsFormatException);
    });

    test('throws on a non-numeric results key', () {
      final json = _validSubmissionJson();
      (json['results'] as Map<String, dynamic>)['not-a-number'] = {'correct': false};
      expect(() => AmcatSubmissionResultParsing.fromJson(json), throwsFormatException);
    });
  });
}
