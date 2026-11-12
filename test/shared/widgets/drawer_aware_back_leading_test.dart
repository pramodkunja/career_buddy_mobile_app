import 'package:career_buddy_lms/shared/widgets/drawer_aware_back_leading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen shaped like every real screen that hit this bug: its own
/// `drawer` plus `leading: drawerAwareBackLeading(context)` — reachable
/// both as a root destination (nothing to pop to) and pushed on top of
/// another screen (something to pop to).
Widget _screen() {
  return Builder(
    builder: (context) => Scaffold(
      drawer: const Drawer(child: Text('Drawer content')),
      appBar: AppBar(title: const Text('Screen'), leading: drawerAwareBackLeading(context)),
      body: const SizedBox.shrink(),
    ),
  );
}

void main() {
  testWidgets('as a root destination (nothing to pop to), shows the drawer hamburger, not a back arrow', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _screen()));

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(BackButtonIcon), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Drawer content'), findsOneWidget, reason: 'the drawer itself must still open normally');
  });

  testWidgets(
    'while the drawer is open (LocalHistoryEntry active) the leading stays as a '
    'hamburger — canPop returning true via willHandlePopInternally must not flip it '
    'to a back arrow',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: _screen()));

      // Open the drawer — Flutter adds a LocalHistoryEntry, making canPop = true.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byType(BackButtonIcon), findsNothing);
    },
  );

  testWidgets(
    'after the drawer is closed the hamburger is restored and no stale back arrow lingers',
    (tester) async {
      await tester.pumpWidget(MaterialApp(home: _screen()));

      // Open
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Close by tapping the scrim (outside the 304 dp drawer panel; default test
      // window is 800×600 at DPR 1.0, so x=600 is well into the scrim area).
      await tester.tapAt(const Offset(600, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byType(BackButtonIcon), findsNothing);
    },
  );

  testWidgets('when pushed on top of another screen, shows a real back arrow instead of the hamburger', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _screen())),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsNothing, reason: 'a pushed screen must not fall back to the drawer hamburger');
    expect(find.byType(BackButtonIcon), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget, reason: 'the back arrow must actually pop the route');
  });
}
