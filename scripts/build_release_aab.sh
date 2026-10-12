#!/usr/bin/env bash
# Builds the production Android App Bundle (.aab) — the format Google Play
# requires for upload (an .apk, built by build_release.sh, is for direct
# install/testing only and is never what you upload to the Play Console).
#
# Same ENV=production safety rationale as build_release.sh: plain
# `flutter build appbundle --release` (no --dart-define) resolves
# EnvironmentConfig.baseUrl to the dev server, and environment.dart refuses
# to run in that state — see that file's doc comment.
#
# Signing: uses whatever `android/app/build.gradle.kts` resolves for the
# `release` build type — the production upload key from
# android/key.properties if that file exists (see
# docs/ANDROID_RELEASE_SIGNING.md). This script does not create, modify, or
# read android/key.properties itself, but it does check for its existence
# below and refuses to proceed without it: an .aab built by this script is,
# by definition, meant for Play Console upload, and Google Play permanently
# binds an app to whichever key first signs it, so silently falling back to
# the debug key here (as build.gradle.kts otherwise would) must never happen
# unnoticed.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f android/key.properties ]]; then
  echo "ERROR: android/key.properties not found." >&2
  echo "This script produces the .aab meant for Google Play Console upload and" >&2
  echo "refuses to silently sign it with the Android debug key." >&2
  echo "See docs/ANDROID_RELEASE_SIGNING.md for how to generate and configure" >&2
  echo "the production upload keystore before running this script." >&2
  exit 1
fi

flutter build appbundle --release --dart-define=ENV=production
echo
echo "Built: build/app/outputs/bundle/release/app-release.aab"
echo "(--dart-define=ENV=production — verified pointed at https://careerbuddy4u.com)"
echo
echo "Before uploading to Play Console, confirm the signing certificate with:"
echo "  jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab"
echo "(an .aab is signed as a plain JAR, not with apksigner/APK Signature"
echo "Scheme — jarsigner is the correct tool here) and check the printed"
echo "certificate's CN/fingerprint is your real upload key, not 'CN=Android Debug'."
