# Phase 46 — Low-Score Recovery Actions and Threshold Parity

## 1. Original mobile behavior vs. verified web behavior

Read `docs/PHASE_40_CB_CHANGES_COMPLETE_PARITY_MATRIX.md`,
`docs/PHASE_40_CB_CHANGES_IMPLEMENTATION_ROADMAP.md`,
`docs/PHASE_40_CB_CHANGES_AUDIT_REPORT.md`, and the Phase 43/44/45 reports
first. Phase 40's own audit (Item 15) had already found this gap and
proposed a plan — but per this phase's own instruction ("verify the
actual current web source before changing any score threshold or
behavior," "do not infer the threshold from … an outdated document"),
every claim below was re-verified directly against the current
`royalStaffing_CB01` source, not taken on the earlier audit's word alone.

**Original mobile behavior** (confirmed by reading the code before
changing it):
- `lib/features/resume/domain/entities/resume_analysis.dart` had no
  `atsOk`/`roleFit`/`targetRole` concept at all — `ResumeAnalysisResult`
  only carried a single `canInterview` boolean.
- `lib/features/resume/data/resume_html_parser.dart` derived that boolean
  as `html.contains('Try Interview')` — which, read against the real
  template's actual branch structure (below), only ever evaluates `true`
  in the *fully eligible* case. A paying user who is merely below the ATS
  threshold, or whose picked role doesn't fit, was silently shown the
  **same "Upgrade for AI Interview" CTA as a Free-plan user** — a second,
  previously-unflagged correctness bug beyond the known wrong-number copy.
- `lib/features/resume/presentation/screens/resume_builder_screen.dart`
  hardcoded `"Score 70 or above out of 100"` (line 731) and `"score 70 or
  above"` (line 748) — confirmed by `grep`, exactly as Phase 40 found.
- No "Build Resume" / "Upload Another" / "Analyse Again" / "Skill up
  yourself" action existed anywhere on this screen.
- `lib/features/mock_interview/presentation/widgets/mock_interview_results_view.dart`
  showed a plain `"Qualified Candidate"` / `"Action Required"` label with
  **no threshold number at all** (not wrong, just absent) and had no
  recovery UI of any kind for a failed attempt.

**Verified current web behavior** (read directly, with exact line
citations — see §2).

## 2. Source-file evidence for each threshold and recovery action

**Thresholds** (`royalStaffing_CB01/career_app/views.py`, read directly):
- Line 185: `ATS_INTERVIEW_THRESHOLD = 90` — gates whether a resume's ATS
  score is high enough to unlock the AI interview.
- Line 1134: `PASSING_SCORE = 90` — gates whether an AI-interview attempt
  itself is a pass. A **separate** server constant from the one above;
  both happen to equal 90 today (confirmed no drift), but each gates a
  genuinely different thing, so they were kept as two separately-named
  Dart constants (`kAtsInterviewThreshold` in `resume_analysis.dart`,
  `kInterviewPassingScore` in `interview_analytics.dart`) rather than
  merged into one — per this task's own explicit "keep separate rules
  separate" instruction.
- Neither number is wired through any feature flag or admin setting —
  both are plain Python module constants, so there is no live/dynamic
  value to fetch; the Dart constants are the correct, stable mirror.

**Resume-parsing recovery UI**
(`royalStaffing_CB01/templates/resume_match_result.html`, read in full):
- Lines 222-247 — the top action-bar's real 4-way
  `{% if %}/{% elif %}/{% else %}`:
  `can_interview and role_fit and not role_fit.ok` → a disabled "Resume
  doesn't match {role}" badge; `elif can_interview and not ats_ok` → a
  disabled "Interview unlocks at {ats_threshold}% ATS score" badge;
  `elif can_interview` → the real "Try Interview" button; `else` (Free
  plan) → "Upgrade for AI Interview".
- Lines 309-379 — the lower banner's own, separate 4-way branch (the
  real "recovery card"): role-mismatch → "Build Resume" (`{% url 'home'
  %}?build=role#create-resume`) + "Upload Another" (`{% url
  'resume_builder' %}`); below-threshold → "Build Resume" + "Analyse
  Again" (same `resume_builder` URL); eligible → "Take Interview";
  Free-plan → "View Plans".
