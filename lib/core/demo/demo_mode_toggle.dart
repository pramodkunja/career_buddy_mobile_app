import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_snackbar.dart';
import 'demo_mode.dart';

/// A debug-only AppBar action that toggles Demo Mode. Renders nothing when
/// `kDebugMode` is false, so it is never visible — and Demo Mode itself can
/// never be active — in a release build. Placed on `ActivityListScreen`,
/// the first screen reached after login, so it's immediately reachable.
class DemoModeToggleAction extends ConsumerWidget {
  const DemoModeToggleAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

    final enabled = ref.watch(demoModeEnabledProvider);
    return IconButton(
      icon: Icon(enabled ? Icons.science : Icons.science_outlined),
      tooltip: enabled ? 'Demo Mode: ON (tap to disable)' : 'Demo Mode: OFF (tap to enable)',
      color: enabled ? Theme.of(context).colorScheme.secondary : null,
      onPressed: () {
        ref.read(demoModeEnabledProvider.notifier).toggle();
        final nowEnabled = ref.read(demoModeEnabledProvider);
        AppSnackbar.showSuccess(
          context,
          nowEnabled
              ? 'Demo Mode ON — Activities/Exercises now use local demo data.'
              : 'Demo Mode OFF — back to real API data.',
        );
      },
    );
  }
}
