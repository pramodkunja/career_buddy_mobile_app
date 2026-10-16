# Updated Web — Complete Screen and Route Inventory (Phase 35)

A systematic walk of every `urls.py` in the updated Django reference (`royalStaffing_CB01/`), cross-referenced against the Flutter app. This supersedes any earlier partial inventory for completeness — every route the root `business_english_lms/urls.py` includes (directly or transitively) is accounted for below. Compiled via direct source reading this phase, not copied from an older document. "Flutter status" records existence only (found / not found); the separate functional and visual parity matrices judge whether what exists actually works and looks right.

**Route count by Django app**: users 10 · activities (incl. roleplay) 28 · skillup_assessment (+ hub) 9 · GD_app (+ websocket) 6 · jam_app 16 · employer_portal/accounts_app/jobs_app 24 · riya_bot 8 · career_app (pro + resume-builder + manual + create) 29 · Grammar (subject_views) 5 · root misc (nav_go, media, admin, static) 8. **Total: ~143 routes.**

## users (`/users/`)

| Route | View | Method | Auth | Description | Flutter status |
|---|---|---|---|---|---|
| `/users/register/` | `register_view` | GET, POST | none | Student signup, requires prior OTP verification | found: `register_screen.dart` |
| `/users/register/send-otp/` | `send_email_otp` | POST | none | Sends registration email OTP | found: `ApiEndpoints.sendEmailOtp` |
| `/users/register/verify-otp/` | `verify_email_otp` | POST | none | Verifies OTP | found: `verifyEmailOtp` |
| `/users/login/` | `login_view` | GET, POST | none | Login, 5-attempt/15-min lockout | found: `login_screen.dart` |
| `/users/logout/` | `logout_view` | POST | none | Logout | found: `ApiEndpoints.logout` |
| `/users/profile/` | `profile_view` | GET, POST | login | Overview/Edit profile | found: `profile_screen.dart` |
| `/users/password-reset/` | `PasswordResetView` | GET, POST | none | Sends reset email | found: `forgot_password_screen.dart` |
| `/users/password-reset/done/` | `PasswordResetDoneView` | GET | none | "Check your email" | found: `check_email_screen.dart` |
| `/users/reset/<uidb64>/<token>/` | `PasswordResetConfirmView` | GET, POST | token | Validates reset token | found: `reset_password_screen.dart` |
| `/users/reset/done/` | `PasswordResetCompleteView` | GET | none | Reset complete | found: `password_reset_complete_screen.dart` |

**Status: fully mapped, no gaps.**

## activities (`/activities/` + roleplay + root)

| Route | View | Method | Auth | Description | Flutter status |
|---|---|---|---|---|---|
| `/activities/` | `activity_list` | GET | login | Lists activities, plan-gated | found: HTML-parsed |
| `/activities/workshop/` | `workshop_dashboard` | GET | login | GD/JAM/Roleplay category | found |
| `/activities/module/<slug>/` | `activity_module_redirect` | GET | login | Slug → detail redirect | not found (pure redirect convenience, not user-facing) |
| `/activities/<pk>/` | `activity_detail` | GET | login | Activity + sub-activities | found |
| `/activities/<pk>/sub/<pk>/` | `sub_activity_detail` | GET | login | Sub-activity exercises | found |
| `/activities/exercise/<pk>/` | `exercise_detail` | GET | login | Exercise page + `attempt_token` | found |
| `/activities/exercise/<pk>/submit/` | `submit_exercise` | POST | login | Generic submission/grading | found |
| `/activities/exercise/attempt/<pk>/delete/` | `delete_attempt` | POST | login | Delete a stored attempt | **not found** |
| `/activities/sub/<pk>/complete/` | `mark_sub_complete` | POST | login | Mark sub-activity complete | found |
| `/activities/exercise/<pk>/analyze/speaking/` | `analyze_speaking` | POST | login | AI speaking analysis | found |
| `/activities/exercise/<pk>/analyze/writing/` | `analyze_writing` | POST | login | AI writing analysis | found |
| `/activities/exercise/<pk>/analyze/listening/` | `analyze_listening` | POST | login | AI listening analysis, anti-replay | found |
| `/activities/exercise/<pk>/analyze/reading/` | `analyze_reading` | POST | login | AI reading analysis | found |
| `/activities/oop-quiz/questions/` + `/submit/` | `oop_quiz_*` | GET/POST | none | OOP mock quiz | found |
| `/activities/quiz/<subject>/questions/` + `/submit/` | `quiz_*` | GET/POST | none | Per-subject quiz bank | found |
| `/activities/amcat/questions/` + `/submit/` | `amcat_*` | GET/POST | none | AMCAT mock | found |
| `/activities/cocubes/questions/` + `/submit/` | `cocubes_*` | GET/POST | none | CoCubes mock | found |
| `/roleplay/` | `roleplay_home` | GET | login | Roleplay landing, plan-gated | found: `roleplay_home_screen.dart` |
| `/roleplay/practice/` | `roleplay_practice` | POST | login | Generates session content | found |
| `/roleplay/analyze/` | `analyze_roleplay` | POST | login | Scores recorded attempt | found |
| `/roleplay/<feature>/` | `roleplay_practice_view` | GET | login | Sub-feature page | found: `roleplay_practice_screen.dart` |
| `/` | `home` | GET | none | Public landing page | found: `home_screen.dart` |
| `/careers/<slug:track>/` | `career_path` | GET | none | Career-track landing page | **not found** |
| `/dashboard/` | `student_dashboard` | GET | login | Main student dashboard | found |

