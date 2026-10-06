import 'package:career_buddy_lms/features/activities/domain/entities/mcq_exercise.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_question.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_question_result.dart';
import 'package:career_buddy_lms/features/activities/domain/entities/mcq_submission_result.dart';
import 'package:career_buddy_lms/features/activities/presentation/widgets/mcq_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

McqExercise _exercise() => const McqExercise(
  id: 1,
  title: 'Vocab Quiz',
  questions: [McqQuestion(id: 100, questionText: 'Q1?', options: {'a': 'A', 'b': 'B'}, correctAnswer: 'a')],
);

McqSubmissionResult _result({required int percentage, String? explanation, bool isCorrect = true}) =>
    McqSubmissionResult(
      exerciseId: 1,
      score: percentage,
      maxScore: 100,
      percentage: percentage,
      attemptNumber: 1,
      questions: [
        McqQuestionResult(
          questionId: 100,
          selected: 'a',
          correct: isCorrect ? 'a' : 'b',
          isCorrect: isCorrect,
          explanation: explanation,
        ),
      ],
    );

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  // Tier thresholds/messages/emoji verbatim from `showResultPanel()`
  // (`static/js/exercises.js:81-108`).
  final cases = <(int, String, String)>[
    (100, '🏆', 'Perfect Score!'),
    (95, '🌟', 'Excellent!'),
    (85, '✨', 'Very Good!'),
    (70, '👍', 'Good Job!'),
    (45, '💪', 'Average'),
    (10, '📚', 'Keep Practising'),
  ];

  for (final (percentage, emoji, message) in cases) {
    testWidgets('shows "$message" ($emoji) at $percentage%, matching the web\'s tier', (tester) async {
      await tester.pumpWidget(wrap(McqResultView(exercise: _exercise(), result: _result(percentage: percentage))));

      expect(find.text(message), findsOneWidget);
      expect(find.text(emoji), findsOneWidget);
    });
  }

  testWidgets('a correct question shows a green-tinted "✓ Correct!" explanation box', (tester) async {
    await tester.pumpWidget(
      wrap(McqResultView(exercise: _exercise(), result: _result(percentage: 100, explanation: 'Because reasons.'))),
    );

    expect(find.textContaining('✓ Correct!'), findsOneWidget);
    expect(find.textContaining('Because reasons.'), findsOneWidget);
  });

  testWidgets('a wrong question shows a red-tinted "✗ Incorrect." explanation box', (tester) async {
    await tester.pumpWidget(
      wrap(
        McqResultView(
          exercise: _exercise(),
          result: _result(percentage: 0, explanation: 'Because reasons.', isCorrect: false),
        ),
      ),
    );

    expect(find.textContaining('✗ Incorrect.'), findsOneWidget);
  });

  testWidgets('no explanation box is shown when the server sends no explanation', (tester) async {
    await tester.pumpWidget(wrap(McqResultView(exercise: _exercise(), result: _result(percentage: 100))));

    expect(find.textContaining('✓ Correct!'), findsNothing);
  });
}
