import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import 'demo_mode.dart';

/// Debug-only "Direct Demo Entry" (`RoutePaths.demoEntry`, `/demo`):
/// launch → tap "Preview Demo (Debug)" on the login screen → straight to
/// Activities with Demo Mode already on, no real login required.
///
/// Safe in a release build by construction, not just by omission: even if
/// this route were somehow reached (e.g. a stale deep link), the screen
/// itself checks `kDebugMode` and refuses to turn on
/// [demoModeEnabledProvider] or skip login when it's false — it redirects
/// to `/login` instead. The router-level auth bypass this route relies on
/// (`computeRedirect`'s `demoBypass` parameter, `route_guards.dart`) is
/// itself only ever passed `true` when `kDebugMode` is true (see
/// `app_router.dart`), so there are two independent, redundant gates, not
/// one.
class DemoEntryScreen extends ConsumerStatefulWidget {
  const DemoEntryScreen({super.key});

  @override
  ConsumerState<DemoEntryScreen> createState() => _DemoEntryScreenState();
}

class _DemoEntryScreenState extends ConsumerState<DemoEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!kDebugMode) {
        context.go(RoutePaths.login);
        return;
      }
      ref.read(demoModeEnabledProvider.notifier).set(true);
      context.go(RoutePaths.activities);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
