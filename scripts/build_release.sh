#!/usr/bin/env bash
# Builds the real client-facing release APK, pointed at production.
#
# Plain `flutter build apk --release` (no --dart-define) resolves
# EnvironmentConfig.baseUrl to the dev server (http://10.0.2.2:8000),
# producing a release APK that can never reach any backend. This happened
# once already (see docs/ for the incident). `environment.dart` now also
# refuses to run in that state (fails fast with a clear error), but this
# script exists so the correct command never has to be remembered/retyped.
set -euo pipefail
cd "$(dirname "$0")/.."

# Refuse to produce a "production" artifact silently signed with the Android
# debug key — android/app/build.gradle.kts falls back to debug signing
# whenever android/key.properties is absent, which is the correct behavior
# for ad hoc/local release-mode testing but must never be mistaken for a
# real, distributable build. See docs/ANDROID_RELEASE_SIGNING.md.
if [[ ! -f android/key.properties ]]; then
  echo "ERROR: android/key.properties not found." >&2
  echo "This script produces the real, client-facing release APK and refuses to" >&2
  echo "silently fall back to debug signing for that artifact." >&2
  echo "See docs/ANDROID_RELEASE_SIGNING.md for how to generate and configure" >&2
  echo "the production upload keystore before running this script." >&2
  exit 1
fi

flutter build apk --release --dart-define=ENV=production
echo
echo "Built: build/app/outputs/flutter-apk/app-release.apk"
echo "(--dart-define=ENV=production — verified pointed at https://careerbuddy4u.com)"
