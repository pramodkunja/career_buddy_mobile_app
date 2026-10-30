# Phase 75 — Skill-Up WebView & Lesson Accessibility Audit

## Scope

Audits the Skill-Up learning experience's WebView lifecycle, fullscreen
behavior, lesson routing/deep links, and loading/error states, and verifies
two historical findings from Phase 51's final audit:
1. "383 Tech Center lesson pages are unreachable."
2. "Blocked — cannot confirm whether `webview_flutter`'s default config
   grants real HTML5 fullscreen."

Both are treated as historical claims to re-verify against current source
(Phases 52–74 happened since), not as established current defects.

## Files inspected

**Flutter project** (the only directory modified):
- `lib/features/skill_up/presentation/screens/skill_up_lesson_screen.dart`
  (the only `WebViewController`/`WebViewWidget` usage anywhere in the app,
  confirmed by a repo-wide grep) — read in full.
- `lib/features/skill_up/presentation/skill_up_lesson_route_args.dart`,
  `lib/features/skill_up/domain/skill_up_lesson_url.dart` — read in full.
- `lib/features/skill_up/data/skill_up_data.dart` (729 lines) — the
  hardcoded lesson catalog; counted every `SkillUpLesson(` entry (64) and
  every `relativePath:` under `TechCenter/` (29, all flat files; zero
  nested).
- `lib/app/router/route_paths.dart` / `app_router.dart` — `skillUpLesson`'s
  registration (`extra`-based `SkillUpLessonRouteArgs`, not query params).
- `pubspec.yaml` / `pubspec.lock` — confirmed `webview_flutter: 4.14.1`,
  `webview_flutter_android: 4.14.1`, `webview_flutter_platform_interface:
  2.15.1` are the exact resolved versions.
- The installed `webview_flutter_android-4.14.1` package source directly
  (`$PUB_CACHE/hosted/pub.dev/webview_flutter_android-4.14.1/lib/src/
  android_webview_controller.dart`) — not just its changelog.
- `docs/PHASE_51_FINAL_AUDIT_REPORT.md`, `..._PARITY_MATRIX.md`,
  `..._IMPLEMENTATION_ROADMAP.md` — the exact source of both historical
  claims (Item 13j/13k, lines 361-386 of the matrix).
- `lib/features/employer/presentation/widgets/employer_phone_input_field.dart`
  — the one pre-existing `Image.network(..., errorBuilder: ...)` precedent,
  used as the model for this phase's test fakes' error-handling style.

**Updated Django site** (`royalStaffing_CB01`, read-only):
- `static/001 Career Buddy/TechCenter/` — counted directly (`find`), not
  estimated: 29 flat files + 383 nested files across 10 department
  subdirectories (`business-analysis` 50, `sales-and-marketing` 50,
  `development` 49, `devops-infrastructure` 44,
  `customer-success-technical-support` 40, `product-management` 40,
  `design-ux-ui` 35, `technical-writing` 35,
  `project-management-agile-delivery` 30, `quality-assurance-qa-testing`
  10 — sums to exactly 383).
- `static/001 Career Buddy/Vocabulary/Basicindex.html` and its 10
  `phonics-0*.html` siblings — read directly; confirmed real internal
  `<a href="phonics-0N....html">` links between them.
- `static/001 Career Buddy/TechCenter/english_vocab_mock_test.html` (and its
  3 siblings `aptitude_mock_test.html`/`amcat_mock_test.html`/
  `cocubes_mock_test.html`) — grepped directly for `requestFullscreen`/
  `fullscreenchange`/`PrintScreen`, confirming all 4 implement fullscreen
  inline (not via a shared `exam_guard.js` import).
- `core/skillup_access.py` (`FREE_PREFIXES`/`FREE_FILES`) — confirmed the
  exact Free-tier allowlist: `001 CEFR/`, `Vocabulary/`,
  `GrammerActivities/`, plus the single named file
  `TechCenter/english_vocab_mock_test.html`.
