import 'package:career_buddy_lms/features/activities/domain/entities/mcq_question.dart';
import 'package:career_buddy_lms/features/activities/presentation/widgets/mcq_question_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

McqQuestion _question() => const McqQuestion(
  id: 1,
  questionText: "What is the synonym of 'concise'?",
  options: {'a': 'Brief', 'b': 'Long', 'c': 'Vague', 'd': 'Complex'},
  correctAnswer: 'a',
);

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

  testWidgets('renders the question text and every option', (tester) async {
    await tester.pumpWidget(
      wrap(McqQuestionCard(question: _question(), questionNumber: 1, selectedLetter: null, onSelect: (_) {})),
    );

    expect(find.text("What is the synonym of 'concise'?"), findsOneWidget);
    expect(find.text('Brief'), findsOneWidget);
    expect(find.text('Complex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an option invokes onSelect with its letter', (tester) async {
    String? selected;
    await tester.pumpWidget(
      wrap(McqQuestionCard(question: _question(), questionNumber: 1, selectedLetter: null, onSelect: (letter) => selected = letter)),
    );

    await tester.tap(find.text('Brief'));
    expect(selected, 'a');
  });

  testWidgets('once correctLetter is set (post-submission), options are no longer tappable', (tester) async {
    String? selected;
    await tester.pumpWidget(
      wrap(
        McqQuestionCard(
          question: _question(),
          questionNumber: 1,
          selectedLetter: 'b',
          correctLetter: 'a',
          onSelect: (letter) => selected = letter,
        ),
      ),
    );

    await tester.tap(find.text('Brief'));
    expect(selected, isNull);
    // Both the correct answer and the (wrong) selection get an icon.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });
}
