# Batch 14 — Release Candidate & Store Submission Readiness

## STATUS

**READY_PENDING_OWNER_INPUT**

The Flutter application itself — code, configuration, and build
artifacts — is technically release-ready: `flutter analyze` is clean,
all 1544 tests pass, and all three release artifacts (APK, AAB, iOS)
build successfully against the verified production backend. It cannot
be called fully `READY_FOR_STORE_CONFIGURATION` because real store
submission needs several inputs only the project/business owner can
provide (a real signing/upload keystore, an Apple Developer Team, a
real app icon, a privacy policy, store listing copy, and real test
credentials for the still-open live-auth verification) — none of which
this batch fabricated. See FINAL OWNER CHECKLIST.

## RELEASE CONFIGURATION

| Item | Status | Evidence |
|---|---|---|
| Production URL | VERIFIED (Batch 12) | `EnvironmentConfig.production` → `https://careerbuddy4u.com`, re-confirmed unchanged this batch |
| Environment flag | VERIFIED | All 3 builds this batch used `--dart-define=ENV=production`; the literal host string was previously confirmed compiled into the AOT binary (Batch 12) |
| Android package | `com.sriainfotech.career_buddy_lms` | `aapt2 dump badging` on the real built APK |
| iOS bundle ID | `com.sriainfotech.careerBuddyLms` | `project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`) |
| Version | `1.0.0` (versionName / `CFBundleShortVersionString`) | `pubspec.yaml`'s `version: 1.0.0+1`; confirmed in the built APK via `aapt2` |
| Build number | `1` (versionCode / `CFBundleVersion`) | Same source |
| Signing | **NOT PRODUCTION-READY** — Android release build type is explicitly configured to sign with the **debug** key (`signingConfig = signingConfigs.getByName("debug")`, `android/app/build.gradle.kts`); iOS has `CODE_SIGN_STYLE = Automatic` with no `DEVELOPMENT_TEAM` set. FIXING THIS IS OWNER ACTION, not something this batch can do — see FINAL OWNER CHECKLIST | Direct source read, unchanged this batch (correctly not touched, per this batch's own rule not to rotate/generate keys) |

## ANDROID

| Check | Status |
|---|---|
| APK | BUILD VERIFIED — `flutter build apk --release --dart-define=ENV=production` succeeds, `build/app/outputs/flutter-apk/app-release.apk` (68.9MB) |
| AAB | BUILD VERIFIED — `flutter build appbundle --release --dart-define=ENV=production` succeeds, `build/app/outputs/bundle/release/app-release.aab` (68.3MB) |
| Package ID | `com.sriainfotech.career_buddy_lms` — consistent across `build.gradle.kts` and the built artifact |
| Permissions | `RECORD_AUDIO`, `CAMERA` (+ optional `<uses-feature>`), `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE` (maxSdk 28), `ACCESS_NETWORK_STATE`, `WAKE_LOCK` (the latter three brought in automatically by dependencies, not hand-declared) — all justified by real features in this app, no unnecessary permission found. **`INTERNET` was missing from every prior release build — found and fixed this batch, re-verified present in a fresh build via `aapt2 dump permissions` on the actual artifact** (see FIXED THIS BATCH below) |
| Release configuration | `minSdkVersion=24`, `targetSdkVersion=36`, `compileSdkVersion=36` (all Flutter-tooling defaults, no override) — no ProGuard/R8 rules file exists and `minifyEnabled`/`shrinkResources` are not set (Gradle default: off for the `release` build type unless explicitly enabled) — not a defect, just an unmade optimization choice, left as-is per this batch's "don't change values just because they could theoretically be improved" rule |

## IOS

| Check | Status |
|---|---|
| iOS build | BUILD VERIFIED — `flutter build ios --no-codesign --dart-define=ENV=production` succeeds, `build/ios/iphoneos/Runner.app` (28.7MB). **APP STORE SIGNING NOT VERIFIED** — no code-signing identity/provisioning profile/Apple Developer Team is configured in this environment, and none was added (would require the owner's real Apple Developer account) |
| Bundle ID | `com.sriainfotech.careerBuddyLms` |
| Deployment target | `15.0` (fixed in Batch 10 for the installed Xcode 27 toolchain; re-confirmed unchanged and still building successfully) |
| Permissions | `NSMicrophoneUsageDescription`, `NSCameraUsageDescription`, `NSSpeechRecognitionUsageDescription` — all present, real descriptions, all justified by real features, no extras |
| Signing | `CODE_SIGN_STYLE = Automatic`, `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"`, no `DEVELOPMENT_TEAM` set — standard "never connected to a real Apple Developer account yet" state, not modified this batch (would need the owner's own Team ID/certificates) |

## SECURITY

Full release-oriented sweep of `lib/` and native configuration, re-run
this batch (no new findings beyond what Batches 10-12 already
established, reported here for completeness, not duplicated as "new"):
```text
SAFE — no hardcoded API keys/passwords/tokens/private keys anywhere in
       Flutter source (re-confirmed).
SAFE — no print()/debugPrint() calls anywhere in lib/ (re-confirmed).
SAFE — no certificate-verification bypass (no badCertificateCallback /
       custom SecurityContext) anywhere (re-confirmed).
SAFE — no verbose network logging (no LogInterceptor) (re-confirmed).
SAFE — no insecure HTTP production endpoint — Environment.production is
       https://, verified both by direct test assertion and by
       confirming the literal host string is compiled into the release
       binary (Batch 12).
SAFE — no debug-only authentication bypass reachable in a release build
       (Direct Demo Entry's kDebugMode gate — compile-time eliminated).
FOUND & FIXED — Android release builds had no INTERNET permission at
       all (see FIXED THIS BATCH). Not a "secret" but a genuine,
       severe, previously-undetected functional/release defect —
       reported here since it was found during this batch's
       security/release sweep.
```
No secret value is reproduced anywhere in this document.

## FIXED THIS BATCH

1. **`android.permission.INTERNET` missing from every prior release
   build.** Confirmed via `aapt2 dump permissions` on the actual
   previously-built `app-release.apk` (not source inspection alone —
   Gradle's build success never proved this permission was present,
   since a missing runtime permission doesn't fail compilation). The
   permission existed only in Flutter's own auto-generated `src/debug/`
   and `src/profile/` manifest overlays (added there for the VM
   service/hot-reload), never in `src/main/AndroidManifest.xml`. This
   meant every Android release artifact produced in Batches 9 through
   13 would have had **zero network access at runtime** — every single
   feature that talks to the backend would have silently failed on a
   real device. Fixed by adding the permission to the main manifest;
   re-verified present in a freshly rebuilt APK via the same `aapt2`
   command.
2. **Android launcher label was `career_buddy_lms`** (the raw package
   name), not a real app name — would show literally as
   "career_buddy_lms" under the home-screen icon. Fixed to `"Career
   Buddy"`, matching this app's own consistent in-app branding
   (`MaterialApp`'s `title: 'Career Buddy'`, the login screen) — direct
   evidence, not an invented value. Re-confirmed in the rebuilt APK via
   `aapt2 dump badging` (`application-label:'Career Buddy'`).
3. **iOS `CFBundleDisplayName` was `"Career Buddy Lms"`** — fixed to
   `"Career Buddy"` for the same reason; re-confirmed present in the
   rebuilt `.app`'s `Info.plist` via `PlistBuddy`.

Nothing else was changed. Signing configuration, versioning, the app
icon, and the native splash background were all deliberately left
untouched — see PRIVACY/DATA and FINAL OWNER CHECKLIST for why each of
those needs the project owner, not further engineering.

## PRIVACY / DATA

**CONFIRMED FROM CODE** (what the app actually does, per direct source
read — not a legal or compliance conclusion):
- **Session cookies**: Django session-cookie authentication
  (`sessionid`, `csrftoken`), persisted on-device via a filesystem-
  backed cookie jar, cleared on logout.
- **Camera**: used only for the AI Mock Interview's live camera-liveness
  check (a self-attestation, not a face-verification analysis — see
  Batch 9's own documented scope).
- **Microphone**: used for AI Speaking/Writing/Listening/Reading
  exercises, JAM, Roleplay, Group Discussion, the Timer exercise type,
  and Mock Interview — all recording spoken answers for real,
  server-side scoring/transcription.
- **On-device speech recognition**: used by the Timer exercise type and
  Group Discussion to capture spoken input as text locally.
- **Document upload**: Resume Parsing/ATS accepts a real PDF/DOCX resume
  file, uploaded to the backend for analysis.
- **AI interactions**: ARIA chat messages, resume/ATS analysis text,
  and mock-interview answers are sent to the backend, which in turn
  calls a third-party AI provider (Sarvam, server-side only — the
  Flutter app never talks to it directly) for some of this processing.
- **WebSocket communication**: Group Discussion's live conversation
  (topic text, the user's spoken-then-transcribed turns) travels over
  a session-authenticated WebSocket to the backend.
- **Certificates/files**: certification PDFs and resume-template
  downloads are fetched from the backend and stored locally on-device
  before being opened.
- **Third-party packages with plausible data-handling implications**:
  `camera`, `speech_to_text`, `flutter_tts`, `record`, `webview_flutter`,
  `video_player`, `file_picker`, `image_picker`, `web_socket_channel`,
  `google_fonts` (fetches font files), `flutter_secure_storage`. All are
  well-known, widely-used Flutter plugins; whether any of them make
  their own independent network calls or collect telemetry beyond what
  this app's own code directs is a question of each package's own
  published privacy documentation, not something confirmable purely by
  reading this app's source.

**REQUIRES OWNER/LEGAL CONFIRMATION** (not concluded here):
- Whether this data-collection profile requires a Google Play "Data
  Safety" declaration of a specific type, and what that declaration's
  exact wording should be.
- Whether Apple's App Store "Privacy Nutrition Label" categories/purposes
  need to be filled out a specific way for this app.
- Whether any additional consent flow (e.g., explicit data-processing
  consent beyond the OS-level camera/mic/speech permission prompts) is
  legally required for this app's markets.
- Whether the third-party AI provider's own data-handling terms
  (server-side, not this app's concern directly, but relevant to the
  overall privacy policy) need to be reflected in the privacy policy.
- Account/data deletion process and requirements (neither store's
  specific requirement was evaluated here — this is a policy question,
  not a code question).

This batch makes no claim of compliance with Google Play or Apple App
Store policies — only an inventory of what the code actually does.

## STORE READINESS

```text
READY               — App builds (APK/AAB/iOS), app name matches real
                       branding, permissions are all justified and
                       accurately described, production backend is
                       verified and correctly configured.
MISSING              — App icon (still Flutter's default template icon;
                       no real Career Buddy logo asset exists anywhere
                       in this repo to regenerate one from — confirmed
                       by searching `assets/` and the in-app branding,
                       which is text-only).
MISSING              — Privacy policy (confirmed absent both in this
                       repo and live on the production site itself —
                       /privacy/, /privacy-policy/, and /terms/ all
                       return a real 404 on https://careerbuddy4u.com).
MISSING              — Store listing copy: app description, short
                       description, screenshots, feature graphic,
                       category, content rating questionnaire answers.
MISSING              — Support/contact information for the store
                       listing (no support email found anywhere in this
                       repo).
MISSING              — Data Safety (Play) / Privacy Nutrition Label
                       (App Store) declarations — see PRIVACY/DATA above.
OWNER ACTION REQUIRED — Android release signing (currently signed with
                       the debug key — not usable for real distribution;
                       needs the owner's real upload keystore, never
                       generated by this batch).
OWNER ACTION REQUIRED — iOS code signing (no Apple Developer Team
                       configured; needs the owner's own account/
                       certificates/provisioning profile).
OWNER ACTION REQUIRED — Real test credentials for the still-open live
                       production authentication verification (Batch 13,
                       unchanged).
```

No store metadata, legal URL, or compliance claim was fabricated
anywhere in this document or the codebase.

## LIVE PRODUCTION AUTH

**NOT VERIFIED — no real student/employer credentials were available.**
Unchanged from Batch 13; this batch did not re-attempt or weaken that
finding, and did not guess/brute-force/fabricate a login.

## BUILD RESULTS

```text
flutter analyze                                              → No issues found.
flutter test                                                  → 1544/1544 passing
flutter build apk --release --dart-define=ENV=production      → SUCCESS
                                                                  build/app/outputs/flutter-apk/app-release.apk (68.9MB)
flutter build appbundle --release --dart-define=ENV=production → SUCCESS
                                                                  build/app/outputs/bundle/release/app-release.aab (68.3MB)
flutter build ios --no-codesign --dart-define=ENV=production  → SUCCESS
                                                                  build/ios/iphoneos/Runner.app (28.7MB)
```

All three were built (and the Android ones re-verified via `aapt2`)
**after** this batch's manifest/Info.plist fixes, not before — the
results above reflect the fixed state, not the pre-fix state.

## DJANGO

```text
Django changes:    NONE
Database changes:  NONE
Migrations:        NONE
API changes:       NONE
```

`git status --short` in `Career_Buddy_LMS/` shows only the same
pre-existing baseline diff present since Batch 6, independently
re-confirmed via unchanged file modification timestamps (Sep 21-22,
over a week predating this batch's work).

## FINAL OWNER CHECKLIST

Only genuine, real remaining actions — every one of these requires a
decision, asset, credential, or account that only the project/business
owner holds; none of them is an engineering task this session can
complete by writing more code:

1. **Provide a real signing/upload keystore for Android** and update
   `android/app/build.gradle.kts`'s release `signingConfig` to use it
   (currently signed with the debug key, not usable for real
   distribution).
2. **Set up an Apple Developer Team** for this project (add
   `DEVELOPMENT_TEAM` in Xcode, provisioning profile / App Store
   Connect app record) to enable real iOS code signing and TestFlight/
   App Store submission.
3. **Provide a real Career Buddy app icon/logo image** so the launcher
   icons (currently Flutter's unmodified default) can be regenerated
   from it.
4. **Write and publish a real privacy policy** (and, if desired, terms
   of service) — currently absent from both this repo and the live
   site. Required by both stores, especially given this app's real
   camera/microphone/speech-recognition/document-upload capabilities.
5. **Complete each store's Data Safety / Privacy Nutrition Label
   declaration**, using the CONFIRMED FROM CODE inventory above as a
   starting point, with legal/compliance sign-off on the exact wording.
6. **Write store listing copy** (description, short description,
   screenshots, feature graphic, category, content rating
   questionnaire, support contact email).
7. **Provide one real student test account** (and, if employer-flow
   verification is also wanted, one real employer test account) so the
   still-open live-authentication smoke test (Batch 13) can finally be
   completed.
8. **Confirm the version number** (`1.0.0+1`) is acceptable for the
   first submission — reviewed this batch and judged correct as-is (no
   prior published version exists anywhere), but final confirmation is
   the owner's call, not an engineering decision.

Everything else audited this batch — release configuration, Android/
iOS build correctness, the network-permission defect, security, and
the full regression/build matrix — is resolved and does not require
another engineering batch to revisit.
