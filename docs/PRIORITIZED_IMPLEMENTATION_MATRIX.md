# Career Buddy LMS — Prioritized Implementation Matrix

The last discovery deliverable before implementation resumes. Ordered by
the 14-phase sequence requested, each row showing: Web Feature → Web
Screen → Flutter Status → API → Data → UI Status → Test Status → Blocker.

Status vocabulary matches `COMPLETE_WEB_TO_FLUTTER_MASTER_INVENTORY.md`.
UI Status: `UI_VERIFIED` (actual visual comparison performed, live or
on-device) vs. `UI_NOT_VERIFIED` (source-inspected only).

**Web source modified: NO.**

## PHASE 1 — Foundation (largely complete; verify, don't rewrite)

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| Navigation | Persistent top navbar (`base.html`) | IMPLEMENTED_NOT_VERIFIED→MATCH | n/a | n/a | UI_VERIFIED (drawer confirmed open on 6 screens, incl. live on real production) | 1569/1569 pass, +1 new regression test | none — dead-end found and fixed this session |
| Authentication | Login/Logout/Register/OTP/Password-Reset/Profile | MATCH (see §A) | MATCH | MATCH | UI_VERIFIED (login, password-reset screens; registration/profile rendering) | passing | Registration full-submit and Password-Reset success-state need a real email inbox to close |
| Session handling | Cookie-based, server session | MATCH | MATCH | MATCH | n/a | passing | none |
| Shared components (AppButton/AppCard/AppTextField/AppLoader/AppErrorView) | n/a | IMPLEMENTED | n/a | n/a | UI_VERIFIED (used across every live-tested screen) | passing | none |

## PHASE 2 — Student Home

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| Dashboard | `dashboard.html` | IMPLEMENTED_NOT_VERIFIED (UI); nav-dead-end fixed | **BACKEND_NOT_DEPLOYED** | blocked | UI_NOT_VERIFIED (data-dependent sections unreachable) | passing (error-state tests) | **Backend deploy of `/dashboard/api/`** — Flutter code already matches the documented contract field-for-field |
| Activities list/detail | `list.html`/`detail.html` | IMPLEMENTED_NOT_VERIFIED | **BACKEND_NOT_DEPLOYED** | blocked | UI_NOT_VERIFIED | passing | same backend deploy |
| Activity progress navigation hub | Workshop Dashboard | MATCH | MATCH | MATCH | UI_VERIFIED | passing | none |

## PHASE 3 — Grammar

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| Subject library (9 topics) | `/subject/` | MATCH | WEB_HTML_ONLY (static, re-verified this document) | MATCH | UI_NOT_VERIFIED this pass (screen itself not re-screenshotted) | passing | none |
| Topic detail (all media) | `/subject/<slug>.html` | IMPLEMENTED_NOT_VERIFIED | WEB_HTML_ONLY | MATCH | UI_NOT_VERIFIED | passing | none — low priority to re-verify, already thorough from a prior batch |

## PHASE 4 — Classes / Practice / Workshops

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| JAM (practice + assessment) | `/jam/*` | MATCH | MATCH | MATCH | UI_VERIFIED (prior E2E) | passing | none |
| **JAM History/Profile/Delete/Reset** | `/jam/{history,profile,session/delete,assessment/delete,reset-progress}/` | **IMPLEMENTED_NOT_VERIFIED** | MATCH (code-verified; History genuinely `@login_required`, confirmed live anonymous→302; Profile confirmed live anonymous→200, i.e. no login required) | MATCH | UI_VERIFIED via widget tests only | passing | not live-round-tripped — no student test-account credentials available this session, and Delete/Reset are genuinely destructive (would need explicit authorization to exercise against a real account even with credentials) |
| Roleplay | `/roleplay/*` | MATCH | MATCH | MATCH | UI_VERIFIED | passing | none |
| Group Discussion | `/gd/*` | MATCH | MATCH | MATCH | UI_VERIFIED | passing | none |

