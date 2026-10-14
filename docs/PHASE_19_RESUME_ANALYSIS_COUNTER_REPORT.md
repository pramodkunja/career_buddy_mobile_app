# Phase 19 — Free Resume-Analysis Remaining Counter Report

**Scope:** Flutter-only implementation of the proactive "N of M resume
analyses left" counter identified as a small, client-only gap in the
Phase 18 audit. No Django file was modified in either tree; no backend
logic, endpoint, or subscription rule was touched.

## 1. What changed

**`lib/features/resume/`:**
- `domain/repositories/resume_repository.dart` — added a
  `typedef ResumeParseQuota = ({int left, int limit})` (same lightweight-
  record pattern as Phase 16's `McqSubmitEcho`) and a new abstract method,
  `Future<ResumeParseQuota?> getParseQuota()`, documented as best-effort —
  never a `Result`/`Failed`, since a missing count is a normal outcome for
  most users, not an error.
- `data/resume_html_parser.dart` — new function `parseResumeParsesLeft(html)`.
- `data/resume_remote_datasource.dart` — new method `getParseQuota()`: a
  dedicated `GET resumeBuilderHome`, deliberately **not** reusing
  `_ensureCsrfCookie()` (left completely unchanged), wrapped in a broad
  `catch` so any failure (network error, unexpected shape) returns `null`
  rather than throwing.
- `data/resume_repository_impl.dart` — thin pass-through `getParseQuota()`.
- `presentation/controllers/resume_builder_controller.dart` — `ResumeIdle`
  and `ResumeUploading` both gained a nullable `parseQuota` field; a new
  `loadParseQuota()` method fetches it and updates whichever of those two
  states is current (a `ResumeResultState` already showing is left alone);
  `uploadAndAnalyze`/`reanalyze` now carry the quota they had across the
  upload-in-flight → success/failure transition, so a failed upload doesn't
  silently drop an already-loaded count; `reset()` clears it deliberately
  (see §2).
- `presentation/screens/resume_builder_screen.dart` — `_UploadForm` now
  takes a `parseQuota` field; `_UploadFormState.initState()` fires
  `loadParseQuota()` once; a new `_ParseQuotaBadge` widget renders the
  count, shown only when non-null.

**Pre-existing fake repositories updated for the new interface method**
(no behavior change intended, just compile-correctness): `test/app/client_flow_test.dart`,
`test/features/auth/auth_controller_test.dart`,
`test/features/resume/presentation/controllers/resume_builder_controller_test.dart`,
`test/features/resume/presentation/screens/resume_builder_screen_test.dart`,
`test/features/resume/presentation/screens/resume_history_screen_test.dart`.

**New test file:** `test/features/resume/data/resume_remote_datasource_test.dart`
(no datasource-level test file existed for this feature before).

## 2. How the counter is parsed and displayed

- **Source of truth**: `resume_builder_home`'s own page
  (`templates/resume_builder.html:191-195`, verified directly against the
  updated Django source before writing the parser): `<i class="fas
  fa-file-lines"></i> Free plan: {{ parses_left }} of {{ parse_limit }}
  resume analyses left`. `parseResumeParsesLeft` matches exactly that
  text, extracts both integers, and rejects (returns `null` for) any
  value the server could never actually send — negative `left`,
  non-positive `limit`, or `left > limit` — rather than ever displaying
  something nonsensical.
- **Fetch timing**: `getParseQuota()` fires once per mount of the upload
  form's `State`, from `initState()`. Because `ResumeIdle`↔`ResumeUploading`
  render the *same* `_UploadForm` element (no new `key`, so Flutter
  preserves the existing `State` across that toggle), `initState` does
  **not** re-fire merely from submitting an upload or showing/hiding the
  loading overlay — it only fires again when `_UploadForm` is freshly
  (re)created, which happens exactly once more: after `reset()` ("Analyze
  Another Resume") removes `_ResultView` from the tree and a brand-new
  `_UploadForm` mounts in its place. This is what keeps the displayed
  count from going stale after a completed analysis, with no polling, no
  duplicate requests, and no extra plumbing beyond the controller method
  itself.
- **Display**: a compact, full-width banner (`_ParseQuotaBadge`,
  styling matching this screen's existing `_ErrorBox`/feature-card
  conventions) rendered directly under the hero, above the upload card —
  shown *only* when `parseQuota != null`. There is no separate
  loading/error rendering for this widget: absence of the badge covers
  "still loading," "paid plan," and "fetch failed" uniformly, matching the
  web's own all-or-nothing `{% if parses_left is not None %}` gate.

## 3. Paid-plan, missing-data, and request-failure behavior

- **Paid plan**: the server omits the badge from the page entirely
  (confirmed server-side logic, Phase 18), so `parseResumeParsesLeft`
  returns `null` and no counter renders — no plan-detection logic exists
  or is needed anywhere in this Flutter code.
- **Missing/unparseable data**: any HTML that doesn't contain the exact
  badge text (a different page, a redesigned template, a malformed
  fragment) returns `null` from the regex match alone — never throws.
- **Request failure**: `getParseQuota()`'s datasource implementation
  catches any exception (network error, non-2xx status that still has no
  badge in its body, etc.) and returns `null`. This never surfaces as an
  error message, never touches `ResumeIdle.errorMessage` (reserved for
  real upload/analysis failures), and never blocks or delays the rest of
  the upload screen.

## 4. Tests executed and results

**New tests added (18 total):**
- `test/features/resume/data/resume_html_parser_test.dart` — 5 new tests:
  a valid badge parses exactly; the badge's total absence (paid-plan-style
  page) returns `null`; malformed/unrelated HTML returns `null` without
  throwing; out-of-range values (negative, non-positive limit, `left >
  limit`) are rejected; the at-limit case (`0 of 4`) still parses
  correctly (not treated as "missing").
- `test/features/resume/data/resume_remote_datasource_test.dart` (new
  file) — 4 tests: hits the real `resumeBuilderHome` endpoint via GET;
  fires independently of any CSRF-cookie state; a 500/error-body response
  safely yields `null`; a genuine request exception is caught and yields
  `null`, never propagating.
- `test/features/resume/presentation/controllers/resume_builder_controller_test.dart`
  — 4 new tests: a valid quota is carried into `ResumeIdle`; a `null`
  quota leaves the counter hidden with no error surfaced; a prior quota
  survives a failed upload (not silently dropped); `reset()` clears the
  quota (the next mount re-fetches it fresh).
- `test/features/resume/presentation/screens/resume_builder_screen_test.dart`
  — 5 new tests: the counter renders once the fetch resolves; it stays
  hidden when the quota is unavailable; it does not appear while the fetch
  is deliberately held in flight (via a `Completer`, for a deterministic,
  non-racy assertion) and appears the instant it resolves; it refreshes to
  a new, lower count after "Analyze Another Resume" returns to a fresh
  upload form.

**Commands and results:**
```
flutter test test/features/resume/   → 57 passed, 0 failed
flutter test                          → 1969 passed, 0 failed (full suite; 1951 prior + 18 new)
```

**A real bug found and fixed during this phase's own testing** (not
present in the final code): the first version of `_ParseQuotaBadge` used
a `Row` with `mainAxisSize: MainAxisSize.min` inside an `Align`, which
overflowed horizontally at a 400px-wide test viewport because the long
badge text had no way to wrap or shrink. Fixed by switching to a
full-width `Container` with the text in an `Expanded`, matching this
screen's existing `_ErrorBox` pattern — confirmed by rerunning every
affected test (including the full-width responsive-overflow test already
in this file) with zero failures afterward.

