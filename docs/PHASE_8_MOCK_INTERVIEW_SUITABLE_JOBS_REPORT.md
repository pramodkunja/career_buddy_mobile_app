# Phase 8 — Mock Interview: Parse and Display Suitable Jobs

Flutter-only change. Django/web repository was not modified (read-only
throughout, per standing instructions).

## 1. Original finding and fresh verification

The finding carried over from Phase 2/5 was: Mock Interview's results page
(`resume_analytics`) unlocks a `suitable_jobs` job-recommendation list on a
passing score, but the mobile app never parsed or displayed it —
`mock_interview_html_parser.dart`'s own doc comment stated this was
deliberate, citing "no Job Detail screen to route it to yet."

Before making any change, this was re-verified against current source, not
assumed:

- `grep -rn "suitable_jobs\|suitableJobs" lib/` returned only the two
  comment-only references in `mock_interview_html_parser.dart` and
  `interview_analytics.dart` — no actual field or parsing logic existed.
  **The gap was still open.**
- The stated reason ("no Job Detail screen to route it to yet") was
  **confirmed stale**: Phase 4 built and wired `PublicJobDetailScreen` /
  `RoutePaths.publicJobDetail(id)` for Dashboard's own recommended jobs,
  using the exact same `job.pk`-in-href scraping technique this row would
  need. The comment had not been updated after Phase 4 shipped.

Conclusion: the underlying functional gap was real and still open; only the
stated *reason* for leaving it unaddressed was wrong. Proceeded to
implement.

## 2. Verified web behavior (read directly from Django source)

- **View**: `career_app/views.py`'s `resume_analytics` (`@login_required`).
  On a completed session, if `is_passed` (`total_integer_score >= 70`), it
  calls `_get_matched_jobs(matching_skills, years_experience=years_exp,
  max_results=_job_recommendation_limit(request.user))` and passes the
  result as `suitable_jobs` in the template context.
- **Data source**: `_get_matched_jobs` (`career_app/views.py:39+`) queries
  `JobPosting.objects.filter(status='active').select_related('employer')`,
  filters by an experience-level band derived from `years_experience`, then
  ranks by skill overlap against `matching_skills`, capped at
  `max_results`. **This is the identical `JobPosting` query and ranking
  logic** `activities/views.py`'s dashboard recommendations use — confirmed
  by reading both call sites.
- **Template**: `templates/resume_analytics.html:350-409`. The whole card is
  gated by `{% if is_passed and suitable_jobs %}` — "not passed" and
  "passed with zero matches" are **indistinguishable in the rendered HTML**
  (both render as the section being entirely absent). This is the web's own
  legitimate empty-state behavior, not a parsing defect to special-case
  around.
- Per-job fields rendered: `title`, `employer.company_name`,
  `get_skills_list|slice:":3"`, `location`, `get_job_type_display`,
  `get_experience_display`, `salary_display` (computed server-side via
  `get_salary_display_for_user`), and a `View & Apply` link —
  `<a href="{% url 'employer_portal:job_detail' job.pk %}" ... target="_blank">`.
- **Confirmed markup differences from Dashboard's near-identical card**
  (`dashboard.html:96-151`) that meant Dashboard's parser regexes could not
  be reused unmodified:
  - Job-card div: `class="job-card border rounded-3 p-3 h-100"` — Dashboard's
    equivalent adds `overflow-hidden`.
  - Skill badge: `class="badge bg-light text-dark border"` — Dashboard's
    equivalent adds `text-truncate`.
  - The `job.pk` link markup is **byte-for-byte identical** to Dashboard's —
    confirmed, not assumed, satisfying the task's explicit instruction not
    to assume the same routing contract without checking.

## 3. Flutter data flow — before and after

Traced in full before writing any code:
`MockInterviewRemoteDataSource.getAnalytics()` → `parseInterviewAnalyticsHtml`
(`mock_interview_html_parser.dart`) → `InterviewAnalyticsResult`
(`interview_analytics.dart`) → `MockInterviewRepositoryImpl.getAnalytics()`
(pure pass-through) → `MockInterviewController`'s `MockInterviewResults`
state → `MockInterviewScreen` → `MockInterviewResultsView`.

**Before**: the parser never looked at the job-recommendation markup;
`InterviewAnalyticsResult` had no field for it; the results view only
rendered the score summary and per-question breakdown.

**After**: `parseInterviewAnalyticsHtml` additionally calls a new
`_parseSuitableJobs(html)` and populates a new
`InterviewAnalyticsResult.suitableJobs` field. No other layer in the chain
needed a code change — the repository, controller, and screen's `switch`
wiring are all pure pass-through of the whole `InterviewAnalyticsResult`
object, so the new field reaches the results view automatically.
`MockInterviewResultsView` was extended to render it.

**No duplicate model or second data-fetching path was introduced**: the
existing `RecommendedJob` entity (`lib/features/dashboard/domain/entities/`)
is reused directly, justified by §2's confirmation that both features'
`suitable_jobs`/`recommended_jobs` come from the same query and the same
per-job template fields.

## 4. Files changed, and why

- `lib/features/mock_interview/domain/entities/interview_analytics.dart` —
  added `final List<RecommendedJob> suitableJobs` (default `const []`) to
  `InterviewAnalyticsResult`; corrected its doc comment (previously claimed
  the field was "deliberately not modeled").
