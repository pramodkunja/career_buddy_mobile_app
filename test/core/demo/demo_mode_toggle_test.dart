import 'package:career_buddy_lms/core/demo/demo_mode.dart';
import 'package:career_buddy_lms/core/demo/demo_mode_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app() => MaterialApp(home: Scaffold(appBar: AppBar(actions: const [DemoModeToggleAction()])));

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(child: _app()));
}

void main() {
  // `flutter test` runs in a debug-mode-equivalent environment, so
  // `kDebugMode` is true here and the action renders — matching what a
  // developer running `flutter run` (debug) sees. The release-build case
  // (icon renders nothing) is a compile-time `kDebugMode` branch this test
  // process cannot flip; see `demo_mode_test.dart`'s note on the same
  // limitation.
  testWidgets('shows the "off" icon by default', (tester) async {
    await _pump(tester);

    expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    expect(find.byIcon(Icons.science), findsNothing);
  });

  testWidgets('tapping toggles demoModeEnabledProvider and swaps the icon', (tester) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.science), findsOneWidget);
    expect(find.byIcon(Icons.science_outlined), findsNothing);
    expect(find.textContaining('Demo Mode ON'), findsOneWidget);
  });

  testWidgets('tapping again turns it back off', (tester) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.science_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.science));
    await tester.pump();

    expect(find.byIcon(Icons.science_outlined), findsOneWidget);
    expect(find.textContaining('Demo Mode OFF'), findsOneWidget);
  });

  testWidgets('reflects an externally-set demoModeEnabledProvider state', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(demoModeEnabledProvider.notifier).set(true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _app(),
      ),
    );

    expect(find.byIcon(Icons.science), findsOneWidget);
  });
}
