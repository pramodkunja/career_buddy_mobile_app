import 'package:career_buddy_lms/features/generic_writing/domain/entities/writing_prompt.dart';
import 'package:career_buddy_lms/features/generic_writing/domain/services/writing_limits.dart';
import 'package:career_buddy_lms/features/generic_writing/presentation/widgets/generic_writing_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SizedBox(width: 320, child: child)));

void main() {
  testWidgets('shows the prompt text, its Guide box, and the min/max hint', (tester) async {
    const prompt = WritingPrompt(
      position: 1,
      questionText: 'Describe the outcome.',
      guide: 'Aim for 80-120 words.',
    );
    final limits = getWritingLimits(exerciseTitle: 'X', questionText: prompt.questionText, guide: prompt.guide);

    await tester.pumpWidget(
      _wrap(GenericWritingPromptCard(prompt: prompt, draft: '', limits: limits, onChanged: (_) {})),
    );

    expect(find.text('Describe the outcome.'), findsOneWidget);
    expect(find.textContaining('Aim for 80-120 words.'), findsOneWidget);
    expect(find.text('80–120 words required'), findsOneWidget);
    expect(find.text('0 words'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides the Guide box when there is no guide text', (tester) async {
    const prompt = WritingPrompt(position: 1, questionText: 'Write freely.');
    const limits = WritingLimits(min: 50);

    await tester.pumpWidget(
      _wrap(GenericWritingPromptCard(prompt: prompt, draft: '', limits: limits, onChanged: (_) {})),
    );

    expect(find.textContaining('Guide:'), findsNothing);
    expect(find.text('Minimum 50 words required'), findsOneWidget);
  });

  testWidgets('the word count reflects the draft and calls onChanged as the user types', (tester) async {
    const prompt = WritingPrompt(position: 1, questionText: 'Write freely.');
    const limits = WritingLimits(min: 3);
    String? lastChanged;

    await tester.pumpWidget(
      _wrap(GenericWritingPromptCard(prompt: prompt, draft: '', limits: limits, onChanged: (text) => lastChanged = text)),
    );

    await tester.enterText(find.byType(TextField), 'one two three');
    expect(lastChanged, 'one two three');
  });

  testWidgets('word count text is green once within range and red/neutral otherwise', (tester) async {
    const prompt = WritingPrompt(position: 1, questionText: 'Write freely.');
    const limits = WritingLimits(min: 3, max: 5);

    await tester.pumpWidget(
      _wrap(GenericWritingPromptCard(prompt: prompt, draft: 'one two three', limits: limits, onChanged: (_) {})),
    );
    var text = tester.widget<Text>(find.text('3 words'));
    expect(text.style?.color, const Color(0xFF198754)); // within [3,5]

    await tester.pumpWidget(
      _wrap(GenericWritingPromptCard(prompt: prompt, draft: 'one two three four five six', limits: limits, onChanged: (_) {})),
    );
    text = tester.widget<Text>(find.text('6 words'));
    expect(text.style?.color, const Color(0xFFDC3545)); // over the max

    await tester.pumpWidget(_wrap(GenericWritingPromptCard(prompt: prompt, draft: '', limits: limits, onChanged: (_) {})));
    text = tester.widget<Text>(find.text('0 words'));
    expect(text.style?.color, const Color(0xFF64748B)); // neutral, nothing typed yet
  });
}