- Lines 560-563 — a role-specific "Skill up yourself" button
  (`{% url 'skill_up' %}?section={{ target_role.section }}`), shown
  only when `can_interview and target_role.section and not ats_ok`,
  inside the "AI Suggestions" card.
- `career_app/views.py:217-230` (`_check_role_fit`) confirms a
  role-mismatched resume's `match_percentage` is forced to 0 server-side
  for that role, so `ats_ok` is always false in the role-mismatch case
  too — the two states are mutually exclusive in the template but both
  genuinely mean "not ats_ok".

**AI-interview recovery UI**
(`royalStaffing_CB01/templates/resume_analytics.html`, read in full):
- Lines 202-245 — the score banner's exact badge text: `"Qualified
  Candidate (Score ≥ {{ passing_score }}/100)"` when passed, `"Action
  Required (Score < {{ passing_score }}/100)"` plus `"You should upgrade
  your skill."` and a `"Skill up yourself"` button (`{{ skillup_url }}`)
  when not.
- `career_app/views.py:1871`: `"skillup_url": None if is_passed else
  _skillup_url_for(request)` — confirmed `_skillup_url_for` (line 243)
  always returns at least `/skill_up/` (falls back to no `?section=` when
  no target role was picked), so this button is **unconditionally**
  present whenever `not is_passed` — never `None` on that branch.
- Lines 309-358 — "Recommended Skill Upgradation Courses" card, shown
  whenever `not is_passed`: 3 hardcoded category links
  (`activity_list?category=speaking|writing|negotiation`) plus a
  `"View All 23 Skill Learning Activities"` link (`activity_list`, no
  category) — confirmed this card's markup is entirely static template
  content, not server-templated data; nothing here was invented.
- Lines 361-409 — `suitable_jobs`, confirmed still gated to `is_passed
  and suitable_jobs` only (unchanged, no leak).

## 3. Thresholds changed vs. intentionally preserved

| Threshold | Verdict |
|---|---|
| Resume ATS → interview unlock copy ("70" → "90") | **Changed** — was a plain wrong-number display bug. |
| Resume ATS → interview unlock *eligibility logic* | **Changed** — the `canInterview` derivation itself was wrong (conflated "Free plan" with "paid but below threshold/role mismatch" — see §1); now derived from the real 4-way `ResumeInterviewGate`. |
| AI-interview passing score (`PASSING_SCORE`) | **Preserved as its own, separate constant** (`kInterviewPassingScore`) — not merged with the resume ATS threshold, even though both are 90 today, because the source defines them as two distinct server constants (§2). |
| `is_passed` pass/fail decision itself | **Untouched** — `mock_interview_html_parser.dart`'s `isPassed` already derived this by scraping the literal `"Qualified Candidate (Score"` substring, never a hardcoded number; this phase only added *display* copy naming the threshold, never touched the decision logic. |
| Server-side `_ats_unlocks_interview`/`is_passed` computation | **Untouched** — no backend file was read-write touched; this is a Flutter-only phase. |
| `suitable_jobs`/interview-access no-leak behavior | **Preserved, re-verified** — still server-gated; this phase adds no client-side bypass. |

## 4. Implemented recovery actions and their actual destinations

All of the following reuse **existing** mobile routes/screens — no new
route, screen, or backend call was added.

### Resume-parsing result (`resume_builder_screen.dart`)