## PHASE 5 — Exercises

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| MCQ | `/activities/api/exercise/<pk>/` | IMPLEMENTED_NOT_VERIFIED | BACKEND_NOT_DEPLOYED | blocked | UI_NOT_VERIFIED | passing | backend deploy |
| Fill-Blank | `/activities/exercise/<pk>/` | MATCH | MATCH | MATCH | UI_VERIFIED (prior E2E) | passing | none |
| Matching | same | PARTIAL | MATCH (request); anomaly (response) | anomaly | UI_VERIFIED | passing | **live scoring anomaly — needs backend investigation**, not a Flutter fix |
| Bingo | same | IMPLEMENTED_NOT_VERIFIED | MATCH (contract re-verified this session field-by-field against fresh `exercises.js`; real mechanic corrected — "definition read aloud, click the matching word," not mark-off-as-you-hear-it) | not live-tested | UI_NOT_VERIFIED | passing | blocked on an unavailable test credential (live login failed; not pursued further per explicit user direction) |
| Generic Writing | same | IMPLEMENTED_NOT_VERIFIED→MATCH (sibling) | MATCH | live-confirmed (100/100 real AI grade) | UI_VERIFIED | passing | none |
| Timer | same | IMPLEMENTED_NOT_VERIFIED | MATCH (contract re-verified this session; "server-side Sarvam AI re-grade" confirmed to mean the server only overrides the client score when `SARVAM_API_KEY` is set, else trusts it outright — `TimerClientScorer` already ports the real JS heuristic exactly) | not live-tested | UI_NOT_VERIFIED | passing | blocked on an unavailable test credential |
| AI Speaking | `/activities/exercise/<pk>/analyze/speaking/` | IMPLEMENTED_NOT_VERIFIED | MATCH (contract re-verified this session) | not live-tested | UI_NOT_VERIFIED | passing | blocked on an unavailable test credential; one minor documented gap — no client-side 25-word pre-submission nudge (server has no such minimum either, so non-blocking) |
| AI Writing | `/activities/exercise/<pk>/analyze/writing/` | IMPLEMENTED_NOT_VERIFIED | MATCH (contract re-verified this session; gate corrected from "word count" to the real 500-900 non-whitespace **character** count, already correctly implemented) | not live-tested | UI_NOT_VERIFIED | passing | blocked on an unavailable test credential |
| AI Reading | `/activities/exercise/<pk>/analyze/reading/` | IMPLEMENTED_NOT_VERIFIED | MATCH (contract re-verified this session; scoring corrected from "pronunciation" to SequenceMatcher-based text similarity against a reference passage; the Flutter passage bank re-checked word-for-word against `reading.js`'s hardcoded list and found to be a verbatim port) | not live-tested | UI_NOT_VERIFIED | passing | blocked on an unavailable test credential |
| AI Listening | `/activities/exercise/<pk>/analyze/listening/` | IMPLEMENTED_NOT_VERIFIED (re-scoped from a split MATCH/IMPLEMENTED_NOT_VERIFIED — see notes) | MATCH (contract re-verified this session; corrected — there is no separate "token endpoint," the `attempt_token` comes from the ordinary exercise page load) | token mechanism confirmed live (`nvenkatsai`); the `analyze` scoring submission itself not live-tested | UI_NOT_VERIFIED | passing | blocked on an unavailable test credential for the actual scoring submission |

## PHASE 6 — Mock Tests

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| OOP/AMCAT/CoCubes/24-subject | all 4 systems | MATCH | MATCH | MATCH | UI_VERIFIED | passing | none |

## PHASE 7 — Skill-Up

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| Hub + lesson pages | `/skill-up/` | IMPLEMENTED_NOT_VERIFIED (structural tab-vs-SPA adaptation) | MATCH | MATCH (content) / PARTIAL (catalog maintenance) | UI_NOT_VERIFIED this pass | passing | **catalog drift risk** — recommend an auto-derivation mechanism matching `riya_bot/skillup_catalog.py`'s approach, not a blocking bug today |
| Certifications | `/skill-up/assessment/*` | MATCH | MATCH | MATCH | UI_VERIFIED | passing | none |

## PHASE 8 — AI Features

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| ARIA chat (non-streaming) | `/api/riya/chat/` | MATCH | MATCH | MATCH | UI_VERIFIED | passing | none — now this app's own secondary path, see below |
| **ARIA streaming (the real default path)** | `/api/riya/chat/stream/` | **MATCH** | MATCH (full SSE protocol live-verified against production, byte-for-byte) | MATCH | UI_VERIFIED via widget tests (incremental token rendering) | passing | none — this session |
| **ARIA language selector** (manual `#chatbotLanguageSelect` dropdown + `<LANG:code>` mid-stream auto-detect) | n/a (both write `AriaChatState.language`, same field every chat/voice/TTS request reads) | **IMPLEMENTED_NOT_VERIFIED** | MATCH (contract production-verified live for `language: "hindi"` against both the streaming chat and TTS endpoints) | MATCH (same 5 languages/codes/labels/order as the real `<select>`) | UI_NOT_VERIFIED (no physical-device test this pass) | passing | header dropdown built; no separate manual-vs-auto precedence logic needed since the real web has none (last write to the one shared field wins, reproduced identically); changing language cancels an in-progress recording (matches the real web's own handler), does not stop in-flight streaming/TTS (also matches) |
| **ARIA voice transcription** | `/api/voice/transcribe/` | **IMPLEMENTED_NOT_VERIFIED** | MATCH (contract production-verified live with fully synthetic audio, see `ApiEndpoints.riyaVoiceTranscribe`) | MATCH | UI_NOT_VERIFIED (no physical-device mic test this pass) | passing | auto-sends the transcription immediately (confirmed real web behavior — `processTranscript(text, "voice")` is the same entry point typed text uses, no review step); needs a real-device mic run to close |
| **ARIA text-to-speech** | `/api/voice/tts/` | **IMPLEMENTED_NOT_VERIFIED** | MATCH (contract production-verified live, see `ApiEndpoints.riyaTts`) | MATCH | UI_NOT_VERIFIED (no physical-device audio-output test this pass) | passing | every reply auto-speaks (confirmed real web behavior: `speak: true` unconditional on the streaming path); header speaker button is replay/stop only, not the web's replay/pause/resume (`flutter_tts` has no true resume) — needs a real-device audio run to close |
| **ARIA widget global coverage** | n/a | **MATCH** | n/a | n/a | n/a | passing | audit complete (`base.html` includes the widget unconditionally; only real exclusions are Skill-Up certification exam-taking, a commented-out user-guide include, a GST invoice document, and Django admin); rollout complete — 61/62 Flutter screens now carry it, only `SplashScreen` deliberately excluded (no web equivalent) |
| AI Mock Interview | `career_app` (`/resume-builder/{start-interview,camera-verified,get-question,submit-answer,record-violation,violation-state,upload-interview-video,analytics}/`) | IMPLEMENTED_NOT_VERIFIED | MATCH (contract re-verified field-by-field this session against a fresh full backend re-read; corrected a prior assumption that this might live in `ResumeBuilder_module`, which is confirmed dead code) | not live-tested (login attempt for the one available test credential failed live; not pursued further per explicit user direction — see master inventory G4) | UI_NOT_VERIFIED | passing | needs a valid, plan-eligible test credential to close; face-detection intentionally out of scope (no ML equivalent — and the web's own analogous `FULLSCREEN_EXIT` violation type is confirmed unused/decorative too, so this isn't an isolated gap) |

## PHASE 9 — Resume

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| Upload/ATS/JD-match | `/resume-builder/match/` | MATCH | MATCH | MATCH | UI_VERIFIED | passing | none |
| Templates (3, static) | ATS result page | MATCH | WEB_HTML_ONLY | MATCH | UI_VERIFIED | passing | none — confirmed not a gap despite initial assumption of a richer gallery |
| History | `/resume-builder/history/` | MATCH | MATCH | MATCH | UI_VERIFIED | passing | known limitation: "View File" loses session cookies |

## PHASE 10 — Subscription / Payments

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| Plan comparison | `/pro/` | **MISSING** | MISSING | MISSING | n/a | n/a | **Full implementation gap — the single largest in the app** |
| Razorpay checkout | `/pro/create-order/`, `/pro/verify-payment/` | **MISSING** | MISSING | MISSING | n/a | n/a | No Razorpay Flutter SDK dependency exists; real-money/PCI-adjacent — needs explicit go-ahead before starting (user already deferred this once this session) |
| GST invoice | `/pro/invoice/<pk>/` | **MISSING** | MISSING | MISSING | n/a | n/a | same |

## PHASE 11 — Employer

| Web Feature | Web Screen | Flutter Status | API | Data | UI Status | Test Status | Blocker |
|---|---|---|---|---|---|---|---|
| Login/Dashboard | | MATCH | MATCH | MATCH | UI_VERIFIED | passing | none |
| **Application Detail** (status change) | `employer/employer/applications/<pk>/` | **MATCH** | MATCH | MATCH | UI_VERIFIED (on-device, real application id 12) | passing | none — done this session's prior task |
| **Company Profile create/edit** | `employer/employer/profile/{create,edit}/` | **MATCH** | MATCH (GET live-verified; POST code-verified, not live-submitted) | MATCH | UI_NOT_VERIFIED (not run on-device this turn) | passing | none — closes the dashboard's incomplete-profile dead-end |
| **Delete Job** | `employer/employer/jobs/<pk>/delete/` | **MATCH** | MATCH | MATCH | UI_VERIFIED (widget tests: confirm dialog, cancel, confirm+snackbar) | passing | none — this session |
| **Job Applications (per-job list)** | `employer/employer/jobs/<pk>/applications/` | **MATCH** | MATCH (parser run against real production HTML, 4 real applications) | MATCH | UI_NOT_VERIFIED on-device (attempted; blocked by an emulator input-automation issue that plausibly tripped a short login throttle on the real account — see `COMPLETE_WEB_TO_FLUTTER_MASTER_INVENTORY.md` §K's note); UI_VERIFIED via widget tests instead | passing | on-device re-check recommended once any account throttle clears |
| **Post Job / Edit Job** (`job_create`/`job_edit`) | `employer/employer/jobs/{new,<pk>/edit}/` | **MISSING — genuinely blocked, not unbuilt** | n/a | n/a | n/a | n/a | the real production form has diverged from this repo's `JobPostingForm`/`job_form.html` (confirmed on `main` and `origin/dev`, absent from full git history): production adds a `keywords` field, a conditional `application_contact` field, a Department selector driving 129 categorized skill checkboxes with mandatory-marking, and a `contract-duration` block. Building against the committed 17-field contract risks submitting the wrong shape (worst case on edit: silently clearing a real job's skills) — flagged for the repo owner to reconcile which source is deployed before this is attempted |
| **All Applications** | `employer/employer/applications/` | **MATCH** | MATCH (parser run against real production HTML, 4 real applications incl. job title/source) | MATCH | UI_VERIFIED via widget tests (caught + fixed 2 real narrow-width overflow bugs) | passing | none — this session |
| **Candidate Search** | `employer/employer/candidates/search/` | **MATCH** | MATCH (parser run against real production HTML, 84 real registered candidates) | MATCH | UI_VERIFIED via widget tests | passing | none — this session |
| **Public Job Detail** | `employer/jobs/<pk>/` | **IMPLEMENTED_NOT_VERIFIED** | GET MATCH (live-verified, real job, multi-paragraph description); apply POST code/test-verified only | MATCH | UI_VERIFIED via widget tests | passing | apply POST not live-submitted (would create a real application) |
| **Job Openings** | `employer/employer/job-openings/` | **MATCH** | MATCH (parser run against real production HTML, 80 real active jobs) | MATCH | UI_VERIFIED via widget tests (caught + fixed 1 real overflow bug); reuses Public Job Detail, no duplicate screen | passing | none — this session |
| **My Application Detail** (student-side) | `/applications/<pk>/` | **IMPLEMENTED_NOT_VERIFIED** | code/test-verified only | MATCH | UI_VERIFIED via widget tests | passing | not live-round-tripped — no test-account credentials available for a student owning a known application id |
| **Quick Apply** (`resume_apply_job`) | n/a | **NOT_APPLICABLE** | n/a | n/a | n/a | n/a | re-investigated: the endpoint exists but is referenced by zero current templates/JS (confirmed via `grep`/full git history) — its only real trigger, a "Quick Apply" form on `resume_match_result.html`, was removed from the live template at some point. Building a Flutter entry point would invent navigation the current web doesn't have |

## PHASE 12 — Final UI/Data/API parity

Not yet performed as a dedicated pass — most UI_VERIFIED rows above come
from live functional testing (real data rendered correctly), not a
side-by-side visual diff against web screenshots. Recommend this as its
own explicit pass once PHASE 2/5/8/9's IMPLEMENTED_NOT_VERIFIED items are
closed out, rather than threading it through every phase individually.

## PHASE 13 — Production E2E

Already substantially done (`docs/PRODUCTION_E2E_VERIFICATION_REPORT.md` +
this session's own direct work) for 3 of 4 accounts in depth
(`nvenkatsai`, `Testone`, `rameshn`, `Testthree` — all 4 were exercised by
the earlier background-agent pass). Re-run per-phase as each
IMPLEMENTED_NOT_VERIFIED item above gets a real implementation to verify.

## PHASE 14 — Release readiness

Unchanged from Batch 14's findings (not re-verified this session): no real
signing keystore, no Apple Developer Team, no app icon, no privacy policy,
no store metadata. Explicitly out of scope until functional parity is
closer to complete, per the user's own phase ordering.

---

## Recommended next phase

**JAM History/Profile/Delete/Reset, ARIA streaming, ARIA voice
(transcription + TTS), the ARIA language selector, the ARIA widget
global-coverage audit + rollout, the AI Mock Interview contract
re-verification, and the remaining-exercise contract re-verification
(Timer/Bingo/AI Speaking/AI Writing/AI Reading/AI Listening) are now done**
(this and the prior two sessions) — see the rows above. No genuine Flutter
bugs were found across any of the six exercise types; only a handful of
this doc's own prior-wording corrections and one minor, documented,
non-blocking UX gap (AI Speaking's missing 25-word pre-submission nudge).

**The single remaining blocker across this entire phase is a live,
authenticated test account.** AI Mock Interview, Bingo, Timer, AI Speaking,
AI Writing, AI Reading, and AI Listening are all sitting at
IMPLEMENTED_NOT_VERIFIED specifically because the one available test
credential failed a live login against production this session, and per
explicit user direction was not pursued further by guessing passwords. A
working credential (ideally one with a Normal/Pro plan and a parsed
resume, for Mock Interview specifically) would let every one of these move
to MATCH in a single follow-up pass — there is no remaining code-level work
blocking that transition. Next, pending that credential or other
direction: Skill-Up catalog/data parity, Interview Analytics, then
Subscriptions/Payments as its own controlled, explicitly-authorized phase.

**Phase 11 (Employer) is now essentially complete.** Every real web screen
in this phase has a Flutter equivalent except `job_create`/`job_edit`,
which are genuinely blocked (not simply unbuilt) by a confirmed divergence
between this repo's `JobPostingForm` and the real, live production
job-posting form, and `resume_apply_job`, correctly left unbuilt as
`NOT_APPLICABLE` (no live trigger exists on the real web to reproduce).
See the rows above for the full picture, including which items are
`UI_VERIFIED` via widget tests vs. still needing an on-device pass.

Given the matrix above, the next highest-leverage items are:

1. **Reconcile the `job_create`/`job_edit` source divergence** — not a
   Flutter task. Someone with access to whatever actually deploys
   production needs to locate the real, current `JobPostingForm`/
   `job_form.html` (Department selector, 129 categorized skill checkboxes,
   `keywords`, conditional `application_contact`, `contract-duration`) so
   this repo can be brought in sync before Post/Edit Job is attempted.
   Confirmed absent from both `main` and `origin/dev`, and from this
   repo's full git history.
2. **Step 4 of the current task** — JAM History/Profile/Delete (done), ARIA
   streaming/voice/language selector/widget global-coverage (done), AI Mock
   Interview complete flow, Interview Analytics, Skill-Up catalog/data
   parity, remaining exercise types, then Subscriptions/Payments as its own
   controlled, explicitly-authorized phase (real-money work, not started
   casually).
3. **Backend deploy of `/dashboard/api/` + `/activities/api/*`** — not a
   Flutter task, but unblocks Phases 2 and 5's largest IMPLEMENTED_NOT_VERIFIED
   items the moment it happens; worth flagging to whoever owns the Django
   deploy.
4. **On-device re-verification** of the screens still `UI_NOT_VERIFIED`
   on-device this session (`EmployerJobApplicationsScreen`, Company
   Profile, Public Job Detail, My Application Detail) — safe to redo once
   the emulator input-automation issue from earlier this session is
   sorted out.

Subscriptions/Payments (Phase 10) remains the largest gap by scope, but
stays explicitly deferred pending its own go-ahead given the real-money
nature of the work — not resumed without that, per Step 4's own
instruction not to start it casually.

**Web source modified: NO.**
