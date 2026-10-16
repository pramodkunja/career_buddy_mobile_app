import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;

/// Build-time environment selection.
///
/// Pass with `--dart-define=ENV=dev` / `--dart-define=ENV=staging`.
/// **Phase 35**: defaults to [Environment.production] when no `ENV` flag is
/// passed at all — changed from the previous default of [Environment.dev].
/// Confirmed directly (live, on a real physical device, this phase) that a
/// plain `flutter run`/`flutter build apk --debug` with no `--dart-define`
/// — the normal, default way anyone (not just a Flutter developer who
/// remembers the flag) launches or builds this app — silently resolved to
/// `http://10.0.2.2:8000`/`http://127.0.0.1:8000`, an address meaningless
/// outside an Android emulator. On a real device this is not just "the
/// wrong server," it is not a route to anywhere at all, so every request —
/// including login — hangs until Dio's `connectTimeout` fires and surfaces
/// as `"The request took too long. Please try again."`: the exact,
/// verbatim symptom reported. The pre-existing release-mode guard below
/// only ever caught this for a **release** build with `ENV` forgotten; nothing
/// caught the far more common case of a plain debug run/build, which is
/// almost certainly how this was actually being tested. Defaulting to the
/// real, positively-verified production backend instead means the app
/// reaches a real server out of the box; a developer who genuinely wants
/// the local Django dev server must now opt in explicitly with
/// `--dart-define=ENV=dev` (see `environment_test.dart`'s own doc comment
/// for how each branch is exercised).
///
/// [Environment.production] is a positively-verified real host (Batch 12 —
/// see `docs/BATCH_12_PRODUCTION_RELEASE.md` for the full evidence: DNS
/// resolution, a valid Let's Encrypt certificate issued specifically for
/// this domain, `DEBUG=False`-style security headers matching this exact
/// Django project's `settings.py`, and several routes/assets/behaviors
/// unique to this codebase — `/users/login/`, `/static/js/BOTscript.js`,
/// and `GET /api/riya/chat/` returning exactly the 405 the real view
/// only-accepts-POST behavior predicts — all confirmed live, read-only,
/// with no destructive or state-changing request made). No separate
/// staging host was found by that same investigation
/// (`api.careerbuddy4u.com` has no DNS record at all) — [Environment
/// .staging] remains unconfigured until one is confirmed.
enum Environment { dev, staging, production }

abstract final class EnvironmentConfig {
  static const String _envName = String.fromEnvironment(
    'ENV',
    defaultValue: 'production',
  );

  static Environment get current => resolve();

  /// The actual resolution logic behind [current]. Takes [releaseMode] as a
  /// parameter — rather than reading the global [kReleaseMode] constant
  /// directly — purely so a test can exercise the release-mode guard below
  /// without needing to compile an actual release binary ([kReleaseMode]
  /// can't be toggled at runtime).
  @visibleForTesting
  static Environment resolve({bool releaseMode = kReleaseMode}) {
    final env = switch (_envName) {
      'dev' => Environment.dev,
      'staging' => Environment.staging,
      // The default (see this class's own doc comment, Phase 35) and the
      // fallback for any unrecognized value — never silently dev.
      _ => Environment.production,
    };
    // Phase 35: now that `dev` is no longer the default, resolving to
    // [Environment.dev] in a release build can only mean `ENV=dev` was
    // passed *explicitly* (forgetting the flag entirely now safely
    // defaults to production instead). A release build has no legitimate
    // reason to ever point at the dev server (`10.0.2.2`), so this is kept
    // as a defense-in-depth guard against that explicit mistake. This
    // exact bug class has already happened twice in this project's history
    // (a release APK built before this guard existed, and — the Phase 35
    // finding that prompted flipping the default in the first place — a
    // debug build silently defaulting to `dev`, confirmed live on a real
    // device) — failing loudly here, the first time [baseUrl] is read,
    // turns that mistake into an immediate, visible crash instead of a
    // silent dead app in the client's hands.
    if (releaseMode && env == Environment.dev) {
      throw StateError(
        'Release build refused: ENV resolved to "dev" '
        '(baseUrl would be http://10.0.2.2:8000, unreachable outside a '
        'local emulator). Rebuild with --dart-define=ENV=production '
        '(see scripts/build_release.sh).',
      );
    }
    return env;
  }

  /// The Django dev server's default bind address. `10.0.2.2` is the Android
  /// emulator's alias for the host machine's `localhost`; iOS simulators and
  /// desktop/web can reach `localhost` directly.
  /// Optional dev-only override, e.g.
  /// `--dart-define=API_BASE_URL=http://192.168.0.243:8000` — needed on a
  /// physical phone, where `10.0.2.2` (emulator-only alias) is unreachable
  /// and every request just hits the connect timeout. Use the dev machine's
  /// LAN IP and run Django with `runserver 0.0.0.0:8000`.
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    switch (current) {
      case Environment.dev:
        if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
        final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
        return 'http://$host:8000';
      case Environment.staging:
        throw UnsupportedError(
          'Staging backend URL not configured.\n'
          'Configure the verified Career Buddy LMS staging backend '
          '(update EnvironmentConfig.baseUrl\'s Environment.staging branch) '
          'before distributing a staging build.',
        );
      case Environment.production:
        // Verified live (Batch 12) — see this file's class-level doc
        // comment and `docs/BATCH_12_PRODUCTION_RELEASE.md` for the full
        // evidence trail. `www.careerbuddy4u.com` resolves to the same
        // host and serves byte-identical responses; the bare domain is
        // used here since it's listed first in the real backend's own
        // `CSRF_TRUSTED_ORIGINS` (`business_english_lms/settings.py`).
        return 'https://careerbuddy4u.com';
    }
  }
}