**Gaps**: `delete_attempt` (minor), `career_path` (career-track landing pages — no Flutter equivalent at all).

## skillup_assessment (`/skill-up/assessment/`) + Skill-Up hub

| Route | View | Method | Auth | Description | Flutter status |
|---|---|---|---|---|---|
| `/skill-up/assessment/` | `certifications_hub` | GET | login | Certifications hub | found |
| `/skill-up/assessment/api/status/` | `api_certifications_status` | GET | login | JSON status by category | found |
| `/skill-up/assessment/api/<module>/certificate/generate/` | `api_certificate_generate` | POST | login | Generate certificate PDF | found |
| `/skill-up/assessment/api/<module>/certificate/regenerate/` | `api_certificate_regenerate` | POST | login | Regenerate | found |
| `/skill-up/assessment/<module>/` | `module_detail` | GET | login | Module detail page | found |
| `/skill-up/assessment/<module>/certificate/name/` | `certificate_name_submit` | POST | login | Submit printed name | found |
| `/skill-up/assessment/<module>/certificate/edit/` | `certificate_edit_name` | GET, POST | login | Edit submitted name | **not confirmed as a distinct flow** |
| `/skill-up/assessment/<module>/certificate/download/` | `certificate_download` | GET | login | Download certificate PDF | found |
| `/skill-up/` | `skillup_hub` | GET | login, frame-embeddable | Skill Up static hub | found (locally-sourced content, not a live scrape) |

**Gap, separately flagged (Phase 15, re-confirmed this phase as still unaddressed)**: no free/paid plan content gating exists anywhere in Flutter's Skill-Up navigation, though the server-side middleware restricting Free-plan access to Aptitude/TechCenter/Non-IT-Center lessons is confirmed to exist. A Free-plan user tapping a gated lesson today would hit an unhandled 403/locked response.

## GD_app — Group Discussion (`/gd/` + WebSocket)

| Route | View | Method | Auth | Description | Flutter status |
|---|---|---|---|---|---|
| `/gd/` | `home` | GET | login | Landing, topic picker, plan-gated | found (fetched only to prime CSRF) |
| `/gd/create/` | `create_session` | POST | login | Create session, plan-gated | found |
| `/gd/room/<id>/` | `gd_room` | GET | login + ownership | Live room shell | found (page not fetched; WS used instead) |
| `/gd/report/<id>/` | `session_report` | GET | login + ownership | Performance report | found |
| `/gd/api/sessions/` | `api_sessions` | GET | login | JSON session list | found |
| `ws/GD_app/<id>/` | `GDConsumer` | WebSocket | session cookie + ownership | Live chat | found |

**Status: fully mapped, no gaps.**

## jam_app — Just A Minute (`/jam/`)

16 routes (home, dashboard, session start/start-with-topic, save-audio, session detail, history, topics, profile, assessment start/session/result, session/assessment delete, reset-progress, complete-session) — **all found** in Flutter, except `home`/`dashboard` which are deliberately not called directly (access is gated one layer up, by design, per existing code comments — not a gap).

## employer_portal + accounts_app + jobs_app (`/employer/`, `/employer-home/`, `/applications/`)

24 routes covering public employer home/job-detail/application, employer auth (login/register, both legacy-alias and real), dashboard, profile create/edit, job CRUD, applications (per-job and all), job openings, candidate search, CSV download.

