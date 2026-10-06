import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runtime Demo Mode toggle. When active, every repository provider in
/// `*_providers.dart` swaps its real, API-backed implementation for an
/// in-memory demo implementation (`lib/core/demo/`) instead of hitting the
/// network — so Activities/Exercises/AI-module screens can be exercised
/// end-to-end without any real `Activity`/`SubActivity`/`Exercise` rows in
/// the (intentionally empty) development database. Demo Mode never touches
/// authentication — a real login is still required to reach these screens.
///
/// [demoModeEnabledProvider] is the switch a debug-only UI toggle flips.
/// [demoModeActiveProvider] is what repository providers actually read: it
/// is hard-`false` whenever `kDebugMode` is false, so Demo Mode cannot
/// activate in a release build even if [demoModeEnabledProvider]'s state
/// were somehow `true`.
class DemoModeEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;

  void toggle() => state = !state;
}

final demoModeEnabledProvider = NotifierProvider<DemoModeEnabledNotifier, bool>(DemoModeEnabledNotifier.new);

final demoModeActiveProvider = Provider<bool>((ref) {
  if (!kDebugMode) return false;
  return ref.watch(demoModeEnabledProvider);
});
