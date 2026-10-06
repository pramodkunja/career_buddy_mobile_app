import 'package:career_buddy_lms/shared/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('tapping the button invokes onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(AppButton(label: 'Continue', onPressed: () => tapped = true)),
    );

    await tester.tap(find.text('Continue'));
    expect(tapped, isTrue);
  });

  testWidgets('a loading button shows a spinner and ignores taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        AppButton(label: 'Continue', isLoading: true, onPressed: () => tapped = true),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  testWidgets('a disabled button (onPressed null) ignores taps', (tester) async {
    await tester.pumpWidget(wrap(const AppButton(label: 'Continue', onPressed: null)));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('backgroundColor/foregroundColor override the primary variant\'s colors when given', (tester) async {
    const bg = Color(0xFF2563EB);
    const fg = Colors.white;
    await tester.pumpWidget(
      wrap(AppButton(label: 'Submit', onPressed: () {}, backgroundColor: bg, foregroundColor: fg)),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.style?.backgroundColor?.resolve({}), bg);
    expect(button.style?.foregroundColor?.resolve({}), fg);
  });

  testWidgets('omitting backgroundColor/foregroundColor keeps the default primary style untouched', (tester) async {
    await tester.pumpWidget(wrap(AppButton(label: 'Submit', onPressed: () {})));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.style, isNull);
  });

  testWidgets('borderRadius overrides the primary variant\'s shape into a full pill when given', (tester) async {
    await tester.pumpWidget(
      wrap(AppButton(label: 'Submit', onPressed: () {}, borderRadius: BorderRadius.circular(999))),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final shape = button.style?.shape?.resolve({}) as RoundedRectangleBorder?;
    expect(shape?.borderRadius, BorderRadius.circular(999));
  });
}