- `lib/features/mock_interview/data/datasources/mock_interview_html_parser.dart` —
  added `_parseSuitableJobs` (adapted from, not copy-pasted from, Dashboard's
  `_parseRecommendedJobs`, with the two corrected regexes from §2) and a
  local `_splitByMarker` helper (duplicated rather than shared across
  features, matching this codebase's established per-feature convention);
  wired its result into `parseInterviewAnalyticsHtml`'s return; corrected the
  stale "no Job Detail screen" doc comment.
- `lib/features/mock_interview/presentation/widgets/mock_interview_results_view.dart` —
  added a `_SuitableJobsSection`/`_SuitableJobCard` widget pair (new, small,
  Mock-Interview-scoped — Dashboard's `_JobCard` etc. are private to that
  file and were not made public or imported cross-feature), rendered only
  when `analytics.suitableJobs` is non-empty; "View & Apply" routes to
  `RoutePaths.publicJobDetail(job.id!)` via `context.push`, disabled when
  `job.id == null`.
- `test/features/mock_interview/data/mock_interview_remote_datasource_test.dart` —
  extended the `_analyticsHtml` fixture with a real job-card slice and added
  4 new tests under `getAnalytics`.
- `test/features/mock_interview/presentation/widgets/mock_interview_results_view_test.dart`
  (new file) — 7 widget tests for the new section.
- `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` — updated the Mock Interview
  results/job-recommendations row from Missing to Fully equivalent
  (source/test-verified).

No Django file, no auth/password-reset/profile/subscription/employer code,
no GD/JAM language-selection code, no Demo Mode, and no
face-detection/typed-answer proctoring code was touched.

## 5. Before/after behavior for each data scenario

- **Valid multi-job response**: parses every job, in document order, with
  all 7 fields and a correct `job.pk`-derived id.
- **Field mapping**: title, company, skills (first 3), location, job type,
  experience level, and salary display all map 1:1 from the corresponding
  card markup.
- **Missing optional sub-fields on one job** (e.g. a dropped skill badge or
  location span): that job still parses, with the missing field defaulting
  to an empty string/list — never a crash, never a guessed value.
- **Missing `suitable_jobs` section entirely** (web's own `{% if %}` being
  false — not passed, or passed with zero matches): `suitableJobs` parses as
  `[]`. The results view renders no section at all — correctly
  indistinguishable from the web's own behavior, not an error state.
- **Explicit empty collection**: same as above — `[]` in, no section
  rendered.
- **Malformed/drifted job-card markup** (e.g. the title `<h6>`'s class
  changes): that job is silently skipped, never fabricated — confirmed via
  a dedicated regression test.
- **A job card whose link markup has drifted**: every other real field
  still parses; `id` is `null`; the UI disables "View & Apply" rather than
  navigating anywhere fabricated.
- **Unrelated sections of the same page** (score summary, question
  breakdown): still parse correctly after this change — covered both by the
  existing (unmodified) assertions in the same test and by a new explicit
  regression test.

## 6. Tests added and run

11 new tests, all passing:

- `mock_interview_remote_datasource_test.dart` (`getAnalytics` group, +4):
  valid multi-field/job parse (extended the existing "parses the summary
  numbers…" test); missing section parses as empty, with unrelated fields
  unaffected; drifted job link still parses with `id: null`; multiple jobs
  parse in order; malformed markup produces no fabricated job.
- `mock_interview_results_view_test.dart` (new file, 7 tests): no section
  when empty; header/years-experience/matched-count text; first-3-skills
  slicing; real navigation via `GoRouter` to `PublicJobDetailScreen` using
  the scraped id; disabled button (no navigation) when `id` is `null`;
  existing question-breakdown rendering still intact alongside the new
  section; no-overflow at 320/375/430px with long field values.

```
flutter test test/features/mock_interview/ test/features/dashboard/
...
00:02 +112: All tests passed!
```

## 7. `flutter analyze` and full suite

```
flutter analyze
Analyzing Mobile_app...
No issues found! (ran in 2.6s)

flutter test
...
00:47 +1921: All tests passed!
```

1921 passing, against the Phase 7 baseline of 1910 — **+11**, matching
exactly the 11 new tests added this phase. No regressions.

## 8. Remaining uncertainties / what would need live-device verification

- This phase is **source- and test-verified only**. No live device or
  emulator run was performed, and no real request was made to production
  `resume_analytics`. The parser's regexes are anchored to the exact
  template markup read in `templates/resume_analytics.html:350-409`
  (confirmed on 2026-10-12), but a live-device pass against a real passing
  interview session's rendered page would be the only way to fully confirm
  against production template drift, locale/number formatting, and the
  plan-based `max_results` limiting behavior.
- `_job_recommendation_limit(request.user)` (Normal vs Pro result count) was
  read but not independently re-verified against live account data — the
  parser itself is agnostic to the count (it parses however many cards are
  present), so this does not affect correctness, only end-to-end
  confirmation.

## 9. Django and pre-existing work

No file under `Career_Buddy_LMS/Career_Buddy_LMS/` (Django/web repo) was
read for anything but reference, and none was modified. All work from
Phases 2–7 was left untouched — confirmed by `flutter analyze`/`flutter
test` showing zero regressions outside this phase's own new tests.

## 10. Build/deploy

No build, deploy, signing, or upload step was run or touched. Only source
and test files were edited.

---

Stopping here per the task's explicit instruction. Awaiting approval before
starting any further phase.
