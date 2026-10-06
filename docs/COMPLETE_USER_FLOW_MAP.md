# Career Buddy LMS — Complete User Flow Map

Companion to `docs/COMPLETE_WEB_TO_FLUTTER_MASTER_INVENTORY.md` (route-level
detail lives there; this file maps navigation). Organized by the exact
category breakdown requested, with every named item addressed explicitly —
`[✓]` MATCH/IMPLEMENTED, `[~]` PARTIAL, `[✗]` MISSING/PLACEHOLDER,
`[n/a]` NOT_APPLICABLE on the web itself.

**Web source modified: NO.**

## Public

```
Landing/Home                                    [~] top section only
Login (student)                                 [✓]
Registration                                    [~] built, submit not live-tested
OTP verification                                [✓] shared send/verify endpoint
Forgot password                                 [✓]
Reset password                                  [~] invalid-link state verified; success state unit-tested only
Password change                                 — same screen as Reset Password; no separate
                                                   "change password while logged in" flow exists
                                                   on the web (Profile Edit has no password field)
Public pages                                     [n/a] no Contact/Terms/Privacy/Help pages exist
                                                   on the web itself
Public workshops/content                        [✓] Skill-Up hub + lesson pages are genuinely
                                                   unauthenticated on web; Flutter matches
Public subscription pages                       [✗] /pro/ plan comparison — MISSING in Flutter
```

## Student / Jobseeker

```
Dashboard                                        [~] UI built, drawer-navigation bug fixed this
                                                    session; data blocked by BACKEND_NOT_DEPLOYED
Profile                                          [✓] live-verified
Profile Edit                                     [✓] live-verified, phone-prefill bug fixed
Activities                                       [~] UI built, same backend-deployment block
Activity categories                              [✓] free-plan filtering confirmed live
Practice                                         — see Exercises below
Exercises (MCQ/Fill-Blank/Matching/Bingo/
  Generic-Writing/Timer)                         [~] see §C of the master inventory — Matching has
                                                    a live scoring anomaly, Bingo/Timer not live-tested
Grammar                                           [✓] all 9 real topics confirmed present
Grammar topics                                    [✓] re-verified via fresh full-file programmatic scan
Grammar classes                                   — "classes" = the topic detail pages themselves;
                                                    no separate "class" concept exists on the web
Grammar practice                                  [✓] practice/example sections within each topic page
Grammar tests                                     — Grammar has no dedicated quiz/test separate from
                                                    the in-page practice exercises; Mock Tests (below)
                                                    are the real quiz system
Mock Tests                                        [✓] all 4 systems live-verified
  OOP                                              [✓]
  AMCAT                                            [✓]
  CoCubes                                          [✓]
Workshops                                         [✓] Roleplay/JAM/GD all live-verified
Workshop dashboard                                [✓] drawer-fixed this session
Workshop detail                                   — folded into each workshop's own home screen
Practice sessions                                 [✓] JAM/Roleplay/GD sessions all live-verified
JAM                                               [✓]
JAM practice                                      [✓]
JAM assessment                                    [✓] 3-stage flow code+eligibility verified
Roleplay                                          [✓] live-verified, no gaps found
Group Discussion                                  [✓] live-verified, 1:1 WebSocket protocol
AI Speaking                                        [~] contract verified, no live audio submitted
AI Listening                                       [~] token contract live-verified, analyze not live-tested
AI Reading                                         [~] contract verified only
AI Writing                                         [~] contract verified; a sibling Writing-type exercise
                                                    scored 100/100 live
Certifications                                    [✓] live-verified
Skill-Up                                          [~] content matches; catalog is hand-maintained (drift risk)
Skill-Up subjects                                  [✓]
Skill-Up lessons                                   [✓] ~64 real lesson pages, all reachable
Skill-Up assessments                               [✓] same as Certifications above (same subsystem)
ARIA/Riya                                         [~] non-streaming chat MATCH; streaming/voice/language MISSING
Resume Builder                                    [✓] live-verified
Resume templates                                   [✓] exactly 3 real templates, 1:1 match confirmed
Resume creation                                    — the web is an analyzer, not a from-scratch builder;
                                                    "creation" = upload + ATS/JD match, which matches
Resume editing                                     — no section-by-section editor exists on the web
                                                    either (confirmed: `ResumeBuilder_module` is a
                                                    dormant, unintegrated reference package, not live)
Resume preview                                     [✓] ATS result page IS the preview; matches
Resume download                                    [✓] the 3 static template downloads; matches
Resume history                                     [✓] live-verified, with a known SSO-loss limitation
ATS                                               [✓] live-verified
ATS resume testing                                 [✓]
Resume parsing                                     [✓]
Resume analysis                                    [✓] deterministic scoring rules confirmed matching
Payments                                          [✗] MISSING — see §H of the master inventory
Subscription                                       [✗] MISSING
Plan selection                                     [✗] MISSING
Payment success/failure                            [✗] MISSING
Account/profile                                   [✓] same as Profile above
Logout                                            [✓] live-verified, bug found+fixed this session
```

## Employer

```
Employer login                                    [✓] live-verified (rameshn, Testthree)
Employer dashboard                                [✓] live-verified for both a complete and an
                                                     incomplete-profile account
Company profile                                   [✗] PLACEHOLDER
Company profile edit                              [✗] PLACEHOLDER (same screen handles both on web)
Post job                                          [✗] PLACEHOLDER
Job openings                                      [✗] PLACEHOLDER
Job detail                                        [✗] PLACEHOLDER (generic, not employer-aware —
                                                     the real web view has 2 render modes depending
                                                     on session; Flutter has 1 placeholder for both)
Edit job                                          [✗] MISSING — no route at all
Delete job                                        [✗] MISSING
Applications                                      [✗] PLACEHOLDER (all-applications list)
Application detail                                [✗] MISSING — no route at all; the single most
                                                     consequential employer gap (only place status
                                                     changes happen, which email the candidate)
Candidate search                                  [✗] PLACEHOLDER
Candidate detail                                   — folded into Candidate Search's result cards on
                                                    web; no separate detail page exists there either
Any resume/candidate actions                      [✗] MISSING (view resume, contact candidate — all
                                                     part of the missing Candidate Search/Application
                                                     Detail screens)
Any employer settings                              — Company Profile IS the employer settings screen
                                                    on web; already tracked as PLACEHOLDER above
Any employer subscription/payment flow            — employers use the same `/pro/` flow as students;
                                                    tracked once under Payments above, not duplicated
Logout                                            [✓] shared global logout — confirmed live
```

---

## Flows NOT in the original category list, found during discovery

- **Per-job Quick Apply** (from Resume Builder → Job Match) — MISSING.
- **My Application Detail** (student-side, deep-linked from status-change
  emails) — MISSING.
- **Candidate CSV export** — exists as a real Django URL but has no UI
  button anywhere on the web itself; NOT_APPLICABLE, not a Flutter gap.
- **`job_logout`** and **`jobs_app.urls`/`job_list()`** — dead/orphaned
  Django routes, confirmed unreachable from any real page; excluded from
  parity tracking.

**Web source modified: NO.**
