# Updated Web — Flutter Functional Parity Matrix (Phase 35)

Synthesizes: (1) the route-level gap summary from `UPDATED_WEB_COMPLETE_SCREEN_INVENTORY.md`, (2) Phase 15's `UPDATED_WEB_MOBILE_GAP_ANALYSIS.md` (18 items), re-stated with current status re-checked where this phase actually re-verified it, and (3) this phase's own corrections to Phase 33/34's prior framing. "Implemented" below means the interaction was traced through to a working request/response contract, not merely that a Flutter file or route exists — per the task's own instruction not to credit a feature as done from a file's existence alone.

## Headline finding

The single largest functional gap on the whole site is **not** a missing feature of the Manual Resume Builder (Phases 24-32) — that feature is implemented and has no web-route equivalent gap. It is a **wholly separate, unbuilt feature**: the web's free-form, single-page **"Create Resume" builder** (`career_app/create_resume_views.py`, 7 routes: preview, PDF, pages, drafts-list, draft-save, draft-detail, draft-delete), which has signed-in draft persistence and no Flutter equivalent at all. The web's actual hero "Create Resume" button (`landing.html:6552`) scrolls to *this* feature, not the Manual Resume Builder. Phase 34's choice-sheet fix (offering Manual Resume Builder + AI Parsing from the home screen) is a reasonable adaptation given no Flutter equivalent of feature (2) exists, but it does not achieve literal parity with the web's actual button destination — this should be named plainly rather than implied as resolved.

## Phase 15 gap-analysis items — current status

| # | Item | Phase 15 status | Re-verified this phase? | Current status |
|---|---|---|---|---|
| 5 | Mock Interview violation-threshold dialog hardcoded "3" | Modification required | **Yes** — `mock_interview_question_view.dart:110-111` reads `widget.state.terminateThreshold` dynamically | **Confirmed fixed**, no action needed |
| 8 | Proactive resume-parse quota counter | Partial | **Yes** — `ResumeParseQuota` confirmed wired across `resume_html_parser.dart`, `resume_repository_impl.dart`, `resume_remote_datasource.dart`, `resume_repository.dart`, `resume_builder_screen.dart` | **Confirmed implemented**, no action needed |
| 11 | Skill-Up free-plan content gating | Missing/Uncertain | Grep for plan-gating logic in `lib/features/skill_up/` returned no results | **Still appears missing** — not independently re-confirmed beyond this grep; treat as open until a full trace is done |
| 12 | TechCenter/NonITCenter content expansion | Uncertain | Not re-checked this phase | **Carry forward Phase 15 status unchanged** — not re-verified |
| 17 | Quiz-rotation / AMCAT-CoCubes grading-path uncertainty | Uncertain | Not re-checked this phase | **Carry forward Phase 15 status unchanged** — not re-verified |
| 18 | Activity-progress-percentage semantics | Uncertain | Not re-checked this phase | **Carry forward Phase 15 status unchanged** — not re-verified |
| 1-4, 6-7, 9-10, 13-16 | (remaining Phase 15 items) | Various (Aligned/Backend blocked/etc.) | Not re-checked this phase | **Carry forward Phase 15 status unchanged** — see `docs/UPDATED_WEB_MOBILE_GAP_ANALYSIS.md` for full original detail; nothing in this phase's investigation contradicts any of them |

## New functional gaps identified this phase (route-inventory-driven)

| Feature | Web route(s) | Flutter status | Priority | Notes |
|---|---|---|---|---|
| **"Create Resume" free-form builder** | `create/preview/`, `create/pdf/`, `create/pages/`, `create/drafts/` (list/save/detail/delete) | Not implemented | **P1 — highest** | A whole feature area: free-form sections, live preview, PDF export, signed-in draft persistence. Distinct from the Manual Resume Builder (which already has full Flutter parity) and from AI Resume Parsing (also already implemented). |
| Career-track landing pages | `/careers/<slug:track>/` | Not implemented | P2 | Public, unauthenticated marketing pages per career track. |
| Skill-Up free-plan content gating | server-side middleware restricting Free-plan users (confirmed to exist server-side) | Not implemented client-side | P1 | A Free-plan user tapping a gated lesson today likely hits an unhandled 403/locked response rather than a clear in-app message — a real, reachable broken state, not cosmetic. |
| Streaming TTS for Aria/Buddy | `/api/voice/tts/stream/` | Only the batch `riyaTts` endpoint is used (1.8-4s+ first-audio latency vs. ~0.5s for the streaming path) | P2 | Real, confirmed voice-response latency gap, not previously documented. |
| Resume-apply-via-parsed-data | `career_app.views.resume_apply_job` | Not implemented | P2 | "Apply to a job using your already-parsed resume" convenience flow. |
| Subscription plans page content | `career_app.views.pro_page` | Flutter has Razorpay checkout; unclear whether the *plans/pricing content itself* is sourced live or stale/hardcoded | P2 — needs verification | Should be explicitly checked before being marked done. |
| GST payment invoice download | `career_app.views.payment_invoice` | Not implemented | P2 | No in-app way for a paying student to retrieve an invoice. |
| Exercise-attempt deletion | `activities.views.delete_attempt` | Not implemented | P3 | Minor; no user-facing way to delete a stored attempt. |
| Certificate edit-name sub-flow | `skillup_assessment.views.certificate_edit_name` | Not distinctly confirmed as implemented | P3 | May be partially covered by the existing name-submit flow; needs explicit confirmation. |

## Previously-reported items reconfirmed stable (no new work needed)

- **MCQ/Matching server-side scoring contract** (the historical "correct answer scored 0" anomaly): fixed in commit `082712c` (2026-10-13), with passing `REGRESSION (Phase 16)` tests already covering the exact scenario. No regression found this phase.
- **Login timeout root cause**: fixed this phase (see `PHASE_35_LOGIN_AND_DEBUG_PREVIEW_DIAGNOSIS.md`) — a debug build's default environment, not a backend contract mismatch.
- **Debug preview button**: not a functional defect — correctly `kDebugMode`-gated, cannot appear in a release build.
- Employer portal, JAM, Group Discussion, Grammar, and the camera-gated AI mock-interview flow: route inventory found no new gaps in these areas beyond what Phase 33 already reported as comprehensive.

## What this matrix does not claim

No device-level or production-account re-verification of any item above was performed this phase beyond the specific login-timeout investigation (see the diagnosis report for exactly what was and wasn't device-verified). Every row here is source/code-verified only, unless explicitly marked otherwise. Items carried forward unchanged from Phase 15 should not be read as "confirmed still true today" — they are "not contradicted by anything found this phase," which is a weaker and more honest claim.
