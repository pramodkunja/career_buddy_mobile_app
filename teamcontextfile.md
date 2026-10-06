# Career Buddy LMS — Mobile App: Team Context

**Date:** 2026-09-21
**Flutter version:** 3.44.8 (stable channel)
**Dart version:** 3.12.2

## Location

- Flutter app: `Career_Buddy_LMS/Mobile_app/` (this project's root).
- Django backend: `Career_Buddy_LMS/Career_Buddy_LMS/` — this is now the
  **one true backend tree**. A separate `CAREER BUDDY LMS/` top-level
  folder (with a further-along, uncommitted "Phase D" mobile-API branch)
  existed earlier but was intentionally deleted by the user; don't go
  looking for it or its `profile/api/` endpoint — they no longer exist.
- The Django dev server runs via `python manage.py runserver 0.0.0.0:8000`
  from that backend tree (Daphne/ASGI under the hood). Reach it from the
  Android emulator at `http://10.0.2.2:8000/`, or `http://127.0.0.1:8000/`
  from the host machine — `EnvironmentConfig.baseUrl` already picks the
  right one per platform.

## Architecture decisions

- **Feature-first, layered structure** (`app/`, `core/`, `shared/`,
  `features/<name>/{data,domain,presentation}`) — see `ARCHITECTURE.md` for
  the full rationale and the "adding a new feature" checklist.
- **Riverpod** (`flutter_riverpod` 3.x, `Notifier`/`NotifierProvider`) for
  state management, chosen per the project brief over GetX/Bloc.
- **Dio + cookie_jar + dio_cookie_manager** for networking, because the
  backend authenticates via Django session cookies today, not a token API
  (verified against `users/views.py`, `users/forms.py`). `ApiClient` is
  built once (async, needs a directory for the persisted cookie jar) in
  `main()` and injected via `ProviderScope` overrides.
- **go_router** for declarative routing with an auth guard
  (`app/router/route_guards.dart`), pinned below 18.x to match this
  Flutter/Dart SDK's compatibility.
- **google_fonts** (Outfit + Newsreader) and a hand-mirrored color palette
  in `app/theme/` — copied from the web app's `static/css/style.css`
  `:root` tokens rather than guessed.
- Deliberately **not** added yet (would be premature): `riverpod_annotation`/
  codegen, `json_annotation`, `equatable`, `cached_network_image`,
  `connectivity_plus`. None of the current screens need them; Dio's own
  connection-error type already covers "no network" without a second
  package.

## Dependencies added

`flutter_riverpod`, `dio`, `go_router`, `flutter_secure_storage`,
`cookie_jar`, `dio_cookie_manager`, `path_provider`, `google_fonts`. See
each one's comment in `pubspec.yaml` for why it's there.

## Current implementation status

- Flutter project created (`com.sriainfotech.career_buddy_lms`), targeting
  Android + iOS.
- Theme/design system, error-handling foundation (`AppException` →
  `Failure` mapping), API client foundation, and core reusable widgets
  (`AppButton`, `AppTextField`, `AppLoader`, `AppErrorView`, `AppSnackbar`)
  are in place.
- Auth feature: session-cookie login/logout wired to the **real, verified**
  backend contract (not a stub) — `POST /users/login/`, `POST
  /users/logout/` (note the `/users/` prefix — `users.urls` is mounted
  there in `business_english_lms/urls.py`, confirmed against the live
  server) — with an `AuthController` exposing `AuthUnknown`/
  `AuthAuthenticated`/`AuthRefreshing`/`AuthUnauthenticated` states, and a
  login screen mirroring `templates/users/login.html` (username-or-email +
  password only; register/employer-portal links are placeholders — those
  screens don't exist yet). Verified end-to-end against the live server:
  CSRF handshake, invalid-credentials path (200 + real error text), and
  logout (302) all confirmed by replicating the exact request Dio sends.
  Never verified with a real successful login — no test/demo credentials
  exist anywhere in the repo, and none were invented.
- Splash screen + `go_router` guard: unknown → splash, no session → login,
  session → dashboard.
- Dashboard feature (`features/dashboard/`): full typed
  model/repository/`AsyncNotifier`/screen stack, built against a
  **documented but not-yet-implemented** backend contract
  (`docs/BACKEND_CONTRACT_dashboard.md`) — the web dashboard
  (`activities/views.py` `dashboard()`) is 100% server-rendered HTML with
  no JSON API behind it. Hitting `GET /dashboard/api/` today correctly
  404s and the screen shows a real, retryable error state — nothing is
  faked. Mirrors the web dashboard's sections (stats, activity progress,
  recent results, recommended jobs, payment history) 1:1, including
  matching empty-state copy and each section's conditional-visibility
  rules. Session-expiry on this screen reuses `AuthController.logout()`
  (no separate auth path). Responsive via a single `isTablet()` breakpoint
  (700px) — stats grid and section layout adapt; nothing more elaborate
  was needed.
- Test suite (38 tests, all passing): validators, exception mapping, route
  guard redirect logic, `AuthController`/`DashboardController` state
  transitions (against fake repositories), dashboard JSON parsing
  (valid/missing-optional/malformed), the datasource's Dio-level error
  mapping (via a fake `HttpClientAdapter`, `test/support/`), and widget
  tests for `AppButton` and the dashboard screen/section widgets.
- `flutter analyze`: no issues. `flutter test`: all passing.
- Verified on a real device: ran on the `Pixel_9a` Android emulator
  (API 37) twice — first confirming the login screen renders correctly
  (no cached session), then again after the dashboard work to confirm the
  app still boots and runs cleanly with the new code compiled in. Could
  not visually observe the dashboard screen itself on-device (no valid
  login credentials to get past the login screen — see above); its
  loading/success/error rendering is instead verified by the widget test
  suite. iOS not verified — no iOS Simulator runtime is installed on this
  machine (`flutter doctor` flags it); Xcode itself is present.
- **Riverpod gotcha worth knowing:** `AsyncNotifierProvider` auto-retries a
  failed `build()` with backoff by default (`AsyncLoading(..., retrying)`).
  `dashboardControllerProvider` explicitly disables this
  (`retry: (retryCount, error) => null`) so a failure surfaces immediately
  as a real error the user's own Retry button controls, rather than a
  spinner that silently retries in the background. This also matters for
  widget tests: a bare `tester.pump()` loop won't advance the real
  `Future.delayed` backoff timer, so a test can look "stuck loading"
  forever if a provider still has retry enabled.

## Known issues / gaps

- **Dashboard shows real data for no one yet** — `docs/BACKEND_CONTRACT_dashboard.md`
  documents the proposed `GET /dashboard/api/` endpoint; nothing has been
  implemented on the Django side. Until it exists, the dashboard screen
  will always show a 404 error state (honest, not a bug).
- **No successful login has ever been observed** — no test/demo credentials
  exist anywhere in the repo. The login request/CSRF/error paths are
  verified against the live server, but the "valid credentials → dashboard"
  path has never actually run. Supply credentials to close this gap.
- iOS Simulator runtime isn't installed, so iOS was never run, only
  compiled against (Xcode toolchain is otherwise fine per `flutter doctor`).
- Register and Employer Portal Sign In buttons on the login screen are
  inert placeholders (`onPressed: () {}`) — those screens don't exist yet.
- `EnvironmentConfig.baseUrl` only has a `dev` value
  (`http://127.0.0.1:8000`, or `10.0.2.2` on the Android emulator); staging
  and production hosts are unconfirmed and will throw `UnsupportedError` if
  selected.
- No `--platforms=web,macos,linux,windows` support was requested or added
  (task scope was Android + iOS only).
- The Android emulator (`Pixel_9a`) used for manual verification runs low
  on storage (seen at both ~350MB and ~774MB free across sessions) — debug
  APK installs have failed on this before. If it happens again, don't wipe
  the emulator without asking first.

## Next recommended task

Either (a) get `docs/BACKEND_CONTRACT_dashboard.md`'s endpoint implemented
on the Django side (it's designed to be a thin JSON mirror of `dashboard()`'s
existing queries — no new business logic) and then wire/verify it
end-to-end, or (b) get real login credentials to finally verify the
successful-login → dashboard-request path on a live device.
