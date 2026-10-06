# career_buddy_lms

The Flutter mobile client for Career Buddy LMS.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the folder structure, state
management, networking, theming, and how to add a new feature.

## Release Builds

**A release build must explicitly pass `--dart-define=ENV=production`.**
Every backend destination in this app (the API, Group Discussion's
WebSocket, Skill-Up's WebView, resume/certificate downloads) resolves
through `EnvironmentConfig.baseUrl` (`lib/app/config/environment.dart`),
which defaults to `Environment.dev` — a local Django dev server address —
whenever `ENV` isn't set. This default is intentional and must keep
working with no flag for ordinary development; it means a release build
run without the flag below would compile and install successfully while
silently pointing at a local dev address instead of the real backend.

```bash
# Android
flutter build apk --release --dart-define=ENV=production
flutter build appbundle --release --dart-define=ENV=production

# iOS
flutter build ios --release --dart-define=ENV=production
```

`Environment.production` resolves to the real, positively-verified
Career Buddy LMS backend (`https://careerbuddy4u.com` — see
`docs/BATCH_12_PRODUCTION_RELEASE.md` for the full verification
evidence). `Environment.staging` has no confirmed host yet and will
throw a clear, actionable error if selected — do not pass
`--dart-define=ENV=staging` until a real staging host is verified and
filled into `EnvironmentConfig`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
