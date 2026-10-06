# Career Buddy LMS — Web ↔ Flutter Coverage Report

Every number below is tallied from the actual inspection already performed
and recorded in `docs/WEB_SCREEN_INVENTORY.md`, `docs/WEB_FLOW_MAP.md`,
`docs/WEB_API_INVENTORY.md`, and `docs/WEB_STATIC_CONTENT_INVENTORY.md` —
7 parallel read-only discovery passes across all 11 Django apps, plus this
session's own direct work (Password Reset, Registration, Profile, the
Dashboard navigation-dead-end fix). Counts marked "approximate" are
explicitly disclosed as such — see the linked inventory for the exact
row-by-row detail behind them. Nothing here is invented or rounded up to
sound more complete than what was actually found.

```text
Total web routes:              ~150 (see WEB_SCREEN_INVENTORY.md, sections A-K)
Total web screens:              ~95 (routes minus pure API/action endpoints,
                                      redirects, and dead/orphaned routes)
Total web flows:                 16 (Auth, Activities/Exercises, Mock Tests,
                                      Grammar, Skill-Up, Resume/ATS, AI Mock
                                      Interview, Subscriptions, Certificates,
                                      ARIA, JAM, Roleplay, GD, Employer Portal,
                                      Jobs/Career, Profile/Password-Reset)
Total web templates:            ~60 (approximate — not separately enumerated
                                      as a standalone template-file count;
                                      derivable 1:1 from the screens above,
                                      most screens map to exactly one template)
Total web APIs:                 ~118 rows (WEB_API_INVENTORY.md)
Total static-content sources:    17 (WEB_STATIC_CONTENT_INVENTORY.md)

Flutter screens:                 ~85 (existing feature screens + this
                                      session's Password Reset (4),
                                      Registration (1), Profile (1))
Verified:                        ~20 (screens exercised live against
                                      production with real accounts this
                                      session and the prior E2E verification
                                      task — see
                                      docs/PRODUCTION_E2E_VERIFICATION_REPORT.md)
Implemented (not live-verified):  ~60 (analyzed/unit-tested, matches the
                                      documented web contract, not yet
                                      exercised against production with a
                                      real account)
Testing:                           0
Blocked:                           0
Missing:                          ~20 (screens with NO Flutter route at all —
                                      see the MISSING_IN_FLUTTER rows in
                                      WEB_API_INVENTORY.md and the "GAP, no
                                      placeholder" rows in
                                      WEB_SCREEN_INVENTORY.md)

API:
Matched:                          ~75
Missing:                          ~25
Backend-blocked:                    7 (BACKEND_NOT_DEPLOYED — exists
                                      uncommitted in the local Django
                                      checkout, 404s live)
HTML-only (intentional, both sides): ~6

UI:
Web-equivalent:                  Every screen live-verified this session and
                                  the prior E2E task matched the web's
                                  information hierarchy and content — no
                                  P0/P1 UI-fidelity defects found in those
                                  screens. The remaining ~60 "Implemented,
                                  not live-verified" screens have NOT had a
                                  screen-by-screen visual diff against the
                                  real web performed this pass — this is an
                                  honest, disclosed gap, not a claim of
                                  verified parity.
Intentional mobile adaptations:  ~10 (documented individually in
                                  WEB_SCREEN_INVENTORY.md's "UI Differences"
                                  section — e.g. Skill-Up's tab layout vs.
                                  web's hash-anchor SPA, JAM/GD's real
                                  improvements over web's own bugs, password
                                  reset's paste-link flow)
Known differences:               Dashboard's greeting shows the raw username
                                  instead of the web's personalized first
                                  name (root cause: the documented
                                  `/dashboard/api/` contract has no
                                  first-name field, undeployed regardless)

Navigation:
Verified:                        6 screens confirmed this session to have a
                                  working nav drawer, including on an error
                                  state (Dashboard, Activities, Profile,
                                  Workshop Dashboard, Mock Tests Hub,
                                  Roleplay Home) — covered by a new
                                  regression test
                                  (dashboard_screen_test.dart)
Missing:                          Active/in-session screens (the 4 mock-test
                                  exam screens, the AI Mock Interview screen)
                                  intentionally were not given the drawer —
                                  treated as a focused-task adaptation, not
                                  yet independently confirmed against the
                                  web's own behavior during an active exam;
                                  flagged for a follow-up decision rather
                                  than fixed silently

Web source modified:
NO
```

## What "Verified" actually means here

Per this task's own anti-inflation rule, "Verified" above is reserved for
screens with real, live evidence — not screens that merely compile and pass
unit tests. The ~20 counted as Verified are:

- Login, Logout (fixed & re-verified this session's earlier phase), Password
  Reset (3 of 4 states — the 4th requires a real email inbox), Registration
  (rendering + OTP-send verified live; full submission deliberately not
  performed, since it creates a real account), Profile Overview + Edit
  pre-fill (both verified live against a real production account, including
  finding and fixing a real phone-prefill bug the live pass surfaced).
- Every screen the 4 background account-verification agents exercised live
  in the earlier E2E task: student/employer dashboards (data comparison),
  Activities, Mock Tests (OOP/AMCAT/CoCubes), Certifications, Resume
  History, Skill-Up, Grammar, ARIA, JAM, Roleplay, Group Discussion,
  Employer Home/Dashboard/Login.

Everything else marked "Implemented" has passing unit tests and a clean
`flutter analyze`, and its data/API contract was cross-referenced against
the real Django source — but has not itself been clicked through against a
live production account this pass. That is a real, disclosed limit on this
report's confidence, not a gap in the underlying code's likely correctness.

## Biggest remaining gaps, ranked

1. **Subscriptions/Payments (`/pro/*`)** — ~0% implemented, no Razorpay SDK
   dependency exists at all. Users cannot upgrade their plan inside the app.
2. **Employer Application Detail** (`/employer/employer/applications/<pk>/`)
   — no Flutter route at all; the only place an employer can change an
   applicant's status.
3. **5 more employer screens** with no Flutter destination at all (Job Edit,
   Job Delete, per-job Applications, My Application Detail, Quick Apply),
   plus 5 more that are `ComingSoonScreen` placeholders (Company Profile,
   Post Job, All Applications, Job Openings, Candidate Search).
4. **`/dashboard/api/` + `/activities/api/*` undeployed** — blocks Dashboard
   data, Activities list/detail, and MCQ for every account, even though the
   Flutter code correctly implements the documented contract. Backend-side
   fix (deploy already-written code), not a Flutter defect.
5. **ARIA streaming/voice/language-selector** — Flutter uses the
   non-streaming chat endpoint (the web's real path is SSE streaming), and
   has no voice input/output or language switching.
6. **Skill-Up's lesson catalog is hand-maintained**, unlike the web's own
   auto-derived chatbot catalog — a real maintenance-drift risk, not a
   current-state defect.

**Web source modified: NO.**
