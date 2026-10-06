import 'package:career_buddy_lms/features/generic_writing/domain/services/writing_client_scorer.dart';
import 'package:flutter_test/flutter_test.dart';

// Distinct filler words with no punctuation, so sentence-splitting
// (`text.split(/[.!?]+/)`) treats a filler run as exactly one "sentence"
// and word-counting is exact and predictable.
String _words(int start, int count) => List.generate(count, (i) => 'word${start + i}').join(' ');

int _score(List<WritingScoreInput> answers, {String exerciseTitle = 'Some Exercise'}) =>
    computeGenericWritingClientScore(exerciseTitle: exerciseTitle, answers: answers);

void main() {
  group('computeGenericWritingClientScore — word-count tiers (default min 50, no max)', () {
    test('meeting the minimum scores 100', () {
      final score = _score([WritingScoreInput(text: _words(1, 50), questionText: 'Write about your day.')]);
      expect(score, 100);
    });

    test('at least 70% of the minimum scores 80', () {
      final score = _score([WritingScoreInput(text: _words(1, 35), questionText: 'Write about your day.')]);
      expect(score, 80);
    });

    test('at least 40% of the minimum scores 50', () {
      final score = _score([WritingScoreInput(text: _words(1, 25), questionText: 'Write about your day.')]);
      expect(score, 50);
    });

    test('any non-empty answer below 40% scores 20', () {
      final score = _score([WritingScoreInput(text: _words(1, 5), questionText: 'Write about your day.')]);
      expect(score, 20);
    });

    test('an empty answer scores 0', () {
      final score = _score([WritingScoreInput(text: '', questionText: 'Write about your day.')]);
      expect(score, 0);
    });
  });

  group('computeGenericWritingClientScore — copying the question text back', () {
    test('an answer containing the (>20-char) question text verbatim is penalized to 30% of its tier score', () {
      const questionText = 'Describe your reflections on the negotiation process in detail.';
      final answer = '$questionText ${_words(1, 45)}'; // 9 + 45 = 54 words, well over the 50-word minimum
      final score = _score([WritingScoreInput(text: answer, questionText: questionText)]);
      expect(score, 30); // round(100 * 0.3)
    });

    test('a short (<=20-char) question text is never checked for copying, even if literally repeated', () {
      const questionText = 'Reflect on this.'; // 17 chars, 3 words
      final answer = '$questionText ${_words(1, 50)}'; // 3 + 50 = 53 words, over the 50-word minimum
      final score = _score([WritingScoreInput(text: answer, questionText: questionText)]);
      expect(score, 100); // no penalty applied
    });
  });

  group('computeGenericWritingClientScore — required recommendations/examples count', () {
    test('fewer list items/keyword-starts than the prompt requires scales the score down proportionally', () {
      const questionText = 'Write 3 actionable recommendations for improving efficiency.';
      // 50 filler words, no bullet markers, no recognized keyword starts —
      // `countFound` floors at 1 (`Math.max(0, 0, 1)`), so ratio = 1/3.
      final score = _score([WritingScoreInput(text: _words(1, 50), questionText: questionText)]);
      expect(score, 33); // round(100 * (1/3))
    });
  });

  group('computeGenericWritingClientScore — contextual relevance', () {
    test('mentioning none of the prompt\'s referenced figures drops the score to 40%', () {
      const questionText = 'Compare the results: revenue grew by 15% while costs increased by 8%.';
      final score = _score([WritingScoreInput(text: _words(1, 50), questionText: questionText)]);
      expect(score, 40); // round(100 * 0.4)
    });

    test('a prompt with fewer than 2 referenced figures skips the relevance check entirely', () {
      const questionText = 'Discuss the 15% increase.'; // only one data point
      final score = _score([WritingScoreInput(text: _words(1, 50), questionText: questionText)]);
      expect(score, 100);
    });
  });

  group('computeGenericWritingClientScore — sentence repetition', () {
    test('a duplicated sentence (>25 chars) costs 20 points', () {
      const sentence = 'This is a duplicated test sentence for repetition detection';
      final score = _score([
        WritingScoreInput(text: '$sentence. $sentence.', questionText: 'Reflect on this.', guide: 'Aim for 10-500 words.'),
      ]);
      expect(score, 80); // 100 - 20
    });
  });

  group('computeGenericWritingClientScore — structure check', () {
    const guide = 'Follow structure: state your purpose, summarize findings, and give a recommendation.';

    test('satisfying every required section (purpose/findings/recommendation) applies no penalty', () {
      final answer = '${_words(1, 30)}. recommend ${_words(31, 20)}.'; // 2 sentences, contains "recommend"
      final score = _score([WritingScoreInput(text: answer, questionText: 'Follow structure.', guide: guide)]);
      expect(score, 100);
    });

    test('missing one of the required sections scales the score down proportionally', () {
      final answer = '${_words(1, 30)}. ${_words(31, 20)}.'; // 2 sentences, no recommend/should/suggest
      final score = _score([WritingScoreInput(text: answer, questionText: 'Follow structure.', guide: guide)]);
      expect(score, 67); // round(100 * 2/3) — purpose + findings met, recommendation missing
    });
  });

  group('computeGenericWritingClientScore — averaging across prompts', () {
    test('the overall score is the mean of each prompt\'s own score', () {
      final score = _score([
        WritingScoreInput(text: _words(1, 50), questionText: 'Write about your day.'), // 100
        WritingScoreInput(text: '', questionText: 'Write about tomorrow.'), // 0
      ]);
      expect(score, 50);
    });
  });

  group('computeGenericWritingClientScore — cross-prompt duplication', () {
    test('two substantial (>50 char) identical responses cut the final score to 40%', () {
      final sharedAnswer = _words(1, 60); // well over 50 chars, identical in both prompts
      final score = _score([
        WritingScoreInput(text: sharedAnswer, questionText: 'Write about your day.'),
        WritingScoreInput(text: sharedAnswer, questionText: 'Write about tomorrow.'),
      ]);
      expect(score, 40); // round(100 * 0.4)
    });
  });

  test('an exercise with no prompts scores 0', () {
    expect(_score(const []), 0);
  });
}
