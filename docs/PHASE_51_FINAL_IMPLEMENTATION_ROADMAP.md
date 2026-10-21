# Phase 51 — Final Implementation Roadmap

Derived directly from `PHASE_51_FINAL_PARITY_MATRIX.md`'s findings. This is
a prioritized list of remaining work only — **no item below has been
started**; Phase 51 was audit-only. Effort is scope size (small/medium/
large), not a time estimate; no completion dates are given.

---

## P0 — Must fix

### P0-1. Non-IT job posting may be unsubmittable (Item 5)

- **Source evidence**: `Mobile_app/lib/features/employer/presentation/screens/post_new_job_screen.dart`'s `_localRequiredErrors()` (lines 383-419) unconditionally requires `work_environment`, `interview_mode`, and `notice_period`, but their input widgets are correctly hidden for Non-IT (`_isNonIt`/`_isNonItNonTech` gates at lines 601, 609, 621) and are never populated by `_onCategoryChanged` (lines 270-279). Real web source (`royalStaffing_CB01/jobs_app/job_form.html:301,315`, `forms.py:508,844-877`) confirms these fields are genuinely IT-only (or IT+Technical-only for notice period) and that Django's own `clean()` backfills safe defaults server-side — a gap the client-side check doesn't know about.
- **Affected Flutter files**: `lib/features/employer/presentation/screens/post_new_job_screen.dart` (the validation method and the 3 field-visibility conditions it should mirror).
- **Dependencies**: none — this is a self-contained client-side logic fix, no backend change needed.
- **Estimated scope**: Small (gate 3 existing checks behind the same 3 booleans the widgets themselves already use).
- **Verification method**: (1) a new widget test asserting a full, valid Non-IT submission succeeds with no validation errors, mirroring the existing IT-only submission test; (2) a live device/emulator pass with a legitimate employer test account, creating one new Non-IT job posting end to end, once such an account is available.
- **Risk if unaddressed**: High — if confirmed live, this would mean Non-IT employers (half of the entire IT/Non-IT split Item 5 exists to serve) cannot post new jobs through the mobile app at all, a core-workflow failure, not a cosmetic gap.

### P0-2. Duplicate/mislabeled `job_type` dropdown for Non-IT (Item 5)

