import 'package:career_buddy_lms/features/mock_tests/data/models/mock_test_question_model.dart';
import 'package:career_buddy_lms/features/mock_tests/data/models/mock_test_submission_result_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _validQuestionJson() => {
  'id': 7,
  'q': 'Which keyword prevents overriding a method in Java?',
  'options': ['final', 'static', 'abstract', 'private'],
  'difficulty': 'medium',
  'topic': 'inheritance',
};

Map<String, dynamic> _validSubmissionJson() => {
  'score': 42,
  'total': 50,
  'results': {
    '7': {'correct': true, 'answer': 0, 'explanation': "'final' methods can't be overridden."},
    '8': {'correct': false}, // not attempted: no answer/explanation revealed
  },
};

void main() {
  group('MockTestQuestionParsing.fromJson', () {
    test('parses a full valid question, never exposing an answer/explanation field', () {
      final question = MockTestQuestionParsing.fromJson(_validQuestionJson());

      expect(question.id, 7);
      expect(question.questionText, 'Which keyword prevents overriding a method in Java?');
      expect(question.options, ['final', 'static', 'abstract', 'private']);
      expect(question.difficulty, 'medium');
      expect(question.topic, 'inheritance');
    });

    test('defaults difficulty/topic safely when absent, rather than throwing', () {
      final json = _validQuestionJson()
        ..remove('difficulty')
        ..remove('topic');
      final question = MockTestQuestionParsing.fromJson(json);
      expect(question.difficulty, '');
      expect(question.topic, '');
    });

    test('throws when a required field (id) is missing', () {
      final json = _validQuestionJson()..remove('id');
      expect(() => MockTestQuestionParsing.fromJson(json), throwsFormatException);
    });

    test('throws when options is malformed', () {
      final json = _validQuestionJson();
      json['options'] = 'not-a-list';
      expect(() => MockTestQuestionParsing.fromJson(json), throwsFormatException);
    });
  });

  group('MockTestSubmissionResultParsing.fromJson', () {
    test('parses score/total and per-question results keyed by numeric id', () {
      final result = MockTestSubmissionResultParsing.fromJson(_validSubmissionJson());

      expect(result.score, 42);
      expect(result.total, 50);
      expect(result.results[7]!.isCorrect, isTrue);
      expect(result.results[7]!.correctAnswerIndex, 0);
      expect(result.results[7]!.wasAttempted, isTrue);
    });

    test('an unattempted question has no correctAnswerIndex/explanation revealed', () {
      final result = MockTestSubmissionResultParsing.fromJson(_validSubmissionJson());

      expect(result.results[8]!.isCorrect, isFalse);
      expect(result.results[8]!.correctAnswerIndex, isNull);
      expect(result.results[8]!.explanation, isNull);
      expect(result.results[8]!.wasAttempted, isFalse);
    });

    test('throws when a required field (score) is missing', () {
      final json = _validSubmissionJson()..remove('score');
      expect(() => MockTestSubmissionResultParsing.fromJson(json), throwsFormatException);
    });

    test('throws on a non-numeric results key', () {
      final json = _validSubmissionJson();
      (json['results'] as Map<String, dynamic>)['not-a-number'] = {'correct': false};
      expect(() => MockTestSubmissionResultParsing.fromJson(json), throwsFormatException);
    });
  });
}
