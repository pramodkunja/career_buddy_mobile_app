import 'package:career_buddy_lms/shared/widgets/coming_soon_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the given title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ComingSoonScreen(title: 'Create Account', message: 'Not available yet.'),
      ),
    );

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Not available yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at narrow phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ComingSoonScreen(
          title: 'Employer Portal',
          message:
              'The employer portal isn\'t available in the app yet. '
              'Please sign in as an employer on the Career Buddy website for now.',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