- **Source evidence**: `post_new_job_screen.dart:734-760` renders `job_type` (IT's choice list: full_time/part_time/contract/internship/remote) unconditionally, directly above the correctly-separate, correctly-gated `employment_type` dropdown (`_isNonIt`-only, line 751). The real web shows only one such field per category (`job_form.html:301-317`, `nonit-hide` class on the IT-only one).
- **Affected files**: same screen, same section.
- **Dependencies**: none.
- **Estimated scope**: Small (add the missing `if (_isIt)` gate already used by the 3 sibling fields in P0-1).
- **Verification method**: widget test asserting the `job_type` dropdown is absent when category is Non-IT; visual confirmation on device once available.
- **Risk if unaddressed**: Moderate — doesn't block submission (the server discards the stray field for Non-IT), but is a confusing, visibly-wrong UI a Non-IT employer sees on every posting attempt.

---

## P1 — High priority

### P1-1. Technical/Non-Technical career-browsing destinations are not distinct (Item 7)

- **Source evidence**: `royalStaffing_CB01/activities/views.py:112-125` (`CAREER_TRACKS`, `career_path()`) and `templates/landing.html:6746-6753,8061-8063` confirm `career_path('technical')`/`'non-technical')` render genuinely different, non-overlapping department lists (the other panel's `<div>` doesn't exist in the DOM at all, and the population JS `return`s early for the absent panel). `Mobile_app/lib/features/resume/data/career_departments_asset_datasource.dart`'s `load(String track)` resolves any non-`'it'` value to the same combined `_loadNonIt()` call.
- **Affected files**: `lib/features/resume/data/career_departments_asset_datasource.dart` (add a category filter parameter), `lib/features/resume/presentation/screens/career_departments_screen.dart` (accept and apply it), `lib/features/home/presentation/widgets/home_path_picker_popup.dart` (give the 2 step-2 cards distinct callbacks instead of a shared `onNonIt`).
- **Dependencies**: none — the `CareerDepartment.category` (`'tech'`/`'nt'`) field already carries the data needed; no new backend endpoint or asset required.
- **Estimated scope**: Small–Medium.
- **Verification method**: widget tests asserting a `'technical'`-filtered load returns only the 15 tech departments and `'non-technical'` returns only the 6; existing combined-`'non-it'` behavior must remain available and unchanged for call sites that still want it.
- **Risk if unaddressed**: Moderate — a real, correctly-sourced UX mismatch against the checklist's own emphasis on offering the choice "conveniently"; not a functional blocker, since the combined list still contains every department, just not filtered as asked.

### P1-2. "Build Resume" (role-action popup) requires login where the web doesn't (Item 7)

- **Source evidence**: `royalStaffing_CB01/career_app/manual_resume_views.py` has no `@login_required` on `roles_api`/`preview_api`/`pdf_download`/`preview_pages_api`. `Mobile_app/lib/app/router/route_paths.dart`'s `manualResumeBuilder` is deliberately excluded from `universalRoutes` (a documented Phase 25 decision made with explicit awareness of this exact web/mobile gap).
- **Affected files**: `lib/app/router/route_paths.dart` (the `universalRoutes` set), route guard tests.
- **Dependencies**: **This is a product decision, not a pure engineering task** — Phase 25 made this choice deliberately; it should be explicitly re-confirmed with stakeholders before changing, not silently reversed by this roadmap.
- **Estimated scope**: Small (if the decision is to loosen the guard — the route and screen already function correctly for authenticated users).
- **Verification method**: if changed, a widget/route-guard test confirming a guest can reach the Manual Resume Builder from the role-action popup without a redirect to Login.
- **Risk if unaddressed**: Moderate — guests lose a genuinely no-login web capability; low risk of harm either way since the feature works correctly once logged in.

### P1-3. "Skills" and "Skill up yourself" destinations are not role/section-filtered (Items 7, 15)

- **Source evidence**: Web deep-links to `skill_up?section=role-<track>-<dept>--<role>` (`landing.html:8111-8123`); `career_role_skills_view.dart` and `mock_interview_results_view.dart`/`resume_builder_screen.dart`'s "Skill up yourself" buttons all open the general `RoutePaths.skillUpSections` hub instead.
- **Affected files**: `lib/features/skill_up/presentation/screens/skill_up_screen.dart` (needs a section-id deep-link capability), the 3 call sites above.
- **Dependencies**: Medium — the Skill-Up screen's current architecture has no concept of jumping to a specific section/role on open; this requires adding that capability once, then wiring 3 call sites to it. The web-side role→section-id mapping logic already exists to port.
- **Estimated scope**: Medium.
- **Verification method**: widget test confirming opening Skill-Up with a role/section parameter lands on the correct section, not just the hub's default tab.
- **Risk if unaddressed**: Low–Moderate — users land one tap further from the content than the web places them; the content remains reachable.

### P1-4. Top-nav mega-menus incomplete in the Flutter drawer (Item 2)

- **Source evidence**: `royalStaffing_CB01/templates/includes/site_nav.html:67-114` — 11-entry Skill Up mega-menu and 7-entry Resources mega-menu; `Mobile_app/lib/shared/widgets/app_nav_drawer.dart:92-101` has only 4 of 11 Skill Up entries and no Resources grouping at all.
- **Affected files**: `app_nav_drawer.dart`.
- **Dependencies**: Most destinations for the missing entries already exist elsewhere in the app (Activities screens, Certifications, Sitemap, etc.) — this is primarily a navigation-affordance addition, not new feature-building.
- **Estimated scope**: Small–Medium (expand 2 menu groups to their real entry counts; add 4 flat top-level shortcuts if feasible — see P2 note on in-page-anchor scrolling).
- **Verification method**: widget test enumerating the drawer's Skill Up group and asserting all 11 (10 + Browse All) entries are present and routed correctly.
- **Risk if unaddressed**: Moderate — real content categories (Vocabulary & Idioms, Speaking & Presentation, Writing & Correspondence, Negotiation & Meetings, Interactive Roleplay, Certifications) are undiscoverable from the primary navigation entry point, even where reachable some other way.

### P1-5. Authenticated Create Resume doesn't auto-open the most recent draft (Item 4)

- **Source evidence**: `royalStaffing_CB01/static/js/create_resume.js:821-827` auto-loads a signed-in user's most-recently-updated draft on page load; `Mobile_app/lib/features/resume/presentation/controllers/create_resume_builder_controller.dart`'s `startBlank()` always starts blank for an authenticated user with no `initialForm`.
- **Affected files**: `create_resume_builder_controller.dart` (add an authenticated-equivalent of the existing `restoreGuestDraftIfAvailable()`), `create_resume_builder_screen.dart` (call it, show an equivalent one-time banner).
- **Dependencies**: None — the drafts-list fetch and `startFromDraft()` path already exist and work; this reuses both.
- **Estimated scope**: Small–Medium (the guest-restore mechanism's race/generation-guard pattern can be largely reused).
- **Verification method**: controller test confirming an authenticated user with ≥1 saved draft auto-opens the most recent one on a fresh `startBlank()` call, and that a user with zero drafts still gets a blank form; screen test for the equivalent banner.
- **Risk if unaddressed**: Low–Moderate — no data loss (the drafts list and Open action fully work), just an extra manual step for a returning signed-in user.

---

## P2 — Verification (implemented functionality needing legitimate device/account/state-based verification)

All of the following are **source-confirmed and automated-test-confirmed already** — nothing here is a known code defect. Each needs a legitimate account/device this audit did not have access to, to close the final, honest "implemented but not device-verified" gap.

| Item | What needs verifying | What account/device is needed |
|---|---|---|
| 8, 15 | Live rendering of all 4 resume-outcome branches and both recovery-action screens | Any authenticated account; ideally one in each of the 4 outcome states |
| 10 | An actual unlimited job-recommendation list for a Pro-plan user | A legitimate Pro-plan test account |
| 12, 13 | Opening a real Non-IT Skill-Up lesson and observing whether `webview_flutter`'s default config actually grants working HTML5 fullscreen for the embedded 3-warning quiz engine | A legitimate paid-plan (`normal`/`pro`) test account |
| 13 | Same fullscreen question for the 4 standalone Skill-Up mock-test pages | Same paid-plan account |
| 14 | Visual confirmation of the Free-plan locked-content wall, the 1-activity limit, and the 4-resume-parse exhaustion message, each live | A legitimate Free-plan test account |
| 14 | One full Razorpay test-mode order-create → pay → verify round-trip | Razorpay **test-mode** credentials (never production) |
| 6 | Actual tutorial video frame decode/playback on-device (a prior report claims this was done; not re-verified this audit) | Any device + network access |
| 4 | Live confirmation of the guest-save/restore/PDF round-trip (a prior report claims this was done; not re-verified this audit) | Any device, guest session |

**None of these should be closed by fabricating an account or bypassing a
plan/auth check** — per every phase's own standing instruction, including
this one. They should be scheduled whenever the project has legitimate
access to each tier.

---

## P3 — Lower priority

### P3-1. Inert "What can you do with CareerBuddy?" cards (Item 6)

4 of 9 cards (Learn, Build your resume, Find jobs, Get AI guidance) should
open the corresponding tutorial video on tap, matching the web's `CB_CAN`
→ `open(id)` wiring. **Affected file**: `home_tutorials_section.dart`.
**Scope**: Small (wire existing `HomeTutorialVideoDialog.show()` calls to 4
existing items). **Risk**: Low — the same content is still one tap away via
Featured Tutorials.

### P3-2. Tutorial watched-state / resume-position (Item 6)

Web persists per-video watched checkmarks and playback resume position via
`localStorage`; no Flutter equivalent exists. **Affected files**:
`home_tutorial_video_dialog.dart`, `home_tutorials_section.dart`. **Scope**:
Small–Medium (via `shared_preferences`). **Risk**: Low — pure engagement
polish, not required for the core "learn more about the app" requirement.

### P3-3. Android `FLAG_SECURE` screenshot block for Mock Interview (Item 13)

A genuine mobile-only capability the app doesn't use — stronger than the
web's own detect-only approach. **Affected files**: native Android
platform channel + `mock_interview_screen.dart`'s camera-gate/question
lifecycle. **Scope**: Medium (native platform-channel work, not pure
Dart). **Risk**: Low-to-moderate depending on how seriously screenshot
leakage of interview questions is treated as a business risk — flagged as
P3 rather than higher only because it is a net-new capability, not a
regression or a broken existing one.

### P3-4. 383 Tech Center nested role-course pages are unreachable (Item 13)

Build a `SkillUpTechRolesScreen` analogous to the existing
`SkillUpNonItRolesScreen`, sourced from a Tech-Center-equivalent JSON
carrying a `coursePath` per role (the existing `it_departments.json` has no
such field and would need a sibling asset, following the exact same
extraction/parsing pattern already proven for Non-IT in Phase 47).
**Affected/new files**: a new Tech-Center course-path data asset + data
source + 1-2 new screens, mirroring the Non-IT pattern closely.
**Dependencies**: none blocking — the pattern to copy already exists and
works. **Scope**: Medium–Large (new asset extraction + new screens, though
low architectural risk since it's a proven pattern). **Risk**: Moderate —
real graded content is currently unreachable, but this is pre-existing
(not a regression) and lower urgency than P0's submission-blocking bug.

### P3-5. "Resources" mega-menu and 4 flat top-level nav items (Item 2)

Covered partially by P1-4's Skill Up expansion; the "Resources" grouping
and the 4 flat items (About Us, Industries, Create Resume, Contact Us) are
lower priority since their underlying content is already reachable by
scrolling the Home screen — this is purely a navigation-shortcut
convenience. **Scope**: Small, contingent on whether in-page-anchor
scrolling is feasible in the current Flutter nav model (a design question,
not just an engineering one). **Risk**: Low.

### P3-6. Documentation corrections

- Update `WEB_SCREEN_INVENTORY.md`, `WEB_FLOW_MAP.md`,
  `WEB_TO_MOBILE_SCREEN_MATRIX.md`, `PRODUCTION_E2E_VERIFICATION_REPORT.md`
  to stop describing "Post New Job" as unbuilt.
- Update `app_top_bar.dart`/`app_nav_drawer.dart`'s doc comments to cite
  `site_nav.html` instead of the stale `base.html` line ranges.
- Note `LANDING_PAGE_WEB_MOBILE_PARITY_REPORT.md`'s "69/69" test count as
  historical/stale (current count for the same command is 47/47).

**Scope**: Small, no code risk. **Risk**: None functional — maintainer
clarity only.

---

## Explicitly no work needed

The following areas were audited this phase and found to require **no
further implementation work** — listed here per the task's instruction not
to invent tasks where none are warranted:

- **Item 1** (landing popup): fully implemented and verified; only the
  guest-only-audience limitation is noted, and that is tied to a separate,
  out-of-scope authenticated-Home architectural decision (see Item 3's
  note in the matrix), not something to "fix" in isolation.
- **Item 3** (IT/Non-IT selection entry points): fully implemented.
- **Item 8** (ATS scoring/thresholds/role-mismatch): fully implemented;
  only live-device visual confirmation remains, tracked under P2.
- **Item 9** (AI interview personalization): fully implemented server-side,
  correctly never duplicated client-side.
- **Item 10** (job recommendation counts): fully implemented, low-drift
  architecture; only the Pro-plan live count is unverified, tracked under P2.
- **Item 11** (AI chatbot context/language): fully implemented; only live
  LLM response-language fidelity is unverified, tracked under P2, and that
  is equally unverifiable from source on the web side too.
- **Item 14** (free-plan restrictions): fully implemented, no hardcoded
  drift-risk numbers anywhere; only live account-tier confirmation and the
  Razorpay round-trip remain, tracked under P2.
- **Item 15**'s core recovery-action mechanics (beyond the P1-3 deep-link
  precision note): fully implemented.
