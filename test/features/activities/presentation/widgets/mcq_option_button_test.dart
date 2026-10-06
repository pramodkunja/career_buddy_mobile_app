import 'package:career_buddy_lms/features/activities/presentation/widgets/mcq_option_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Container containerFor(WidgetTester tester) {
    final containers = tester.widgetList<Container>(
      find.descendant(of: find.byType(McqOptionButton), matching: find.byType(Container)),
    );
    return containers.firstWhere((c) => (c.decoration as BoxDecoration?)?.border != null);
  }

  Material materialFor(WidgetTester tester) =>
      tester.widgetList<Material>(find.descendant(of: find.byType(McqOptionButton), matching: find.byType(Material))).first;

  testWidgets('default state uses the web\'s exact flat slate colors', (tester) async {
    await tester.pumpWidget(
      wrap(McqOptionButton(letter: 'a', text: 'Option A', selected: false, onTap: () {})),
    );

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.color, const Color(0xFFE2E8F0));
    final material = materialFor(tester);
    expect(material.color, const Color(0xFFF8FAFC));
  });

  testWidgets('selected state uses the web\'s exact blue colors, not the app\'s generic action blue', (tester) async {
    await tester.pumpWidget(
      wrap(McqOptionButton(letter: 'a', text: 'Option A', selected: true, onTap: () {})),
    );

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.color, const Color(0xFF2563EB));
    final material = materialFor(tester);
    expect(material.color, const Color(0xFFEFF6FF));
  });

  testWidgets('correct state uses the web\'s exact green colors and a check icon', (tester) async {
    await tester.pumpWidget(
      wrap(McqOptionButton(letter: 'a', text: 'Option A', selected: false, onTap: null, isCorrect: true)),
    );

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.color, const Color(0xFF10B981));
    final material = materialFor(tester);
    expect(material.color, const Color(0xFFECFDF5));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('wrong-selection state uses the web\'s exact red colors and a cancel icon', (tester) async {
    await tester.pumpWidget(
      wrap(McqOptionButton(letter: 'a', text: 'Option A', selected: true, onTap: null, isWrongSelection: true)),
    );

    final decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.color, const Color(0xFFEF4444));
    final material = materialFor(tester);
    expect(material.color, const Color(0xFFFEF2F2));
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('the border width is a constant 1.5px across every state, matching the web', (tester) async {
    await tester.pumpWidget(
      wrap(McqOptionButton(letter: 'a', text: 'Option A', selected: false, onTap: () {})),
    );
    var decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.width, 1.5);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      wrap(McqOptionButton(letter: 'a', text: 'Option A', selected: true, onTap: () {})),
    );
    decoration = containerFor(tester).decoration! as BoxDecoration;
    expect(decoration.border!.top.width, 1.5);
  });
}
