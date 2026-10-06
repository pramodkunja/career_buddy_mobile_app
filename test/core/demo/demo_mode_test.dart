import 'package:career_buddy_lms/core/demo/demo_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demoModeEnabledProvider', () {
    test('starts disabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(demoModeEnabledProvider), isFalse);
    });

    test('toggle() flips the state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(demoModeEnabledProvider.notifier).toggle();
      expect(container.read(demoModeEnabledProvider), isTrue);

      container.read(demoModeEnabledProvider.notifier).toggle();
      expect(container.read(demoModeEnabledProvider), isFalse);
    });

    test('set() assigns an explicit value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(demoModeEnabledProvider.notifier).set(true);
      expect(container.read(demoModeEnabledProvider), isTrue);

      container.read(demoModeEnabledProvider.notifier).set(false);
      expect(container.read(demoModeEnabledProvider), isFalse);
    });
  });

  group('demoModeActiveProvider', () {
    // `flutter test` runs in a debug-mode-equivalent environment, so
    // `kDebugMode` is true here — this confirms the toggle actually drives
    // the provider every repository provider reads, under the only build
    // mode this test suite can exercise. The `kDebugMode` release-build
    // gate itself (demo_mode.dart's `if (!kDebugMode) return false;`) is a
    // compile-time constant this test process cannot flip, so it is not
    // independently exercisable from `flutter test` — documented here
    // rather than silently skipped.
    test('mirrors demoModeEnabledProvider under the test/debug build', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(demoModeActiveProvider), isFalse);

      container.read(demoModeEnabledProvider.notifier).set(true);
      expect(container.read(demoModeActiveProvider), isTrue);

      container.read(demoModeEnabledProvider.notifier).set(false);
      expect(container.read(demoModeActiveProvider), isFalse);
    });
  });
}