## 5. `flutter analyze` result

```
flutter analyze
No issues found! (ran in 1.8s)
```
Run both scoped to `lib/features/resume/` during development and
whole-project at the end — clean both times.

## 6. Remaining limitations / unverified behavior

- **Source verification** (this phase): the exact badge markup
  (`resume_builder.html:184-198`) was read directly from the updated
  Django source before writing the parser — not assumed from the Phase 18
  report alone.
- **Automated testing** (this phase): all behavior described in §2-§4 is
  covered by the 18 new tests plus the full, unmodified pre-existing
  suite (zero regressions).
- **Not performed this phase**: no live device, emulator, or running
  backend instance was used. No manual UI interaction was performed and
  none is claimed. The one genuinely "live-shaped" fact this phase relies
  on — that `resume_builder_home` really renders this exact badge text in
  production — was verified by reading the template source, not by an
  actual HTTP round-trip against a running server.
- **A pre-existing, out-of-scope observation carried over from Phase 18,
  not touched here**: the free-analysis-limit's own server-side TOCTOU
  race (an unsynchronized check-then-create in `resume_job_match`) is a
  backend concern, unrelated to and unaffected by this client-only change.

---

Phase 19 is complete. Stopping here per instruction — awaiting explicit
approval before beginning Phase 20 or any other phase.