**Gaps**: `resume_apply_job` (`/employer/employer/resume-apply/` — "apply using your parsed resume," no Flutter equivalent found); `job_register` legacy alias is a dead-end redirect, not applicable.

Everything else: **found**, consistent with Phase 33's own "comprehensive" assessment of this feature area.

## riya_bot — ARIA/Buddy chatbot (root-mounted `/api/riya/`, `/api/aria/`, `/api/voice/`)

| Route | Description | Flutter status |
|---|---|---|
| `/api/riya/chat/` (+ `/api/aria/chat/` alias) | Non-streaming chat reply | found |
| `/api/riya/chat/stream/` | **Streaming (SSE) reply — the real web's default, low-latency path** | found |
| `/api/voice/transcribe/` (+ alias) | Voice-to-text for chat input | found |
| `/api/voice/tts/` (+ alias) | Batch text-to-speech (base64 WAV) | found |
| `/api/voice/tts/stream/` | **Streaming TTS audio** (first audio ~0.5s vs. batch's 1.8-4s+) | **not found** — the app only uses the batch endpoint |

**Gap**: the streaming TTS endpoint is unused — a real, confirmed voice-response latency gap in the Aria/Buddy feature, not previously documented.

## career_app — Pro/Subscription, Resume Builder, Manual Resume Builder, Create Resume (root-mounted `/pro/`, `/resume-builder/`)

**Pro/Subscription** (6 routes): plans page (`pro_page` — **not found**, no Flutter screen/content match confirmed), dev-only toggle (**not found**, low priority), Razorpay order/verify (found), webhook (server-to-server, n/a), GST invoice (`payment_invoice` — **not found**, no in-app way to retrieve a payment invoice).

**Resume Builder / Mock Interview** (14 routes): upload/match/history/reanalyze, full camera-gated AI interview flow (start/camera-verified/violation state+record/get-question/submit-answer/analytics) — **all found**, except `resume_interview_chat` (an HTML SPA shell Flutter deliberately replaces with native UI) and `resume_transcribe_answer` (deliberately replaced by on-device `speech_to_text`) — both intentional, documented adaptations, not gaps.

**Manual Resume Builder** (4 routes — `manual/roles/`, `manual/preview/`, `manual/pdf/`, `manual/pages/`): **all found** (Phases 24-32).

**Create Resume — the free-form builder** (7 routes: `create/preview/`, `create/pdf/`, `create/pages/`, `create/drafts/` list/save/detail/delete): **none found**. This is a complete, separate, signed-in-draft-persisting feature with no Flutter equivalent at all — see the visual audit and roadmap for why this is the single largest confirmed gap.

## Grammar (`/subject/`)

5 routes (index, topic detail, slide image, video, SVG illustration) — **all found** (`grammar_index_screen.dart`/`grammar_detail_screen.dart`, using bundled static content rather than a live scrape, consistent with this feature's established architecture).

## Root-level misc

`nav_go` (web-only navigation-gateway shim, not needed in a native app), 4 protected-media-serving routes (internal, not applicable), Django admin, favicon/legacy static redirects (not applicable).

## Gap summary — ranked, real candidate gaps only

1. **The entire "Create Resume" free-form builder (7 routes)** — the single largest gap, a whole unbuilt feature area with its own signed-in draft persistence, template switching, and live preview/PDF. The current home-screen CTA (Phase 34) works around this by offering the two features that *do* exist instead.
2. **Career-track landing pages** (`/careers/<slug:track>/`) — no Flutter equivalent.
3. **Skill-Up free-plan content gating** — confirmed missing; a real, reachable error state for Free-plan users today.
4. **Streaming TTS** (`/api/voice/tts/stream/`) — a real voice-latency gap in Aria/Buddy.
5. **Resume-apply-via-parsed-data** (`resume_apply_job`) — no Flutter equivalent.
6. **Subscription plans page content** (`pro_page`) — worth confirming the pricing/plans screen's content is actually sourced from somewhere real, not stale/hardcoded.
7. **GST payment invoice download** (`payment_invoice`) — students who upgrade have no in-app way to retrieve an invoice.
8. Lower priority: exercise-attempt deletion, the pro-status dev toggle, the certificate-name-edit sub-flow.

No web-only, non-mobile-relevant route (admin, webhook, protected-media-serving, the `nav_go` desktop-menu shim) is treated as a gap — these are correctly out of scope for a native app, not overlooked.