- A repo-wide grep for `exam_guard` across the entire Skill-Up static tree —
  confirmed present in exactly 202 `NonITCenter/` files and 383
  `TechCenter/` files (585 total, matching Phase 51's own count).

## Current lesson-routing and WebView architecture

Every lesson is a hand-authored static HTML file, served directly by
Django's static-file handler and loaded into a plain `WebViewController` —
not re-implemented in Dart. `SkillUpLessonRouteArgs` (`title`, `url`) is
passed via `context.push(RoutePaths.skillUpLesson, extra: args)`;
`buildSkillUpLessonUrl` resolves a `relativePath` into the real, live,
unauthenticated static URL. `skill_up_data.dart` is the single source of
truth for which lessons exist in the app at all — a lesson not listed there
has no Flutter entry point, regardless of whether the underlying HTML file
exists on the server.

`SkillUpLessonScreen` already had (pre-existing, Phase 38 and earlier): a
`WebViewController` with `JavaScriptMode.unrestricted`, `enableZoom(false)`,
a `NavigationDelegate` distinguishing a main-frame load (`onPageStarted`/
`onPageFinished`), a specific 403 (`onHttpError`) treated as locked content
(`SkillUpAccessMiddleware`, forwarding this app's own session cookie so a
paid user isn't misidentified as anonymous), and a main-frame-only
`onWebResourceError` shown as a retryable error view.

## Evidence for/against the 383-page accessibility claim

**Verdict: the COUNT is still accurate, but the stated ROOT CAUSE was
wrong.**

The real static tree genuinely has 383 nested Tech Center HTML files,
confirmed by direct, reproducible counting (`find ... | wc -l`, shown above,
cross-checked by running it twice independently in this phase). None of
them have a `SkillUpLesson` entry in `skill_up_data.dart` today — confirmed
by searching the file for a nested `TechCenter/<dept>/<role>/...` path
pattern and finding zero matches, versus all 29 flat `TechCenter/*.html`
files, which do have entries.

Phase 51 attributed this to `it_departments.json` lacking a "course-path
field, unlike the Non-IT equivalent." This phase traced that file directly:
it is `assets/data/it_departments.json`, consumed by
`lib/features/resume/data/career_departments_asset_datasource.dart` — the
**Resume Builder's own "Choose Your Path" department/role catalog**, a
completely unrelated feature (confirmed by that file's own doc comment,
"Loads the real 'Choose Your Path' department/role catalogs"). Its Non-IT
sibling (`nonit_departments.json`) has no course-path field either, because
neither file is meant to carry one — this was never the mechanism behind
Skill-Up's own lesson catalog at all.

The real, correct explanation: `skill_up_data.dart` (a hand-maintained Dart
list, not a JSON asset) simply has no entries for the 383 nested files, and
no Flutter screen exists for a department → role → course browsing flow
mirroring the real site's own Tech Center structure (only
`SkillUpNonItDepartmentsScreen`/`SkillUpNonItRolesScreen` exist, and those
serve the unrelated Non-IT role catalog, not Tech Center).

**Reproducibility**: the 383 count is reproducible by anyone with the
repository: `find "static/001 Career Buddy/TechCenter" -mindepth 2 -iname
'*.html' | wc -l` against the read-only Django reference.

**Scope decision**: closing this gap fully would require (a) a new data
manifest enumerating department → role → course → relative-path for all 383
files (none exists in Flutter today — this is not a one-line fix, since no
such structured mapping currently exists anywhere in this repository, Dart
or JSON), and (b) 2-3 new browsing screens plus new routes mirroring the
real site's own Tech Center navigation depth. This is a genuine, confirmed,
large feature build — not a targeted fix within an "audit + targeted fixes"
phase, and the task brief explicitly excludes "an unrelated redesign or
refactor." It is documented here, not implemented, and recommended as its
own future phase (see Implementation Report's "Remaining gaps").

## Fullscreen and back-navigation findings

**Fullscreen — verdict: the "blocked" uncertainty is resolved by the
currently-pinned package version itself, not by any code this app writes.**
Reading `webview_flutter_android-4.14.1`'s own source
(`android_webview_controller.dart:1193-1248`) directly: `AndroidWebViewWidget
.build()` calls `_trySetDefaultOnShowCustomWidgetCallbacks(context)` on
every build, which — **only if the app has not already registered its own**
`setCustomWidgetCallbacks` — automatically wires a default handler that
pushes a fullscreen `MaterialPageRoute` showing the native custom view on
`onShowCustomWidget`, and pops it on `onHideCustomWidget`. Confirmed
`skill_up_lesson_screen.dart` never calls `setCustomWidgetCallbacks` itself,
so this default remains active. This capability was added to the package in
`3.10.0` ("Adds support for playing video in fullscreen"); whether Phase 51
simply didn't discover this existing default, or an earlier pinned version
lacked it, was not resolvable from source history alone — what matters for
this phase is that the **currently pinned, currently shipped** version
already has it.

This is a source-level finding, not a live confirmation that the real
lesson pages' `requestFullscreen()` calls visually fullscreen correctly on a
real device — that remains genuinely untestable without an authenticated
account, since every lesson using fullscreen (the 4 mock-test pages, and the
585 `exam_guard.js`-bearing pages) sits behind a login-gated route (Skill Up
hub items are not in `RoutePaths.publicRoutes`/`universalRoutes`,
confirmed in `app_nav_drawer.dart`'s own doc comment and re-verified live
this phase — see "Blocked checks" below). No authorized test account exists
to reach any of them. **No code change was made for fullscreen** — there is
no confirmed defect to fix; the existing package default is correct and
sufficient as currently used.

**Back navigation — verdict: a real, reproducible, now-fixed gap.** Before
this phase, Android back always popped `SkillUpLessonScreen` entirely,
regardless of the `WebView`'s own internal navigation history. This is
demonstrated with REAL, already-reachable content, not a hypothetical: the
real `Vocabulary/Basicindex.html` ("Vocabulary Hub", already a Flutter
lesson entry) contains genuine `<a href="phonics-0N-....html">` links to all
10 phonics lessons (also already individual Flutter lesson entries,
confirmed by reading the file directly). A user who opens "Vocabulary Hub,"
taps one of its own internal links, then presses Android back, was taken
straight out of the lesson screen entirely — never back to "Vocabulary Hub"
— unlike any real browser tab or the web's own in-page navigation. Fixed
this phase (see Implementation Report).

## Confirmed issues, severity, and evidence

| # | Issue | Severity | Evidence |
|---|---|---|---|
| 1 | Android back ignores WebView-internal navigation history | Medium — a real, reproducible navigation trap for multi-page lesson hubs (confirmed: at least Vocabulary/Basicindex.html + its 10 phonics children) | Direct source reading of `skill_up_lesson_screen.dart` (no `PopScope`/`canGoBack` check existed) + the real HTML's own internal links |
| 2 | Phase 51's 383-count root cause was misattributed to an unrelated JSON file | Low (documentation correction only — no behavior was ever actually gated by that file) | Direct reading of `career_departments_asset_datasource.dart`'s own doc comment and `it_departments.json`'s real consumer |
| 3 | 383 Tech Center nested lesson pages remain unreachable from Flutter | Confirmed, real, but scoped out as a large feature build, not a targeted fix | Reproducible file count (above) vs. `skill_up_data.dart`'s own entries |

Nothing else audited (loading indicator, 403-locked view, main-frame vs.
sub-resource error handling, JavaScript enablement, zoom-disable, cookie
forwarding, retry) showed a defect — all were already correct, pre-existing
behavior, now covered by this phase's own first-ever test suite for this
screen (see Implementation Report).

## Blocked checks and unresolved source-vs-production discrepancies

- **Authenticated lesson access and live fullscreen behavior**: blocked.
  Every lesson screen (free or paid content alike) is reached only through
  the Skill Up hub, which requires a non-guest session — confirmed by
  source (`app_nav_drawer.dart`'s own doc comment: none of the Skill Up
  routes are in `publicRoutes`/`universalRoutes`) and re-confirmed live this
  phase on the emulator: a guest tapping "English Learning" is correctly
  bounced to the Job Seeker login screen (`docs/audit_evidence/phase75/
  04_guest_skillup_login_redirect.png`). No authorized test account exists,
  so live fullscreen and live back-navigation-through-real-lesson-content
  could not be confirmed on-device — only via source reading and this
  phase's own widget-test suite built from real template markup.
- **Whether any OTHER lesson pages besides Vocabulary's phonics series have
  internal links creating meaningful WebView history** was not exhaustively
  sampled across all reachable lessons (a repo-wide grep found internal
  `.html`-to-`.html` links in 12 files total, including 4
  `AptitudeReasoning/Questions/*.html` files linking only back to an
  `index.html` anchor, and the `HP/`-folder files, which are not currently
  reachable from Flutter at all and so are out of this phase's scope). The
  fix itself (checking `canGoBack()` unconditionally) is general — it
  correctly handles any current or future lesson with internal links, not
  just the one confirmed case.
- **Whether `webview_flutter_android`'s default fullscreen behavior was
  ALSO present in whatever version was pinned at the time of Phase 51's
  original audit** is unresolved and does not materially matter: the
  currently pinned version (this app's actual shipped behavior) has it.
