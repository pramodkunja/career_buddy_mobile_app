import 'package:career_buddy_lms/features/timer_exercise/domain/services/timer_client_scorer.dart';
import 'package:flutter_test/flutter_test.dart';

String _repeat(String phrase, int times) => List.generate(times, (_) => phrase).join(' ');

void main() {
  group('computeTimerClientScore', () {
    test('max_score is always the total task count, never 100 (unlike Generic Writing)', () {
      final result = computeTimerClientScore(totalTasks: 5, answers: const []);
      expect(result.maxScore, 5);
      expect(result.score, 0);
    });

    test('a task with an empty (never-started) transcript contributes nothing, but still counts toward max_score', () {
      final result = computeTimerClientScore(
        totalTasks: 2,
        answers: const [TimerTaskAnswer(position: 1, transcript: '', questionText: 'Describe your morning routine.')],
      );
      expect(result.score, 0);
      expect(result.maxScore, 2); // totalTasks, not answers.length
    });

    test('a full-marks task: 70+ words hitting every keyword scores the full point for that task', () {
      // promptText = "task 1: describe your plan." -> keywords (4+ chars):
      // task, describe, your, plan.
      final result = computeTimerClientScore(
        totalTasks: 1,
        answers: [
          TimerTaskAnswer(
            position: 1,
            transcript: _repeat('task describe your plan', 18), // 72 words, >= 70 target
            questionText: 'Describe your plan.',
          ),
        ],
      );
      expect(result.score, 1); // round(1.0 * 0.5 + 1.0 * 0.5)
      expect(result.maxScore, 1);
    });

    test('word score is capped at 1 once 70+ words are captured, regardless of extra length', () {
      // No keyword overlap at all (relScore = 0), isolating the word-count
      // half of the formula: contribution should be exactly 0.5 whether the
      // transcript is 70 or 500 words.
      final resultAt70 = computeTimerClientScore(
        totalTasks: 1,
        answers: [
          TimerTaskAnswer(
            position: 1,
            transcript: List.generate(70, (i) => 'zz$i').join(' '),
            questionText: 'Explain your favorite hobby.',
          ),
        ],
      );
      final resultAt500 = computeTimerClientScore(
        totalTasks: 1,
        answers: [
          TimerTaskAnswer(
            position: 1,
            transcript: List.generate(500, (i) => 'zz$i').join(' '),
            questionText: 'Explain your favorite hobby.',
          ),
        ],
      );
      expect(resultAt70.score, 1); // round(1.0*0.5 + 0*0.5) = round(0.5) = 1
      expect(resultAt70.score, resultAt500.score); // same either way — capped, not linear beyond 70
    });

    test('two tasks each at half credit sum and round (0.25 + 0.25 = 0.5, rounds up to 1)', () {
      // promptText = "task 1: talk about anything." -> keywords: task, talk,
      // about, anything. Transcript matches none of them and is exactly 35
      // words (half of the 70-word target) -> wordScore 0.5, relScore 0 ->
      // contribution 0.25 per task.
      final answer = TimerTaskAnswer(
        position: 1,
        transcript: List.generate(35, (i) => 'zz$i').join(' '),
        questionText: 'Talk about anything.',
      );
      final result = computeTimerClientScore(totalTasks: 2, answers: [answer, answer]);
      expect(result.score, 1); // round(0.25 + 0.25) = round(0.5) = 1
      expect(result.maxScore, 2);
    });

    test('an unattempted task among several still counts toward max_score but contributes 0', () {
      final result = computeTimerClientScore(
        totalTasks: 3,
        answers: [
          TimerTaskAnswer(position: 1, transcript: _repeat('task describe your plan', 18), questionText: 'Describe your plan.'),
          const TimerTaskAnswer(position: 2, transcript: '', questionText: 'Never started.'),
        ],
      );
      expect(result.score, 1); // only task 1 contributed a full point
      expect(result.maxScore, 3); // totalTasks, including the 3rd task not even passed in
    });
  });
}
