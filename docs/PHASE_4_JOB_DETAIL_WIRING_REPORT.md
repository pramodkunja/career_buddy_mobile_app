# Phase 4 — Job Detail Navigation Fix

Scope: the Dashboard recommended-job card's "View & Apply" navigation gap
identified in `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` and
`docs/PHASE_2_PARITY_AUDIT_REPORT.md`. Read first:
`docs/PRE_UPDATE_BASELINE_REPORT.md`, `docs/PREVIEW_AND_STATIC_DATA_AUDIT.md`,
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md`,
`docs/PHASE_2_PARITY_AUDIT_REPORT.md`, `docs/PHASE_3_CRITICAL_FIXES_REPORT.md`.
Git status confirmed unchanged from Phase 3's end state in both
repositories before any edit (Django: same 3 modified / 3 untracked files
present since Phase 1; Mobile_app: same files Phase 3 left behind).

## 1. Root cause — re-confirmed from current source, not assumed

Per instruction, the Phase 2 finding was re-verified fresh rather than
trusted:

- `templates/dashboard.html:142-144` (Django, read-only): each
  recommended-job card's "View & Apply" link is
  `<a href="{% url 'employer_portal:job_detail' job.pk %}" ...>`, which
  resolves to `/employer/jobs/<pk>/` — re-confirmed by re-reading
  `employer_portal/urls.py:9` (`path('jobs/<int:pk>/', ..., name='job_detail')`)
  and `business_english_lms/urls.py:50` (`employer_portal.urls` mounted at
  `/employer/`). The `pk` is a real, stable integer — present in the HTML,
  just never displayed as visible text.
- `lib/features/dashboard/domain/entities/recommended_job.dart`: still had
  no `id` field at all.
- `lib/features/dashboard/data/dashboard_html_parser.dart`'s
  `_parseRecommendedJobs`: still extracted title/company/skills/location/
  jobType/experience/salary but never looked at the card's `<a href="...">`
  tag.
- `lib/features/dashboard/presentation/widgets/recommended_jobs_section.dart`'s
  `_JobCard`: still had `onPressed: () => context.push(RoutePaths.jobDetail)`
  unconditionally — `RoutePaths.jobDetail` maps to a `ComingSoonScreen`
  placeholder.
- `lib/features/employer/presentation/screens/public_job_detail_screen.dart`:
  re-confirmed still a complete, real screen — real `GET` (parses the job),
  real `POST` (submits an application with resume upload, CSRF, field-error
  parsing, duplicate-application detection) — registered at
  `RoutePaths.publicJobDetailPattern` (`/jobs/:id`) in `app_router.dart`,
  with its own existing test coverage
  (`public_job_detail_html_parser_test.dart`,
  `public_job_detail_remote_datasource_test.dart`,
  `public_job_detail_screen_test.dart`).
- `ApiEndpoints.publicJobDetail(int id) => '/employer/jobs/$id/'`
  (`api_endpoints.dart`) — re-confirmed to be the exact same URL the
  dashboard's card links to.

**The defect was still present and exactly as previously described**: a
real, stable id exists in the scraped HTML and a complete, working
job-detail-and-apply screen already exists in the app — they were simply
never connected. This was a Flutter-only wiring gap, not a backend
dependency, confirmed again from current source before any change was
made.

## 2. The fix

Smallest change that connects the existing pieces, following this file's
own established convention (`_parseActivities`'s own href→id extraction,
same file) rather than inventing a new technique:

- **`lib/features/dashboard/domain/entities/recommended_job.dart`**:
  added `final int? id;` (optional — a card whose link markup doesn't
  match still gets every other real field, just no id).
- **`lib/features/dashboard/data/dashboard_html_parser.dart`**:
  `_parseRecommendedJobs` now matches the card's own
  `<a href="..." class="btn btn-primary btn-sm w-100 rounded-3 fw-bold"`
  tag (the exact classes from `dashboard.html:143`, tolerant of the
  template's own line-wrapped whitespace between attributes) and extracts
  the first numeric id from the href — the identical pattern
  `_parseActivities` already uses for its own id extraction, immediately
  above this function in the same file. A non-matching link or missing
  numeric id yields `id: null`, never a guessed or fabricated value.
- **`lib/features/dashboard/presentation/widgets/recommended_jobs_section.dart`**:
  `_JobCard`'s "View & Apply" button now pushes
  `RoutePaths.publicJobDetail(job.id!)` — the real, existing route — when
  `job.id != null`, and is **disabled** (`onPressed: null`, using
  `AppButton`'s own existing disabled-state handling) when it's `null`.
  No new UI state, no fallback navigation, no invalid URL is ever
  constructed.
- **`lib/app/router/route_paths.dart`** and **`lib/app/router/app_router.dart`**:
  corrected the two doc comments that described `RoutePaths.jobDetail` as
  necessary because "no Job Detail screen exists" and "the dashboard API's
  job objects carry no id" — both claims are now simply false, so the
  comments were corrected rather than left actively misleading.
  `RoutePaths.jobDetail`/its `ComingSoonScreen` registration were **left
  in place**, unused, as a harmless fallback — deleting them was judged
  outside this phase's "strictly limited to fixing that navigation path"
  scope, and the task's own instruction was to avoid unnecessary changes.

No Django file was touched. No new backend call, no new dependency, no
fabricated job id or detail data anywhere in the fix.

## 3. How a job id flows from HTML to navigation

1. `DashboardRemoteDataSource.getDashboard()` fetches the real, live
   `/dashboard/` HTML (unchanged this phase).
2. `dashboard_html_parser.dart`'s `_parseRecommendedJobs` splits the page
   into per-card substrings (existing `_splitByMarker` helper, unchanged),
   then for each card: extracts the `<a href="...">` tag matching the
   "View & Apply" button's exact classes, then the first run of digits
   inside that href, parsed as an `int`. Stored on `RecommendedJob.id`.
3. `RecommendedJobsSection`'s `_JobCard` reads `job.id`. If present,
   tapping "View & Apply" calls `context.push(RoutePaths.publicJobDetail(job.id!))`,
   which resolves to `/jobs/<id>`, matched by the existing
   `GoRoute(path: RoutePaths.publicJobDetailPattern, ...)` registration in
   `app_router.dart`, building `PublicJobDetailScreen(jobId: id)` — the
   same, unmodified, already-complete screen every other job-listing entry
   point in this app uses (confirmed unchanged this phase).
4. If `job.id` is `null` (the card's link markup didn't match — e.g. a
   future template change), the button is disabled and no navigation is
   attempted at all.

## 4. Regression tests added

All in existing test files, following existing conventions — no new test
file was created, no existing assertion was weakened or removed:

- **`test/features/dashboard/data/dashboard_remote_datasource_test.dart`**:
  added the real "View & Apply" link markup to the existing valid-HTML
  fixture and a new assertion (`data.recommendedJobs.single.id == 42`);
  added a new test, "a recommended-job card whose link markup has drifted
  still parses every other real field, with a null id rather than a crash
  or a guessed/fabricated one" — strips just the `<a>` tag from the
  fixture and asserts the job still parses with `id: null`.
- **`test/features/dashboard/presentation/widgets/recommended_jobs_section_test.dart`**:
  the `job()` test helper gained an optional `id` parameter. The old
  "View & Apply navigates to the Job Details placeholder" test was
  replaced with two: one confirming a tap with a real id navigates to
  `RoutePaths.publicJobDetailPattern` (not the old placeholder), and a new
  regression test confirming that with no id, the button's `onPressed` is
  `null` and tapping it reaches neither the real detail screen nor the
  unused `ComingSoonScreen` fallback.

## 5. Validation — exact commands and actual results

```
flutter analyze
```
→ **No issues found!** (run after every edit in this phase, consistently clean)

```
flutter test test/features/dashboard/data/dashboard_remote_datasource_test.dart \
             test/features/dashboard/presentation/widgets/recommended_jobs_section_test.dart
