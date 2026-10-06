import 'package:career_buddy_lms/shared/widgets/app_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
}

void main() {
  group('AppFooter', () {
    testWidgets('renders the brand, tagline, and copyright', (tester) async {
      await _pump(tester, const AppFooter());

      // `Text.rich` splits the brand into two `TextSpan`s ("Career " /
      // "Buddy"), so `find.text` needs `findRichText: true` to match the
      // concatenated rendered string.
      expect(find.textContaining('Career Buddy', findRichText: true), findsNWidgets(2));
      expect(find.textContaining('Master Business English'), findsOneWidget);
      expect(find.textContaining('© 2026 Career Buddy'), findsOneWidget);
    });

    testWidgets('shows the activity stats strip by default', (tester) async {
      await _pump(tester, const AppFooter());

      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('Sub-Activities'), findsOneWidget);
      expect(find.text('Interactive Exercises'), findsOneWidget);
    });

    testWidgets('hides the activity stats strip when showActivityStats is false', (tester) async {
      await _pump(tester, const AppFooter(showActivityStats: false));

      expect(find.text('Activities'), findsNothing);
      expect(find.text('Sub-Activities'), findsNothing);
      expect(find.text('Interactive Exercises'), findsNothing);
    });

    testWidgets('shows the brand icon by default', (tester) async {
      await _pump(tester, const AppFooter());

      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    });

    testWidgets('hides the brand icon (but keeps the "Career Buddy" text) when showBrandIcon is false', (tester) async {
      await _pump(tester, const AppFooter(showBrandIcon: false));

      expect(find.byIcon(Icons.school_outlined), findsNothing);
      expect(find.textContaining('Career Buddy', findRichText: true), findsNWidgets(2));
    });
  });
}