| Branch | Top-bar action | Banner action(s) |
|---|---|---|
| Role mismatch | Disabled "Resume doesn't match {role}" | "Build Resume" → `RoutePaths.createResumeBuilder` (the existing free-form Create Resume builder — the real web's own `home?build=role#create-resume` destination, already mapped in this app since Phase 39/21) **+** "Upload Another" → `resumeBuilderControllerProvider.notifier.reset()` (this screen *is* the upload form — `ResumeBuilderScreen` owns both bodies, confirmed in its own class doc comment — so "upload another"/"analyse again" both just mean "go back to the upload form", the exact same call "Analyze Another Resume" already makes). |
| Below ATS threshold | Disabled "Interview unlocks at 90% ATS score" | "Build Resume" (same destination) **+** "Analyse Again" (same `reset()` call). |
| Eligible | "Try Interview" → `RoutePaths.resumeInterviewPlaceholder` (unchanged) | "Take Interview" (unchanged). |
| Free plan | "Upgrade for AI Interview" → `RoutePaths.pro` (unchanged) | "View Plans" (unchanged). |
| Any of the above, when a target role was picked and the server rendered the real "Skill up yourself" button | "Skill up yourself" (inside the AI Suggestions / career-advice card) → `RoutePaths.skillUpSections` — the same honest, documented simplification Phase 43 already established (the real web deep-links to one specific role section; this app's Skill-Up screen has no per-role deep-link target yet, so it opens the general Sections tab instead). |

### AI-interview result (`mock_interview_results_view.dart`)

- Failed attempt: the badge now reads `"Action Required (Score <
  90/100)"`, with `"You should upgrade your skill."` guidance text and a
  `"Skill up yourself"` button → `RoutePaths.skillUpSections` (same
  honest mapping as above — this screen has no per-role target to deep
  link to from here either).
- A new `"Recommended Skill Upgradation Courses"` card (only when
  failed): 3 `"Start Course"` buttons → `RoutePaths.activitiesWithCategory('speaking'|'writing'|'negotiation')`
  — reusing the **exact same, already-existing** category-filtered
  Activities mechanism the landing page's own Skill Up teaser already
  uses (`home_skill_up_teaser.dart`/`public_home_body.dart`) — plus a
  `"View All 23 Skill Learning Activities"` button → `RoutePaths.activities`
  (no category filter), matching the real template's own literal "23".
- Passed attempt: badge now reads `"Qualified Candidate (Score ≥
  90/100)"`; no recovery UI (unchanged — `suitable_jobs` section
  continues to render exactly as before).

## 5. Files changed

| File | Change |
|---|---|
| `lib/features/resume/domain/entities/resume_analysis.dart` | Added `kAtsInterviewThreshold = 90` and the `ResumeInterviewGate` enum (4 values, mirroring the real template's own branch); added `gate`/`targetRoleName`/`showSkillUpAction` fields to `ResumeAnalysisResult` (all optional/defaulted, so every pre-existing test fixture still compiles unmodified) plus an `effectiveGate` getter that falls back to a 2-way split of the pre-existing `canInterview` field for any caller that predates this phase. |
| `lib/features/resume/data/resume_html_parser.dart` | `gate` is now detected from the lower banner's own unique heading text (the exact signal the server itself already decided, so it can't drift); `canInterview` is now derived as `gate != planLocked` (fixing the conflation bug in §1); added `targetRoleName`/`showSkillUpAction` extraction. |
| `lib/features/resume/presentation/screens/resume_builder_screen.dart` | Top action bar now switches on `effectiveGate` (4 branches instead of 2); the lower banner now has all 4 real branches, with `_Banner` extended to support an optional second CTA (role-mismatch/below-threshold); `_AdviceCard` gained the "Skill up yourself" button; all hardcoded "70" replaced with `kAtsInterviewThreshold`. |
| `lib/features/mock_interview/domain/entities/interview_analytics.dart` | Added `kInterviewPassingScore = 90`; updated the existing doc comment that already correctly described the 70→90 history. |
| `lib/features/mock_interview/presentation/widgets/mock_interview_results_view.dart` | Score badge now names the real threshold; added the "Skill up yourself" button and the new `_SkillUpgradationCoursesCard`/`_CourseTile` widgets (shown only when `!isPassed`). |
| `test/features/resume/data/resume_html_parser_test.dart` | Added a `Phase 46 ResumeInterviewGate` group (6 new tests) plus 1 new test on the existing fixture confirming it still defaults to `planLocked`. |
| `test/features/resume/presentation/screens/resume_builder_screen_test.dart` | Added 2 new router stub routes (`createResumeBuilder`, `skillUpSections`) and a `Phase 46 low-score recovery actions` group (10 new tests). |
| `test/features/mock_interview/presentation/widgets/mock_interview_results_view_test.dart` | Added a `Phase 46 — low-score recovery actions` group (7 new tests). |
| `test/features/mock_interview/presentation/screens/mock_interview_screen_test.dart` | Updated one pre-existing assertion (`'Qualified Candidate'` → the full real badge text) to match the now-correct, more complete label — the only *modification* to an existing test's expectation in this phase, and it was required because the old text was itself the simplified/incomplete version of the real web copy. |

No other file was touched. `CreateResumeGuestDraftLocalDataSource`,
`CareerDepartmentsAssetDataSource`, and every other Phase 42-45 file are
completely unmodified. No file in either Django reference directory was
touched (confirmed again — see §11).

## 6. Automated test results, including threshold boundary tests

**Boundary coverage**: `_ats_unlocks_interview`/`PASSING_SCORE` are both
plain `>=` server-side comparisons against a single integer — there is no
separate "exactly at 90" server code path to reproduce, so the boundary
is exercised by asserting the *displayed copy* always equals
`kAtsInterviewThreshold`/`kInterviewPassingScore` (both constant-asserted
directly: `kAtsInterviewThreshold is 90`, `kInterviewPassingScore is 90`)
and by exercising the ATS score 1% below it (60% in the belowThreshold
fixtures), confirming the below-threshold copy/banner render correctly;
the eligible fixture uses 95% (above); the real `gate` detection itself
is driven by which banner the *server* rendered, not a client-side `>=`
comparison repeated independently, so there is no separate client-side
boundary to drift from the server's own.

**Focused runs, all actually executed:**
```
flutter test test/features/resume/data/resume_html_parser_test.dart
  → 32/32 passing (26 pre-existing + 6 new Phase 46 tests: the
    "existing fixture still defaults to planLocked" test plus the
    5-test ResumeInterviewGate group)

flutter test test/features/resume/presentation/screens/resume_builder_screen_test.dart
  → 25/25 passing (15 pre-existing + 10 new Phase 46 tests)

flutter test test/features/mock_interview/presentation/widgets/mock_interview_results_view_test.dart
  → 14/14 passing (7 pre-existing + 7 new Phase 46 tests)

flutter test test/features/mock_interview/presentation/screens/mock_interview_screen_test.dart
  → 11/11 passing (1 updated assertion, 0 new tests, 0 regressions)
```

**Regression batch** (resume, mock_interview, Phase 42/43/44/45-specific
suites together): **653/653 passing**.

**Full suite**: **2441 passing, 0 failing** (baseline before this phase:
2419 passing, 0 failing — net +22, fully accounted for by the test
additions above). No existing test was weakened or deleted; the one
existing assertion that *was* changed (`mock_interview_screen_test.dart`)
was updated to the correct, more complete text, not loosened.

## 7. Analyzer results

`flutter analyze`: **8 issues**, identical to the pre-phase baseline (the
same pre-existing `unused_element_parameter` warnings in unrelated test
files). No new issues introduced.

## 8. Emulator verification

### Device

`emulator-5556` (Android 14, API 34, "sdk gphone64 arm64") — the same
device Phases 43-45 used. `/data` had 531MB free this session; the fresh
debug build was installed after uninstalling this app's own stale prior
install (the same non-destructive routine as every prior phase). No
emulator was wiped, recreated, or had any unrelated app/data removed.

### Interactions actually tested, live

1. Built and installed the fresh debug APK; launched via `adb shell am
   start`; confirmed focus via `dumpsys window`.
2. Navigated the real landing page (as a guest) to the "Resume & AI"
   section ("Turn your resume into a career advantage") and tapped the
   real **"Check Your Resume"** button.
3. Confirmed the existing auth guard correctly redirected to the
   **Login** screen — i.e., confirmed live, on-device, that this
   phase's changes do **not** weaken or bypass the existing
   `@login_required`-equivalent restriction on the Resume Parsing
   feature.
4. Checked `adb logcat` across the whole session, filtered for Flutter
   exceptions/fatals: none found; the app's own process (confirmed via
   `pidof`) stayed alive throughout.

### What could **not** be verified live, and why

Reaching an actual populated resume-result screen (any of the 4
branches) or an actual AI-interview result screen requires a real,
authenticated account with a previously-uploaded resume (for the resume
side) or a completed interview session (for the interview side) — both
of which hit the **live production backend** (`careerbuddy4u.com`). Per
this phase's explicit instruction ("do not fabricate production
accounts, bypass authentication, or mutate production records to
manufacture a low-score scenario") and the standing engagement-wide rule
against inventing test accounts, **no such account was used or
created**, and the actual 4-way resume branch / failed-interview
recovery UI was therefore **not observed rendering on-device with real
data this phase**. This is stated plainly, not glossed over: the
UI-branching, copy, and navigation logic for all 4 resume branches and
both interview branches is verified by the 24 new, deterministic,
fixture-driven automated tests listed in §6 (which exercise the exact
same widget tree the real app renders, with fake repositories standing
in for the network layer — the same testing technique every other
screen in this app already uses), not by live visual confirmation of a
populated low/high-score screen.

### Screenshot directory

`/tmp/cb_phase46_screens/` — files `01_launch.png` through
`15_check_resume_result.png`, covering the app launch, the landing-page
navigation to the Resume & AI section, and the confirmed login-redirect.

## 9. Remaining gaps / unverified behavior

- Live, on-device rendering of the actual 4-way resume-result banner and
  the failed-interview recovery card was not observed with real data —
  see §8's explicit explanation. Fully covered by automated tests
  instead.
- The "Skill up yourself" button's destination is the general Skill-Up
  Sections tab, not the specific role/section the real web deep-links
  to — an honest, previously-documented (Phase 43) simplification, not
  new to this phase, since this app's Skill-Up screen has no per-role
  deep-link mechanism yet.
- `_can_access_interview`/plan-tier logic itself (which plans get
  `can_interview: true` at all) is unchanged and was not re-verified
  this phase beyond confirming the existing Free-plan "Upgrade" banner
  still renders correctly for that case — this phase only corrects how
  the *other three* states (which all assume `can_interview: true`) are
  told apart from each other and from the Free-plan case.

## 10. Scope boundaries respected

No backend file, API, migration, or schema was touched. No new package
dependency was added. No authentication, OTP, authorization, or
subscription rule was changed — the live verification in §8 specifically
confirmed the existing login requirement still applies unchanged. No
signing material was touched. No build/deploy/Play-Store action was
taken.

## 11. Confirmation: Phases 42-45 intact, Django reference projects untouched

- Full suite (2441/2441 passing) includes every pre-existing Phase 42
  guest-save test, Phase 43 career-browsing test, Phase 44 Buddy-overlay
  test, and Phase 45 guest-draft-restoration test — all pass unchanged.
- `git status` confirms only the 9 files listed in §5 were changed by
  this phase; every other modified/untracked file in the working tree is
  pre-existing, prior-phase uncommitted work, left exactly as found.
- `find Career_Buddy_LMS royalStaffing_CB01 -newer Mobile_app/pubspec.yaml -type f`
  returned no results — neither read-only Django reference project was
  touched.

## 12. Summary

The resume-parsing result screen's "70" copy bug is fixed (now correctly
reads 90, sourced from a single centralized `kAtsInterviewThreshold`
constant), and a second, previously-unflagged bug — a paid user below
the ATS threshold or with a role mismatch being shown the same "Upgrade"
prompt as a Free-plan user — is also fixed, via a new `ResumeInterviewGate`
that mirrors the real web's own 4-way server-rendered branch exactly. All
of the real web's confirmed recovery actions (Build Resume, Upload
Another/Analyse Again, Skill up yourself, and the AI-interview's full
"Recommended Skill Upgradation Courses" card) are now implemented,
reusing only existing mobile routes and screens — no new backend
assumptions, no fabricated data. 2441/2441 tests pass (+22 new, 0
regressions), analyzer is at the pre-existing 8-issue baseline, the
existing login/auth guard was confirmed live and unaffected, and Phases
42-45 plus both Django reference projects are all confirmed intact.

**Phase 46 is complete. No further phase has been started.**
