import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/features/dashboard/presentation/widgets/quick_start_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  // In production this always sits inside `DashboardScreen`'s scrollable
  // `ListView` — wrapping it the same way here (instead of a bare
  // `Scaffold(body: ...)`) matches that real embedding context, since the
  // web's 2-column grid (`.quick-links`) is naturally taller than the old
  // single-row wrap of chips it replaced.
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

  testWidgets('renders all 7 of the web dashboard\'s Quick Start category links', (tester) async {
    await tester.pumpWidget(wrap(const QuickStartSection()));

    for (final label in [
      'Speaking',
      'Writing',
      'Vocabulary',
      'Negotiation',
      'Communication',
      'Analysis',
      'Workshop',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label should be one of the 7 Quick Start links');
    }
  });

  testWidgets('tapping a category opens the Activities list pre-filtered to it', (tester) async {
    String? capturedCategory;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: SingleChildScrollView(child: QuickStartSection())),
        ),
        GoRoute(
          path: RoutePaths.activities,
          builder: (context, state) {
            capturedCategory = state.uri.queryParameters['category'];
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));

    await tester.tap(find.text('Speaking'));
    await tester.pumpAndSettle();

    expect(capturedCategory, 'speaking');
  });
}
