import 'package:career_buddy_lms/features/ai_speaking/domain/entities/speaking_issue.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/speaking_quick_tip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeSpeakingQuickTip', () {
    test('a top issue with a non-empty type and suggestion wins over every score-based branch', () {
      final tip = computeSpeakingQuickTip(
        transcript: 'This is a perfectly average length transcript for pace purposes here today.',
        issues: const [SpeakingIssue(phrase: 'a', type: 'Grammar', message: 'msg', suggestion: 'Use "an" instead.')],
        scores: const {'fluency': 90, 'pronunciation': 90, 'confidence': 90},
        elapsedSeconds: 30,
        pauseCount: 0,
      );
      expect(tip, 'Grammar: Use "an" instead.');
    });

    test('an issue with an empty suggestion falls through to the score-based branches', () {
      final tip = computeSpeakingQuickTip(
        transcript: 'word ' * 200,
        issues: const [SpeakingIssue(phrase: 'a', type: 'Grammar', message: 'msg', suggestion: '')],
        scores: const {},
        elapsedSeconds: 60,
        pauseCount: 0,
      );
      expect(tip, 'You are speaking too fast. Slow down slightly and finish each sentence clearly.');
    });

    test('speaking too fast (>175 wpm) is reported before pause/score checks', () {
      final tip = computeSpeakingQuickTip(
        transcript: List.generate(300, (i) => 'word').join(' '),
        issues: const [],
        scores: const {'fluency': 100, 'pronunciation': 100, 'confidence': 100},
        elapsedSeconds: 60,
        pauseCount: 0,
      );
      expect(tip, 'You are speaking too fast. Slow down slightly and finish each sentence clearly.');
    });

    test('speaking too slow (<90 wpm, but >0) is reported', () {
      final tip = computeSpeakingQuickTip(
        transcript: List.generate(20, (i) => 'word').join(' '),
        issues: const [],
        scores: const {'fluency': 100, 'pronunciation': 100, 'confidence': 100},
        elapsedSeconds: 60,
        pauseCount: 0,
      );
      expect(tip, 'Your pace is a bit slow. Keep a steady rhythm and connect ideas in short sentences.');
    });

    test('a normal pace with 3+ pauses reports the pause tip', () {
      final tip = computeSpeakingQuickTip(
        transcript: List.generate(120, (i) => 'word').join(' '),
        issues: const [],
        scores: const {'fluency': 100, 'pronunciation': 100, 'confidence': 100},
        elapsedSeconds: 60,
        pauseCount: 3,
      );
      expect(tip, 'Reduce long pauses. Take one short breath and continue your thought confidently.');
    });

    test('a normal pace with low fluency (<70) reports the pause tip even with 0 pauses', () {
      final tip = computeSpeakingQuickTip(
        transcript: List.generate(120, (i) => 'word').join(' '),
        issues: const [],
        scores: const {'fluency': 50, 'pronunciation': 100, 'confidence': 100},
        elapsedSeconds: 60,
        pauseCount: 0,
      );
      expect(tip, 'Reduce long pauses. Take one short breath and continue your thought confidently.');
    });

    test('a normal pace with low pronunciation (<75) reports the pronunciation tip', () {
      final tip = computeSpeakingQuickTip(
        transcript: List.generate(120, (i) => 'word').join(' '),
        issues: const [],
        scores: const {'fluency': 100, 'pronunciation': 60, 'confidence': 100},
        elapsedSeconds: 60,
        pauseCount: 0,
      );
      expect(tip, 'Focus on pronunciation: stress key words and open your mouth more on vowel sounds.');
    });

    test('a normal pace with low confidence (<75) reports the confidence tip', () {
      final tip = computeSpeakingQuickTip(
        transcript: List.generate(120, (i) => 'word').join(' '),
        issues: const [],
        scores: const {'fluency': 100, 'pronunciation': 100, 'confidence': 60},
        elapsedSeconds: 60,
        pauseCount: 0,
      );
      expect(tip, 'Improve confidence by using a stronger voice and ending sentences without trailing off.');
    });

    test('a good delivery with no issues falls through to the default tip', () {
      final tip = computeSpeakingQuickTip(
        transcript: List.generate(120, (i) => 'word').join(' '),
        issues: const [],
        scores: const {'fluency': 100, 'pronunciation': 100, 'confidence': 100},
        elapsedSeconds: 60,
        pauseCount: 0,
      );
      expect(tip, 'Good delivery. Next step: add clearer sentence structure and stronger keyword emphasis.');
    });

    test('missing score keys default to 70, which is not itself below the fluency/pronunciation/confidence thresholds', () {
      final tip = computeSpeakingQuickTip(
        transcript: List.generate(120, (i) => 'word').join(' '),
        issues: const [],
        scores: const {},
        elapsedSeconds: 60,
        pauseCount: 0,
      );
      // fluency default 70 < 70 is false (not strictly less), pronunciation/confidence default 70 < 75 is true.
      expect(tip, 'Focus on pronunciation: stress key words and open your mouth more on vowel sounds.');
    });
  });
}
