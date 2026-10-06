import 'package:career_buddy_lms/features/mock_tests/presentation/widgets/mock_exam_colors.dart';
import 'package:career_buddy_lms/features/mock_tests/presentation/widgets/mock_test_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Container containerFor(WidgetTester tester) {
    final containers = tester.widgetList<Container>(
      find.descendant(of: find.byType(MockTestOptionTile), matching: find.byType(Container)),
    );
    return containers.firstWhere((c) => (c.decoration as BoxDecoration?)?.border != null);
  }

  Material materialFor(WidgetTester tester) => tester
      .widgetList<Material>(find.descendant(of: find.byType(MockTestOptionTile), matching: find.byType(Material)))
      .first;

  testWidgets('default state uses the exam engine\'s navy-lavender palette, not MCQ\'s blue', (tester) async {
    await tester.pumpWidget(wrap(MockTestOptionTile(index: 0, text: 'Option A', selected: false, onTap: () {})));

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.color, MockExamColors.border);
    expect(materialFor(tester).color, Colors.white);
  });

  testWidgets('selected state uses navy border + lavender fill, not gold and not MCQ blue', (tester) async {
    await tester.pumpWidget(wrap(MockTestOptionTile(index: 0, text: 'Option A', selected: true, onTap: () {})));

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.color, MockExamColors.navy);
    expect(materialFor(tester).color, MockExamColors.selectedBg);
  });

  testWidgets('correct state uses the exam engine\'s own green, distinct from MCQ\'s', (tester) async {
    await tester.pumpWidget(
      wrap(MockTestOptionTile(index: 0, text: 'Option A', selected: false, onTap: null, isCorrect: true)),
    );

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.color, MockExamColors.success);
    expect(materialFor(tester).color, MockExamColors.successBg);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('wrong-selection state uses the exam engine\'s own red, distinct from MCQ\'s', (tester) async {
    await tester.pumpWidget(
      wrap(MockTestOptionTile(index: 0, text: 'Option A', selected: true, onTap: null, isWrongSelection: true)),
    );

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.color, MockExamColors.danger);
    expect(materialFor(tester).color, MockExamColors.dangerBg);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('the letter badge is a rounded square, not a circle, matching the web\'s .opt-badge', (tester) async {
    await tester.pumpWidget(wrap(MockTestOptionTile(index: 0, text: 'Option A', selected: false, onTap: () {})));

    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('letters derive from index (A, B, C, D)', (tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(wrap(MockTestOptionTile(index: i, text: 'Option', selected: false, onTap: () {})));
      expect(find.text(String.fromCharCode(65 + i)), findsOneWidget);
    }
  });
}
