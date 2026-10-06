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

flutter build apk --release --dart-define=ENV=production
echo
echo "Built: build/app/outputs/flutter-apk/app-release.apk"
echo "(--dart-define=ENV=production — verified pointed at https://careerbuddy4u.com)"
