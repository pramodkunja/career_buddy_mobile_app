import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Batch 11 — `ApiClient.create()` reads `EnvironmentConfig.baseUrl`, which
  // deliberately throws for `Environment.staging`/`Environment.production`
  // until a real, verified backend host is configured (see that file's own
  // doc comment — never fabricated here). Left uncaught, that throw would
  // still stop the app before `runApp` (a real build pointed at an
  // unconfigured environment *can never silently proceed*), but as a bare
  // stack trace with no actionable guidance. Catching it here and rendering
  // a plain, unmistakable configuration-error screen instead is a pure UX
  // improvement — it does not change *whether* an unconfigured build fails,
  // only how clearly it fails.
  try {
    final apiClient = await ApiClient.create();
    runApp(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(apiClient)],
        child: const CareerBuddyApp(),
      ),
    );
  } on UnsupportedError catch (e) {
    runApp(_ConfigurationErrorApp(message: e.message ?? 'Backend not configured.'));
  }
}

/// Shown only when the selected `Environment` has no real backend host
/// configured — see `main()`'s doc comment above. Deliberately minimal
/// (no theming/router/Riverpod dependency), since none of the app's real
/// infrastructure could initialize.
class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF14213D),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_suggest_outlined, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
