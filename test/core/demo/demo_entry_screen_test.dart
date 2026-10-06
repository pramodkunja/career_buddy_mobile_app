import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/demo/demo_entry_screen.dart';
import 'package:career_buddy_lms/core/demo/demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> pumpAt(WidgetTester tester, {ProviderContainer? container}) async {
  final router = GoRouter(
    initialLocation: RoutePaths.demoEntry,
    routes: [
      GoRoute(path: RoutePaths.demoEntry, builder: (context, state) => const DemoEntryScreen()),
      GoRoute(path: RoutePaths.activities, builder: (context, state) => const Scaffold(body: Text('Activities'))),
      GoRoute(path: RoutePaths.login, builder: (context, state) => const Scaffold(body: Text('Login'))),
    ],
  );
  final effectiveContainer = container ?? ProviderContainer();
  addTearDown(effectiveContainer.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: effectiveContainer, child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  // `flutter test` runs in a debug-mode-equivalent environment, so
  // `kDebugMode` is true here — this exercises the "turns on Demo Mode and
  // reaches Activities" path, matching what a developer running
  // `flutter run` (debug) sees. The `!kDebugMode` release-safety branch is
  // a compile-time constant this test process cannot flip; documented the
  // same way in `demo_mode_test.dart`/`demo_mode_toggle_test.dart`.
  testWidgets('turns on demoModeEnabledProvider and navigates to Activities', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await pumpAt(tester, container: container);

    expect(container.read(demoModeEnabledProvider), isTrue);
    expect(find.text('Activities'), findsOneWidget);
  });

  testWidgets('shows a loading indicator momentarily before redirecting', (tester) async {
    final router = GoRouter(
      initialLocation: RoutePaths.demoEntry,
      routes: [
        GoRoute(path: RoutePaths.demoEntry, builder: (context, state) => const DemoEntryScreen()),
        GoRoute(path: RoutePaths.activities, builder: (context, state) => const Scaffold(body: Text('Activities'))),
      ],
    );
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
