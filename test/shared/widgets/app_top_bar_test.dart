import 'package:career_buddy_lms/shared/widgets/app_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTopBar', () {
    testWidgets('renders the brand mark and has a 60px preferred height', (tester) async {
      const topBar = AppTopBar();
      expect(topBar.preferredSize, const Size.fromHeight(60));

      await tester.pumpWidget(const MaterialApp(home: Scaffold(appBar: topBar, body: SizedBox())));

      // `Text.rich` splits the brand into two `TextSpan`s ("Career " /
      // "Buddy"), so `find.text` needs `findRichText: true` to match the
      // concatenated rendered string.
      expect(find.textContaining('Career Buddy', findRichText: true), findsOneWidget);
    });

    testWidgets('shows the drawer-toggle hamburger when a Scaffold drawer is present', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(appBar: AppTopBar(), drawer: Drawer(), body: SizedBox())),
      );

      expect(find.byIcon(Icons.menu), findsOneWidget);
    });
  });
}