```
→ **All passed** (5 + 10 = 15 tests in the two directly affected files).

```
flutter test test/features/dashboard/
```
→ **All passed** (53 tests across the whole dashboard feature directory —
confirms nothing else in the dashboard module regressed).

```
flutter test
```
(full suite) → **1898/1898 passing**, 0 skipped, 0 failing — **2 more than
the Phase 3 baseline of 1896** (the exact net count of new regression
tests: +1 in the datasource test file, +1 net in the widget test file,
which replaced one test with two). No existing test was weakened or
removed to reach this result.

## 6. Remaining uncertainty and limitations

- **Not verified on a real device against the real backend.** This fix,
  like every prior phase's, is source-and-fake-adapter-verified only — no
  live click-through was performed, consistent with this engagement's
  standing blocker (no usable test account; see Phase 10/11). No claim of
  live-device or production verification is made.
- **`PublicJobDetailScreen` itself was not modified or re-audited** —
  Phase 4's scope was strictly the navigation wiring into it, not its own
  internal correctness, which Phase 2 already separately verified.
- **The Mock Interview job-recommendations gap** (`suitable_jobs`, a
  separate, still-`Missing` row in the parity matrix) was **not**
  addressed — it needs its own, separate parsing work in
  `mock_interview_html_parser.dart`, out of this phase's explicit scope.
  The matrix row was annotated to note that Phase 4 proved the same
  target screen/pattern is available and reachable, without claiming any
  work was done there.
- **`RoutePaths.jobDetail`/its `ComingSoonScreen` registration remain in
  the codebase, now fully unused** — left in place as a deliberate,
  conservative choice (smallest fix, no unnecessary changes), not an
  oversight.

## 7. Confirmations

- **Django source**: unchanged — `git status --short` in
  `Career_Buddy_LMS/` shows the identical 3-modified/3-untracked state
  present since Phase 1, before and after this phase.
- **Pre-existing uncommitted/untracked work**: fully preserved — this
  phase added exactly 6 modified source files + 4 modified test files to
  Mobile_app's working tree; every file Phase 3 left behind remains
  exactly as it was.
- **No secrets, keystores, or signing material** were read, printed, or
  modified — `android/key.properties` was not touched.
- **Demo Mode**: not touched — no file under `lib/core/demo/` was read or
  modified.
- **No authentication, password-reset, profile, subscription, or
  proctoring logic was changed** this phase — confirmed by the git status
  diff above showing only dashboard/routing files touched.
- **No APK/AAB was built, nothing was deployed or uploaded** to any store.
- **No live-device or production verification is claimed** anywhere in
  this report — all results above are from `flutter analyze`/`flutter test`
  against fake HTTP adapters and widget tests, run and reported exactly as
  shown.

## Status

**Fixed**, per the evidence above — not partially fixed, not blocked. The
parity matrix's Dashboard recommended-jobs row and its associated "next
step" have been updated to reflect this; the separate Mock Interview
job-recommendations row remains unaddressed and still `Missing`, as
documented above. Stopping here, as instructed — no further remediation
phase started without explicit approval.
