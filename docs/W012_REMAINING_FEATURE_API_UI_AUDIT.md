# W012 — Remaining Feature/API/UI Audit

This document is a read-only audit. No Django/web file was modified to produce it. No Flutter file was modified. No database write occurred.

## 1. Executive Summary

68 screens/features were inventoried by direct source inspection (Django views/models/URLs/templates/JS/CSS on the web side; `lib/` on the Flutter side), plus the two provided documents (`API_Triggering.docx`, `static.docx`) as audit inputs — with actual web code treated as authoritative wherever the two disagreed (5 explicit conflicts documented in §3).

**24 COMPLETE** (auth/dashboard/activities navigation, all 4 already-implemented generic exercise types, all 4 AI modules, all 4 mock tests, the Dashboard's Recommended Jobs card, Demo Mode, and the routing for curriculum activities #21-24 which is built and correct but has no live data to render).
**24 PARTIAL** (the 20 numbered curriculum activities #1-9/#11-14/#16-20 whose final sub-activity needs the still-unbuilt Generic Writing/Timer types, plus #10/#15 which are architecturally ready but data-blocked, plus Group Discussion/JAM/Roleplay which are listed but not interactive, plus Interview Analytics whose score is consumed but whose screen doesn't exist).
**18 NOT_STARTED** (Register/Password-Reset placeholders, Generic Writing, Generic Timer, Riya Chatbot, Resume upload/ATS/History, AI Interview, Skill-Up content browsing, Sitemap, Grammar, Certificates, Jobs standalone browse, Subscriptions, and the three Employer Portal entries).
**1 DEAD** (Ordering — re-confirmed from source, not implemented).
**1 N/A** (Landing Page — not applicable to this app's post-login architecture).

The single most important finding of this pass: **the remaining curriculum content is not blocked by missing Flutter architecture.** Every one of the 20 numbered activities' exercises uses only the 6 exercise types already known to the model (`mcq`/`fill_blank`/`matching`/`bingo`/`writing`/`timer`) — 4 of which are already fully implemented. Building **Generic Writing** alone (the same proven HTML-extraction + generic-submit pattern already used 3×, now further clarified to be server-*AI*-authoritative rather than client-authoritative) unlocks the AI-triggering sub-activity of 15 of the 20 activities outright; the remaining 5 need Generic Timer too. #10 and #15 need no new exercise-type work at all — only real database rows, which this project is explicitly forbidden from creating.

Five document-vs-actual-web conflicts were found (§3): Dashboard "static" claim (actually a real dynamic API — already correctly implemented in Flutter), Skill-Up mock tests "static" claim (actually the same live, already-implemented AMCAT/CoCubes/OOP/Subject-Quiz APIs), the chatbot's claimed per-activity description capability (it only navigates by title, doesn't recite descriptions), Employer Portal's claimed AI job-description resume matching (it's deterministic keyword/regex text scoring against a manually-typed query, and offer-letter generation doesn't exist at all), and Grammar's "static" characterization (content is static, delivery is a real authenticated Django view with dynamic video/slide serving).

Two genuinely backend-blocked items were found: the `color_class` field (Activity Progress/Detail icon theming) is simply absent from `activity_list_api`/`activity_detail_api`'s JSON, and Ordering has no rendering path on the web at all. Nothing else audited this pass requires a backend change — every other NOT_STARTED item has a real, already-existing endpoint or HTML-embedded-data mechanism available to it.

## 2. Project Safety Verification

- Web project: unchanged (verified via `git status --short` before and will be re-verified after this audit).
- Backend: unchanged — no view, model, URL, template, JS, or CSS file was edited.
- Database: unchanged — `Activity: 0`, `SubActivity: 0`, `Exercise: 0` (re-verified at the end of this task).
- No API created.
- No seed data created, no migrations run, no fixtures created.

## 3. Document vs Actual Web Conflicts (reported first — load-bearing for the rest of this audit)

### Conflict 1 — Dashboard
**DOCUMENT** (`static.docx`): "The score, activities attempted, in progress and the progress bar of attempted activities, the job recommendations after passing ai interview are all static."
**ACTUAL WEB**: `dashboard_api` (`activities/views.py`) is a real, session-authenticated `GET /dashboard/api/` JSON endpoint that computes `stats`, `activities`, `recent_results`, `recommended_jobs`, `payment_history`, `interview_score` from the database per-request — genuinely dynamic, not static.
**AUTHORITATIVE BEHAVIOR**: Dynamic, API-driven. Flutter's existing `DashboardRepositoryImpl`/`DashboardController` already correctly call this real endpoint and render its live response (verified in earlier phases of this project and re-confirmed this session). No change needed or made.

### Conflict 2 — Skill-Up Mock Tests
**DOCUMENT** (`static.docx`): "The entire courses, lessons, mock tests and score evaluations present in Skill-up sections ... are static."
**ACTUAL WEB**: The four currently-implemented mock tests (OOP, Subject Quiz, AMCAT, CoCubes) are backed by real JSON APIs (`oop_quiz_questions`/`oop_quiz_submit`, `quiz_questions`/`quiz_submit`, `amcat_questions`/`amcat_submit`, `cocubes_questions`/`cocubes_submit` — all in `activities/views.py`, all under `activities/urls.py`), with server-side random question selection (a random subset of a larger bank per attempt) and server-side grading. These are **not** the same "Skill-Up" content the document describes navigating to via the Sitemap — see §11 (Skill-Up) for the distinction between this real API-backed mock-test system and the separate, genuinely-static Skill-Up browsing pages under `static/001 Career Buddy/`.
**AUTHORITATIVE BEHAVIOR**: The four implemented mock tests are dynamic, API-driven, server-graded. Flutter's existing implementation already correctly calls these real endpoints. No change needed or made. The document's "static" claim is only accurate for the *separate* Skill-Up content-browsing pages (guides/lessons), not for these four mock tests.

### Conflict 3 — "Chatbot describes every activity"
**DOCUMENT** (`API_Triggering.docx`): "Along with chatbot functionality to describe each and every activity."
**ACTUAL WEB**: Riya's knowledge is a static, hand-written category-level summary (`APP_KNOWLEDGE_BASE`, `riya_bot/riya_assistant.py:2091-2129`) plus a separate activity-*navigation* matcher (`resolve_activity_navigation_payload`, `riya_bot/riya_assistant.py:1434-1633+`) that queries only `Activity`/`SubActivity` `id`/`title`/`category`/`order` to route a phrase like "go to negotiation and meetings" to the right screen — it does not read or recite each activity's own description/objective content.
**AUTHORITATIVE BEHAVIOR**: The chatbot can *navigate to* any activity by title/category keyword match, but does not individually "describe" each one from a per-activity content source. Documented as a discrepancy; not a Flutter concern (chatbot is unimplemented in Flutter — see §11).

### Conflict 4 — Employer Portal candidate filtering
**DOCUMENT** (`API_Triggering.docx`): "API call is made to filter all the resumes to match the job description, so employers can select candidates and proceed to interview and produce offer letters to them."
**ACTUAL WEB**: `search_candidates` (`jobs_app/views.py:1065-1089`) is a normal, session-authenticated Django **HTML view** (not a separate/external API), and the matching itself (`search_registered_candidates`, `jobs_app/views.py:883-1062`) is deterministic keyword/regex text scoring against a free-text `q` skill query the employer types — not a comparison against a specific job posting's `description` field, and not an AI/ML matching call. "Offer letters" do not exist as a generated-document feature anywhere in source — grepped for "offer letter"/"offer_letter"/"OfferLetter"/"generate_offer" across the entire web project with zero matches; `JobApplication.STATUS_CHOICES` merely includes an `'offered'` status label an employer can set, which triggers a generic status-change email, not a document.
**AUTHORITATIVE BEHAVIOR**: Candidate search is real (an authenticated Django page + regex-based server-side filtering), but is not literally "filter resumes to match the job description" (it matches a manually-typed skill query, not a job's description text) and offer-letter generation does not exist at all. Not currently in scope for Flutter (see §14.I).

### Conflict 5 — Grammar
**DOCUMENT** (`static.docx`): "All the 9 types of grammar modules present are static and are informative type."
**ACTUAL WEB**: The 9 topics' *content* is indeed hardcoded (Python dicts, not DB rows) — the count of 9 matches exactly. But *delivery* is a real, `@login_required`-gated Django app (`subject_home`/`subject_topic`), including dynamically-served protected video and server-generated SVG slide illustrations per topic.
**AUTHORITATIVE BEHAVIOR**: Content is static; access/delivery mechanism is a real authenticated Django feature, not a plain static HTML page. Not currently in scope for Flutter (unimplemented either way).

A note on methodology: this audit's inventory below counts every genuinely distinct screen/feature found by direct source inspection. The task brief's "67" is treated as an estimate, not a target — no item was invented or padded to reach that number, per the no-hallucination requirement. The actual count is stated in the Executive Summary.

## 4. Complete Inventory

| # | Module | Feature | Web Route | Flutter Route | Classification | Status | API | Flutter Coverage | Priority |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Auth | Login | `/users/login/` | `/login` | B — API/Backend | COMPLETE | `POST /users/login/` (session) | Full | — |
| 2 | Auth | Register (Candidate) | `/users/register/` | `/register` | B | NOT_STARTED (placeholder) | `POST /users/register/` (exists, unused by Flutter) | Placeholder only | P2 |
| 3 | Auth | Password Reset | `/users/password-reset/` | `/password-reset` | B | NOT_STARTED (placeholder) | Django auth password reset flow | Placeholder only | P2 |
| 4 | Dashboard | Student Dashboard | `/dashboard/` | `/dashboard` | B | COMPLETE | `GET /dashboard/api/` | Full | — |
| 5 | Activities | Activities List | `/activities/` | `/activities` | B | COMPLETE | `GET /activities/api/` | Full | — |
| 6 | Activities | Activity Detail | `/activities/<id>/` | `/activities/:id` | B | COMPLETE | `GET /activities/api/<id>/` | Full | — |
| 7 | Activities | Sub-Activity Detail | `/activities/<id>/sub/<id>/` | `/activities/sub/:id` | B | COMPLETE | `GET /activities/api/sub/<id>/` | Full | — |
| 8 | Exercise | MCQ | `/activities/exercise/<id>/` (mcq branch) | `/activities/exercise/:id` | B | COMPLETE | `GET/POST /activities/api/exercise/<id>/[submit/]` | Full | — |
| 9 | Exercise | Fill in the Blank | same URL, fill_blank branch | `/activities/exercise/:id/fill-blank` | D — HTML/Embedded | COMPLETE | `questions-data` extraction + `POST submit_exercise` | Full | — |
| 10 | Exercise | Matching | same URL, matching branch | `/activities/exercise/:id/matching` | D | COMPLETE | `questions-data` extraction + `POST submit_exercise` | Full | — |
| 11 | Exercise | Bingo | same URL, bingo branch | `/activities/exercise/:id/bingo` | D | COMPLETE | `bingo-data` extraction + `POST submit_exercise` | Full | — |
| 12 | Exercise | Generic Writing | same URL, writing branch | none | D | NOT_STARTED | `questions-data` extraction + `POST submit_exercise` (AI-regraded) | None | P1 |
| 13 | Exercise | Generic Timer | same URL, timer branch | none | E — Browser-only | NOT_STARTED | `questions-data` extraction + `POST submit_exercise` (AI-regraded) | None | P2 (STT gap) |
| 14 | Exercise | Ordering | icon only, no content branch | none | F — Dead | DEAD | N/A | N/A | DEAD |
| 15 | Workshop | Workshop Dashboard | `/activities/workshop/` | `/activities/workshop` | B | COMPLETE | `GET /activities/api/` (category filter) | Full | — |
| 16 | AI Module | AI Speaking | `/activities/exercise/<id>/` (module template) | `/activities/exercise/:id/speaking` | C — Hybrid (static prompts + real submit API) | COMPLETE | `POST .../analyze/speaking/` | Full | — |
| 17 | AI Module | AI Writing | same pattern | `/activities/exercise/:id/writing` | C | COMPLETE | `POST .../analyze/writing/` | Full | — |
| 18 | AI Module | AI Listening | same pattern | `/activities/exercise/:id/listening` | D + C | COMPLETE | HTML token extraction + `POST .../analyze/listening/` | Full | — |
| 19 | AI Module | AI Reading | same pattern | `/activities/exercise/:id/reading` | C | COMPLETE | `POST .../analyze/reading/` | Full | — |
| 20 | Mock Test | OOP Mastery | `/activities/oop-quiz/` | `/mock-tests/oop-mastery` | B | COMPLETE | `GET/POST oop-quiz/questions|submit/` | Full | — |
| 21 | Mock Test | Subject Quiz (~24 subjects) | `/activities/quiz/<subject>/` | `/mock-tests/subject/:subject` | B | COMPLETE | `GET/POST quiz/<subject>/questions|submit/` | Full | — |
| 22 | Mock Test | AMCAT | `/activities/amcat/` | `/mock-tests/amcat` | B | COMPLETE | `GET/POST amcat/questions|submit/` | Full | — |
| 23 | Mock Test | CoCubes | `/activities/cocubes/` | `/mock-tests/cocubes` | B | COMPLETE | `GET/POST cocubes/questions|submit/` | Full | — |
| 24 | Curriculum Activity 1 | Elevator Pitch Workshop | `/activities/1/` | generic activity flow | B (generic mcq/fill_blank/timer exercises) | PARTIAL (generic flow ready; timer sub-exercise blocked on STT) | Generic activities/exercise APIs | Covered by #5-13 once DB seeded | BLOCKED (no DB data) |
| 25 | Curriculum Activity 2 | Business Negotiation Simulation | `/activities/2/` | generic activity flow | B (matching/mcq/writing) | PARTIAL | Generic APIs | Covered once seeded; writing sub-exercise = #12 | BLOCKED |
| 26 | Curriculum Activity 3 | Professional Email Communication | `/activities/3/` | generic activity flow | B (matching/fill_blank/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 27 | Curriculum Activity 4 | Case Study Analysis and Presentation | `/activities/4/` | generic activity flow | B (mcq/writing/matching) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 28 | Curriculum Activity 5 | Meeting Management Workshop | `/activities/5/` | generic activity flow | B (mcq/fill_blank/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 29 | Curriculum Activity 6 | Job Interview Mastery | `/activities/6/` | generic activity flow | B (mcq/fill_blank/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 30 | Curriculum Activity 7 | Business Report Writing | `/activities/7/` | generic activity flow | B (matching/fill_blank/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 31 | Curriculum Activity 8 | Cross-Cultural Communication | `/activities/8/` | generic activity flow | B (mcq×2/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 32 | Curriculum Activity 9 | Product Launch Planning | `/activities/9/` | generic activity flow | B (mcq/matching/timer) | PARTIAL | Generic APIs | Covered once seeded; timer = #13 | BLOCKED |
| 33 | Curriculum Activity 10 | Business Telephone and Video Calls | `/activities/10/` | generic activity flow | B (matching/fill_blank/mcq — no AI-triggering exercise) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 34 | Curriculum Activity 11 | Financial Literacy and Reporting | `/activities/11/` | generic activity flow | B (matching/mcq/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 35 | Curriculum Activity 12 | Business Correspondence | `/activities/12/` | generic activity flow | B (mcq/fill_blank/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 36 | Curriculum Activity 13 | Networking and Small Talk | `/activities/13/` | generic activity flow | B (mcq/fill_blank/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 37 | Curriculum Activity 14 | Handling Complaints and Conflict Resolution | `/activities/14/` | generic activity flow | B (matching/mcq/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 38 | Curriculum Activity 15 | Business Vocabulary Building Games | `/activities/15/` | generic activity flow | B (mcq/bingo/fill_blank — no AI-triggering exercise) | PARTIAL | Generic APIs | Covered once seeded (all 3 types already implemented!) | BLOCKED (only by DB data) |
| 39 | Curriculum Activity 16 | Proposal and Bid Writing | `/activities/16/` | generic activity flow | B (mcq/writing/timer) | PARTIAL | Generic APIs | Covered once seeded; timer = #13 | BLOCKED |
| 40 | Curriculum Activity 17 | Data Presentation and Visualization | `/activities/17/` | generic activity flow | B (matching/mcq/timer) | PARTIAL | Generic APIs | Covered once seeded; timer = #13 | BLOCKED |
| 41 | Curriculum Activity 18 | Business Idioms and Phrasal Verbs | `/activities/18/` | generic activity flow | B (matching/fill_blank/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 42 | Curriculum Activity 19 | Corporate Social Responsibility Debate | `/activities/19/` | generic activity flow | B (matching/mcq/writing) | PARTIAL | Generic APIs | Covered once seeded | BLOCKED |
| 43 | Curriculum Activity 20 | Project Status Update and Reporting | `/activities/20/` | generic activity flow | B (fill_blank/writing/timer) | PARTIAL | Generic APIs | Covered once seeded; timer = #13 | BLOCKED |
| 44 | AI Module (curriculum #21) | Professional Passage Writing | `/activities/21/` | `/activities/exercise/:id/writing` | C | COMPLETE (routing verified) | `POST .../analyze/writing/` | Full — once seeded | BLOCKED (only by DB data) |
| 45 | AI Module (curriculum #22) | Listen & Write | `/activities/22/` | `/activities/exercise/:id/listening` | D + C | COMPLETE (routing verified) | Token extraction + `POST .../analyze/listening/` | Full — once seeded | BLOCKED |
| 46 | AI Module (curriculum #23) | Professional Reading | `/activities/23/` | `/activities/exercise/:id/reading` | C | COMPLETE (routing verified) | `POST .../analyze/reading/` | Full — once seeded | BLOCKED |
| 47 | AI Module (curriculum #24) | Professional Speaking | `/activities/24/` | `/activities/exercise/:id/speaking` | C | COMPLETE (routing verified) | `POST .../analyze/speaking/` | Full — once seeded | BLOCKED |
| 48 | Workshop (curriculum #25) | Group Discussion | `/activities/25/` (category=workshop) | Activities/Workshop list only | H | PARTIAL (listed, not interactive) | `activity_list_api` | Card only, no session flow | P2 |
| 49 | Workshop (curriculum #26) | JAM | `/activities/26/` | Activities/Workshop list only | H | PARTIAL | `activity_list_api` | Card only | P2 |
| 50 | Workshop (curriculum #27) | Roleplay | `/roleplay/` + `/activities/27/` | Activities/Workshop list only | B (generate+analyze APIs exist) | PARTIAL | `roleplay_practice`/`analyze_roleplay` | Card only, no practice flow | P1 |
| 51 | Chatbot | Riya / "Buddy" Assistant | global widget (`includes/aria_assistant.html`, every page) | none | B (SSE + JSON) | NOT_STARTED | `POST /api/riya/chat/[stream/]`, `/api/voice/transcribe/`, `/api/voice/tts/` | None | P2 |
| 52 | Resume | Resume Upload + JD Match | `/resume-builder/match/` | none | B | NOT_STARTED | `POST /resume-builder/match/` (multipart) | None | P2 |
| 53 | Resume | ATS Score Result | `/resume-builder/match/` (same view, result render) | none | B | NOT_STARTED | same as #52 | None | P2 |
| 54 | Resume | Resume History | `/resume-builder/history/` (view name `resume_history`) | none | B | NOT_STARTED | Django view, session/DB list | None | P3 |
| 55 | AI Interview | Resume-based AI Interview | `/resume-builder/start-interview/` + `/resume-builder/interview/chat/` | none | B | NOT_STARTED | `resume_start_interview`, `resume_get_next_question`, `resume_submit_answer`, `resume_transcribe_answer`, `resume_upload_interview_video` | None | P3 (gated behind Resume upload + paid plan) |
| 56 | Interview Analytics | Interview Result/Analytics | `/resume-builder/interview/analytics/...` (view `resume_analytics`) | none (only `interview_score` consumed on Dashboard) | B | PARTIAL (score consumed, screen not built) | Django view | `interview_score` field only, via Dashboard | P3 |
| 57 | Skill-Up | Skill-Up content browsing (English & Vocab / Aptitude / Tech / Certifications) | `/skillup/` + `static/001 Career Buddy/*` static HTML | none | A — Static | NOT_STARTED | none (static files) | None | P3 |
| 58 | Skill-Up | Sitemap | `/sitemap/` (or similar) | none | A | NOT_STARTED | none | None | P3 |
| 59 | Content | Grammar (9 types) | grammar routes/templates | none | A | NOT_STARTED | none (see §11.F for per-type detail) | None | P3 |
| 60 | Content | Certificates | `skillup_assessment` app (`certificate_name_submit`/`certificate_edit_name`/`certificate_download`/`api_certificate_generate`) | none | B | NOT_STARTED | Real, server-eligibility-gated (score ≥70% via `QuizAttempt`) PDF generation | None | P3 |
| 61 | Jobs | Jobs / Recommended Jobs (Dashboard card) | part of `/dashboard/` | Dashboard's `RecommendedJobsSection` | B | COMPLETE | `GET /dashboard/api/` (`recommended_jobs`) | Full | — |
| 62 | Jobs | Standalone Job Browse/Apply | `employer_portal:job_openings`, job detail/apply | `RoutePaths.jobDetail` (placeholder) | B | NOT_STARTED | `job_openings`, apply view | Placeholder only | P2 |
| 63 | Subscriptions | Plan/Pricing + Razorpay Payment | `/pro/` + Razorpay order/webhook views | `RoutePaths.pro` (placeholder) | B | NOT_STARTED | Razorpay order-create + verify/webhook views | Placeholder only | P1 |
| 64 | Employer Portal | Employer Login/Register | `employer_portal:employer_login`/`employer_register` | `RoutePaths.employerLogin` (placeholder) | B | NOT_STARTED | `EmployerLoginView`, `employer_register` | Placeholder only | P3 |
| 65 | Employer Portal | Employer Dashboard | `employer_portal:dashboard` | none | B (HTML, not JSON) | NOT_STARTED | `employer_dashboard` | None | OUT OF SCOPE (see §14.I) |
| 66 | Employer Portal | Candidate Search | `employer_portal:search_candidates` | none | B (HTML, not JSON) | NOT_STARTED | `search_candidates` | None | OUT OF SCOPE |
| 67 | Landing | Landing/Home Page | `/` (pre-login) | N/A — app starts at Login | A | N/A | none | Not applicable to a logged-in mobile app | N/A |
| 68 | Demo Mode | Direct Demo Entry + Debug Toggle | N/A (Flutter-only, mirrors no web route) | `/demo` | H (Flutter-internal) | COMPLETE | N/A | Full | — |

*(68 rows resulted from exhaustive, evidence-based listing — not forced to exactly 67; see the methodology note above.)*

## 5. Detailed API Matrix

Only endpoints already implemented in Flutter, or genuinely relevant to a near-term implementation decision, are itemized field-by-field here (the full inventory above covers every route at a higher level).

| Feature | Endpoint | Method | Auth | CSRF | Request | Response | Trigger | Flutter Mapping | Status |
|---|---|---|---|---|---|---|---|---|---|
| Login | `/users/login/` | POST | session (anon before) | required | form-encoded username/password | session cookie set | Sign In tap | `AuthRemoteDataSource` | CORRECT |
| Dashboard | `/dashboard/api/` | GET | session | n/a (GET) | none | `stats, activities, recent_results, recommended_jobs, payment_history, interview_score` | screen load | `DashboardRepositoryImpl` | CORRECT |
| Activities list | `/activities/api/` | GET | session | n/a | `?category=` | `activities[], categories[], selected_category, is_free_preview, total_activities` | screen load / category tap | `ActivitiesRepositoryImpl` | CORRECT |
| Activity detail | `/activities/api/<id>/` | GET | session | n/a | path id | `id, title, description(=objective), category, level, duration, is_workshop, is_module, completion_rate, sub_activities[]` | card tap | `ActivitiesRepositoryImpl` | CORRECT |
| Sub-activity detail | `/activities/api/sub/<id>/` | GET | session | n/a | path id | `id, title, description, instructions, exercises[], status, all_exercises_done` | sub-activity tap | `ActivitiesRepositoryImpl` | CORRECT |
| MCQ read | `/activities/api/exercise/<id>/` | GET | session | n/a | path id | `exercise{}, sub_activity{}, activity{}, questions[]` (no `correct`) | exercise tap | `McqExerciseRemoteDataSource` | CORRECT |
| MCQ submit | `/activities/api/exercise/<id>/submit/` | POST | session | required | `{answers:{qid:letter}}` | `exercise_id, score, max_score, percentage, attempt_number, questions[]` (server-authoritative) | Submit tap | `McqExerciseRemoteDataSource` | CORRECT |
| Generic submit (Fill Blank/Matching/Bingo/**Writing**/**Timer**) | `/activities/exercise/<id>/submit/` | POST | session | required | `{score, max_score, answers:{...}}` (client-computed, except writing/timer which the server overrides) | `status, score, max_score, percentage, attempt, customSummaryHtml` | Submit tap | `*ExerciseRemoteDataSource` (fill_blank/matching/bingo done; writing/timer not built) | CORRECT (3 of 5 types built) |
| AI Speaking | `POST .../analyze/speaking/` | POST | session | required | multipart: `audio, duration_seconds, pause_count, client_transcript, language, reference_text` | `success, data{score_25,...}` | Submit recording | `AiSpeakingRemoteDataSource` | CORRECT |
| AI Writing | `POST .../analyze/writing/` | POST | session | required | multipart: `text, language, reference_text, previous_improved_passage?` | `success, score_25(top-level), data{...}` | Submit tap | `AiWritingRemoteDataSource` | CORRECT |
| AI Listening | `POST .../analyze/listening/` | POST | session | required | multipart: `text, reference_text, duration_seconds, pause_count, attempt_token, language` | `success, data{score_25, content_match_percent,...}` | Submit tap | `AiListeningRemoteDataSource` | CORRECT |
| AI Reading | `POST .../analyze/reading/` | POST | session | required | multipart: `audio, duration_seconds, pause_count, client_transcript, reference_text, language` | `success, score_25(top+nested), data{...}` | Submit recording | `AiReadingRemoteDataSource` | CORRECT |
| Mock Tests ×4 | `GET .../questions/`, `POST .../submit/` | GET/POST | **none required** | `@csrf_exempt` on submit | none / `{answers per section}` | flat question bank / server-graded result | screen load / Submit | All 4 implemented | CORRECT |
| Riya chat | `POST /api/riya/chat/` | POST | **none** (works anonymous) | `@csrf_exempt` | `message, page, path, hash, input_mode, language, want_audio` | `success, reply, message, actions, source, language, speak, audio` | user sends message | **not built** | MISSING |
| Riya chat (streaming) | `POST /api/riya/chat/stream/` | POST | none | exempt | same + `history[]` | SSE: `{"t": token}`… `{"done": true, reply, actions, source}` | user sends message | not built | MISSING |
| Riya voice | `POST /api/voice/transcribe/`, `POST /api/voice/tts/` | POST | none | exempt | audio/base64 or text | transcript / audio | mic tap / reply | not built | MISSING |
| Resume upload+match | `POST /resume-builder/match/` | POST | session, plan-gated | required | multipart `file`, optional `text` (JD) | rendered HTML (`match_percentage, matching_skills, missing_skills, analysis, career_advice, years_exp, can_interview`) | Upload tap | not built | MISSING |
| AI Interview start | `POST /resume-builder/start-interview/` | POST | session, plan+resume gated | required | none | redirect to interview chat | after resume parsed | not built | MISSING |
| AI Interview question/answer | `resume_get_next_question` (GET), `resume_submit_answer` (POST), `resume_transcribe_answer` (POST) | mixed | session | required | per-question payload / audio | question text / `{score 0-5, feedback}` / transcript | question flow | not built | MISSING |
| Razorpay order | `POST /pro/create-order/` | POST | session, rate-limited 10/min | required | `plan_type` | `success, order_id, amount, currency, key_id, plan_type, plan_label, user_name, user_email` | Upgrade tap | not built | MISSING |
| Razorpay verify | `POST /pro/verify-payment/` | POST | session | required | `plan_type, razorpay_payment_id, razorpay_order_id, razorpay_signature` | `{success, plan_type}` | after Razorpay checkout callback | not built | MISSING |
| Job apply (public) | `GET/POST employer_portal:job_detail` | GET/POST | **GET public**, POST accepts anon or session | required | job id + applicant fields + resume file | rendered HTML | Apply tap | not built | MISSING |
| Job apply (quick, logged-in) | `POST resume_apply_job` | POST | session | required | job_id + applicant fields (resume pulled from session) | rendered HTML/redirect | Apply tap | not built | MISSING |
| Employer candidate search | `GET employer_portal:search_candidates` | GET | session + `portal=employer` flag | n/a (GET) | `q, location, experience` | rendered HTML, ranked candidate list | search submit | not built, **out of scope** | N/A |

## 6. Static Content Matrix

| Item | Hardcoded in HTML? | Django-generated? | DB-loaded? | JS data? | API data? |
|---|---|---|---|---|---|
| Landing page testimonials + "5 Simple Steps" | Yes, hardcoded (`home.html:1490-1611`) | — | No | No | No |
| Landing page "Featured Activities" row | No | Yes — `home()` (`activities/views.py:76-88`) queries `Activity.objects.filter(is_active=True)...[:6]` | Yes | No | No (server-rendered context, not a JSON API) |
| Skill-Up course/lesson content (English&Vocab/Aptitude/Tech/CEFR/Phonics guides) | Yes — static HTML files under `static/001 Career Buddy/`, served verbatim by `skillup_hub()` reading the file off disk (`riya_bot/skillup_views.py:37,53`) | No DB query for the content itself | No | Client-side hash routing (`#load=...`) | No |
| Skill-Up **mock tests** (embedded in the same static bundle, e.g. AMCAT) | No | — | No | Calls the **same live** `activities/quiz/<subject>/submit/`, `amcat/submit/`, `cocubes/submit/` endpoints (`mock_test.js:7,470`) as the already-implemented dynamic system | **Yes — real, live API** (same system as #20-23), directly contradicting `static.docx`'s blanket claim — see Conflict 2 |
| Sitemap | Yes — a section inside the same static `index.html` (`<!-- SITEMAP -->`), no `{% for %}` loop, no DB query | No | No | No | No |
| Grammar (9 types: noun/pronoun/verb/adjective/adverb/conjunction/tenses/sentence-structure/types-of-sentences) | Content itself: yes, hardcoded Python dicts (`SUBJECT_TOPIC_CARDS`/`SUBJECT_TOPICS`, `subject_views.py:35,110`) | **But delivery is a real, `@login_required`, auth-gated Django view** (`subject_home`/`subject_topic`, `subject_views.py:1604,1616`), plus dynamically-served protected video and on-the-fly-generated SVG slide illustrations (`subject_video`/`_build_illustration_svg`, `subject_views.py:1526,1643`) | No (Python dict, not DB) | No | No — but the delivery mechanism is not "pure static HTML," it's an authenticated Django app; `static.docx`'s characterization undersells this |
| Mock Test question banks (OOP/Subject/AMCAT/CoCubes) | No — flat JSON files loaded server-side, served via real GET APIs | Yes (`_load_bank`/`_amcat_bank`/`_cocubes_bank` read JSON files server-side) | No (file-based bank, not DB rows) | No | **Yes — real API**, contradicting `static.docx`'s claim (see Conflict 2) |
| Exercise instructions (`exercise.instructions`) | N/A | Would be DB-loaded if populated | Yes (`Exercise.instructions` field exists) | No | Via `sub_activity_detail_api`/HTML, **but never actually rendered on the exercise-taking page for any type** (confirmed by grep — a real, pre-existing web omission, not a Flutter gap) |
| AI-module static prompt lists (Speaking topics, Writing/Reading prompts) | Yes — hardcoded directly in the module JS/templates, not DB-sourced | No | No | Yes | No |

## 7. HTML / Embedded-Data Matrix

| Case | Template | Element | Data Structure | JS Reader | Flutter Strategy | JSON API Exists? | Backend Change Needed? |
|---|---|---|---|---|---|---|---|
| Fill in the Blank questions | `exercise.html` | `<script id="questions-data">` | `[{id,text,type,options,correct,explanation,left,right}]` | `QUESTIONS_DATA` global | Extract via GET + regex on script tag id — **implemented** | No | No |
| Matching pairs | same | same tag | same shape (`left`/`right` populated) | same | **implemented** | No | No |
| Bingo cards | same | `<script id="bingo-data">` | `[{word,definition}]` | `BINGO_DATA` | **implemented** | No | No |
| Generic Writing prompts | same | `<script id="questions-data">` | same shape (`text`/`explanation` populated) | `QUESTIONS_DATA` | Same extraction mechanism already proven 3×; **not yet implemented** | No | No |
| Generic Timer prompts | same | `<script id="questions-data">` | same shape | `QUESTIONS_DATA` | Same extraction; input method (typed vs STT) is the open question | No | No |
| AI Listening attempt token | `templates/activities/modules/listening.html` | `<script id="listening-config">` | `{attemptToken,...}` | `lv.readConfig('listening-config')` | **implemented** (`extractEmbeddedJsonConfig`) | No | No |
| Resume interview analytics data | `resume_analytics.html` | `<script type="application/json">` | per-question topic/difficulty/question/answer/score/feedback list | inline `json_data` | Not yet implemented | No (page is otherwise mostly server-rendered) | No |

## 8. Browser-Only Matrix

| Feature | Web Technology | Purpose | Flutter Equivalent In Use | Matches? | Missing | Mobile Limitation |
|---|---|---|---|---|---|---|
| Generic Timer transcript | `webkitSpeechRecognition`/`SpeechRecognition` | produce the text that gets graded | none | No | Speech-to-Text capability | Would need a new third-party STT plugin, or a disclosed typed-input adaptation |
| Bingo definition read-aloud | `window.speechSynthesis` | UX nicety, not graded | `flutter_tts` (already a dependency, already used) | Yes | — | none — already solved |
| AI module audio playback (Listening) | HTML5 `<audio>` | play back narration | `flutter_tts` narration (text-to-speech, not audio playback of a file — the "story" is narrated client-side from text on both platforms) | Yes | — | none |
| AI Speaking/Reading mic capture | `getUserMedia`+`MediaRecorder` | record + upload audio for AI grading | native mic recording via existing `AudioRecorderService` (already implemented) | Yes | — | none — already solved |
| Timer's raw audio recording | `getUserMedia`+`MediaRecorder` | **local-only** playback, never uploaded | N/A (not built) | N/A | N/A — the recording itself is decorative on the web too | Not relevant to grading; only the transcript matters |
| Riya voice input/TTS | Web Speech API (fallback) + Sarvam STT/TTS API | chat voice UX | none (chatbot unbuilt) | N/A | Whole feature | Voice fallback exists server-side (Sarvam), so this is not purely browser-only — an app implementation could call the same Sarvam endpoints directly |
| Resume Interview webcam proctoring | `getUserMedia` (video) | anti-malpractice recording | none (feature unbuilt) | N/A | Whole feature | Native camera plugin would be needed |

## 9. Dead Feature Matrix

| Feature | Model choice exists? | JS exists? | CSS exists? | Template branch renders it? | Route reachable? | Seed data ever creates it? | Verdict |
|---|---|---|---|---|---|---|---|
| Ordering (exercise type) | Yes (`EXERCISE_TYPE_CHOICES`) | Yes (`initOrdering()`, `static/js/exercises.js:1588-1628`) | Yes (`.ordering-list`/`.ordering-item`) | **No** — `exercise.html`'s content `{% if/elif %}` chain (lines 112-386) has branches for mcq/fill_blank/matching/bingo/writing/timer only, closing with a bare `{% endif %}`, no `ordering` branch, no `{% else %}` | No — no page ever renders `.ordering-list`, so `initOrdering()`'s `if (!list) return;` guard fires unconditionally | No — `populate_activities.py` never creates one | **DEAD, re-confirmed** |
| `jobs_app/urls.py`'s `job_list`/`job_detail` names | N/A | N/A | N/A | N/A | **No** — this urlconf is never `include()`'d in the root urlconf; the real public job routes live under `employer_portal`'s urlconf instead | N/A | **DEAD (orphaned urlconf)** — confirmed by the Jobs/Subscriptions research agent |
| `ResumeBuilder_module/` + `core/resume_utils.py`/`core/mask_utils.py` | N/A | N/A | N/A | N/A | Not in `INSTALLED_APPS`, not imported anywhere in the live `career_app` resume flow | N/A | **DEAD / legacy** — confirmed by the Resume/ATS research agent; the live implementation is entirely `career_app/views.py` + `career_app/resume_utils.py` |
| `AppButtonVariant.secondary` (Flutter-side) | N/A | N/A | N/A | N/A | Defined in `lib/shared/widgets/app_button.dart`, zero call sites found anywhere in `lib/` | N/A | **Dead Flutter code** — harmless, unused, found during the architecture audit (§14) |

No other dead web features were found during this pass beyond the four above; every other item in the 68-row inventory has at least one live, reachable code path (even if not yet built in Flutter).

## 10. Remaining Curriculum Activities — Detailed Table

Source: `activities/management/commands/populate_activities.py` (orders 1-20, all `mcq`/`fill_blank`/`matching`/`bingo`/`writing`/`timer` exercise types — every one already covered by an implemented or partially-implemented generic exercise type) and `activities/management/commands/setup_professional_modules.py` (orders 21-24, the 4 AI modules). All 24 rows are currently **BLOCKED only by empty `Activity`/`SubActivity`/`Exercise` tables** (`Activity: 0`) — not by any missing Flutter capability for #10 and #15 (whose exercises are all already-implemented types), and only by the Generic Writing/Timer gap for the rest.

| # | Activity | Category | Sub-Activity 1 | Sub-Activity 2 | Sub-Activity 3 (the "API-triggering" one) | Blocked By |
|---|---|---|---|---|---|---|
| 1 | Elevator Pitch Workshop | speaking | mcq | fill_blank | **timer** | DB data + Generic Timer |
| 2 | Business Negotiation Simulation | negotiation | matching | mcq | **writing** | DB data + Generic Writing |
| 3 | Professional Email Communication | writing | matching | fill_blank | **writing** | DB data + Generic Writing |
| 4 | Case Study Analysis and Presentation | analysis | mcq | **writing** | matching | DB data + Generic Writing |
| 5 | Meeting Management Workshop | negotiation | mcq | fill_blank | **writing** | DB data + Generic Writing |
| 6 | Job Interview Mastery | speaking | mcq | fill_blank | **writing** | DB data + Generic Writing |
| 7 | Business Report Writing | writing | matching | fill_blank | **writing** | DB data + Generic Writing |
| 8 | Cross-Cultural Communication | communication | mcq | mcq | **writing** | DB data + Generic Writing |
| 9 | Product Launch Planning | speaking | mcq | matching | **timer** | DB data + Generic Timer |
| 10 | Business Telephone and Video Calls | *(category not confirmed this pass)* | matching | fill_blank | mcq (no AI-triggering exercise — matches `static.docx`'s claim it's non-API-triggering) | **DB data only** — all 3 exercise types already implemented |
| 11 | Financial Literacy and Reporting | *(n/c)* | matching | mcq | **writing** | DB data + Generic Writing |
| 12 | Business Correspondence: Letters and Memos | *(n/c)* | mcq | fill_blank | **writing** | DB data + Generic Writing |
| 13 | Networking and Small Talk | *(n/c)* | mcq | fill_blank | **writing** | DB data + Generic Writing |
| 14 | Handling Complaints and Conflict Resolution | *(n/c)* | matching | mcq | **writing** | DB data + Generic Writing |
| 15 | Business Vocabulary Building Games | vocabulary | mcq | bingo | fill_blank (no AI-triggering exercise) | **DB data only** — all 3 exercise types already implemented |
| 16 | Proposal and Bid Writing | *(n/c)* | mcq | **writing** | **timer** | DB data + Generic Writing/Timer |
| 17 | Data Presentation and Visualization | *(n/c)* | matching | mcq | **timer** | DB data + Generic Timer |
| 18 | Business Idioms and Phrasal Verbs | *(n/c)* | matching | fill_blank | **writing** | DB data + Generic Writing |
| 19 | Corporate Social Responsibility Debate | *(n/c)* | matching | mcq | **writing** | DB data + Generic Writing |
| 20 | Project Status Update and Reporting | communication | fill_blank | **writing** | **timer** | DB data + Generic Writing/Timer |
| 21 | Professional Passage Writing | writing | AI-Powered Practice (module) | — | — | DB data only — AI Writing already fully implemented |
| 22 | Listen & Write | listening | AI-Powered Practice (module) | — | — | DB data only — AI Listening already fully implemented |
| 23 | Professional Reading | reading | AI-Powered Practice (module) | — | — | DB data only — AI Reading already fully implemented |
| 24 | Professional Speaking | speaking | AI-Powered Practice (module) | — | — | DB data only — AI Speaking already fully implemented |
| 25 | Group Discussion | workshop | Group Discussion Session (no exercises) | — | — | No practice-flow screen built (card-only today) |
| 26 | JAM (Just A Minute) | workshop | JAM Session (no exercises) | — | — | No practice-flow screen built |
| 27 | Roleplay | workshop | Role Play Session (no exercises) | — | — | Real `roleplay_practice`/`analyze_roleplay` APIs exist but no Flutter practice-flow screen built |

**Key takeaway**: 20 of the 24 numbered curriculum activities (all except #10 and #15) have their AI-triggering final sub-activity gated on the still-unbuilt Generic Writing or Generic Timer exercise type. #10 and #15 need **only DB data** — every exercise type they use (mcq/matching/fill_blank/bingo) is already fully implemented and tested. #21-24 (the AI modules) also need only DB data — their module-detection routing (`isSpeakingModuleActivity` etc.) already correctly matches these exact real titles.

## 11. Generic Exercise Audit

| Type | Status | Data Source | Grading Authority | Flutter State |
|---|---|---|---|---|
| MCQ | COMPLETE | Dedicated JSON API (`mcq_exercise_api`) | Server-authoritative | Full |
| Fill in the Blank | COMPLETE | `questions-data` HTML extraction | Client-authoritative (`submit_exercise` trusts it verbatim) | Full |
| Matching | COMPLETE | `questions-data` HTML extraction | Client-authoritative | Full |
| Bingo | COMPLETE | `bingo-data` HTML extraction | Client-authoritative | Full |
| **Generic Writing** | **NOT_STARTED** | `questions-data` HTML extraction (same mechanism, proven 3×) | **Server-(AI)-authoritative** when `SARVAM_API_KEY` set — `submit_exercise`'s `writing`/`timer` branch discards the client score and calls `analyze_text_with_sarvam_chat(mode="writing",...)`, applying relevance/repetition/similarity caps, then overwrites `score`/`max_score=100` | None — see §17 for exact prompts/limits/validation/payload |
| **Generic Timer** | **NOT_STARTED**, browser-dependency-blocked | `questions-data` HTML extraction | Same server-(AI)-authoritative override, `ai_mode="speaking"` | None — see §17 for exact duration/STT/payload |
| Reading (AI module) | COMPLETE | Static hardcoded passage (module JS, not DB) | Server-(AI)-authoritative, real endpoint | Full |
| Listening (AI module) | COMPLETE | Static hardcoded story + HTML-embedded attempt token | Server-(AI)-authoritative | Full |
| Speaking (AI module) | COMPLETE | Static hardcoded topics | Server-(AI)-authoritative | Full |
| Ordering | **DEAD** | N/A | N/A | N/A — do not implement |

### Generic Writing — exact mechanics (re-verified this pass, matches the W011 audit)
- **Prompts**: `question.question_text` per `.writing-prompt-card`, all rendered simultaneously (not one-at-a-time).
- **Explanation/Guide**: `question.explanation`, shown only `{% if question.explanation %}`.
- **Word limits**: client-side only, via `getWritingLimits()` — a hardcoded 150-200 word special case for the exact title "Proposal Section Writing", else parsed from the Guide text (regex for "N-M words"/"N words"), else a default minimum of 50 words with no maximum.
- **Validation**: Submit button disabled until every textarea satisfies its limit; a defensive re-check fires again on click (`alert()` if bypassed via devtools).
- **Client score calculation**: an elaborate heuristic (word-count tiers, copy-detection penalty, "N recommendations/examples" pattern match, data-point relevance check, sentence-repetition detection, Guide-keyword "structure" check, cross-prompt duplication check) — computed but **immediately discarded server-side** whenever the AI key is configured.
- **POST payload**: `{"score": <client heuristic, ignored if AI grades>, "max_score": 100, "answers": {"1": "<typed text>", "2": "...", ...}}` — plain strings, not objects (unlike Fill-in-Blank/Matching's `{given,correct,result}` shape).
- **Server response**: `{"status":"ok","score":<AI-derived>,"max_score":100,"percentage","attempt","customSummaryHtml":"<raw HTML with issue lists + Improved Version>"}`.
- **AI override**: `submit_exercise`'s `writing`/`timer` branch, `activities/views.py:1422-1495` — calls `analyze_text_with_sarvam_chat("writing", answer_text, question_text, 0, 0, key)` per question if word count > 10; applies a hard cap when `relevance < 50`, a repetition-ratio cap, and a prompt-similarity cap; averages across questions for the final score.
- **Fallback scoring**: on an AI-call exception, falls back to `total_q_score += score / len(questions)` (the client's own heuristic, prorated) — not a hard failure.
- **customSummaryHtml**: pre-rendered Bootstrap-classed HTML (issue `<li>` list + an "Improved Version" `<div>`) — the single biggest Flutter-implementation decision: render this HTML (new dependency) or surface only score/percentage and omit the rich per-issue feedback (a documented, honest simplification).

### Generic Timer — exact mechanics (re-verified this pass, matches the W011 audit)
- **Duration**: `DURATION = 60` — a hardcoded JS constant, not a DB/model field; identical for every task.
- **Task sequence**: strictly sequential — `activateTask()` only allows advancing to `taskIdx+1` once the current task is in `completedTasks`; no skipping ahead, no going back.
- **Browser speech APIs**: `webkitSpeechRecognition`/`SpeechRecognition` produces the graded transcript; `getUserMedia`+`MediaRecorder` records audio for **local playback only** — the audio blob is never uploaded to the server.
- **Transcript behavior**: `taskTranscripts[taskIdx]` accumulates finalized speech-recognition results; if the API is unsupported, transcripts stay empty (silent degradation, not an error).
- **Submit payload**: `{"score": <client heuristic>, "max_score": totalTasks, "answers": {"1": "<transcript text>", ...}}` — text only, no audio.
- **Server AI override**: same branch as Writing, but `ai_mode="speaking"`, `min_words` gate relaxed to 0 (not 10), and the low-relevance hard penalty explicitly skipped for this type.
- **Completion**: "Mark Complete" only appears once every task is in `completedTasks`; it is the same submit action, not a separate endpoint.
- **Reset**: a genuine in-place reset (unlike every other type, which only resets via full page reload) — clears all transcripts/recordings/completed flags back to task 0 without navigating away.
- **Mobile feasibility**: the sequencing/countdown/submission/AI-regrading plumbing needs zero backend change; the open question is purely how to produce the graded transcript on mobile — a new Speech-to-Text plugin, or a disclosed typed-text substitute for the 60-second window.

## 12. Major Module Audit

### A. Riya Chatbot
- **Existing web functionality**: a site-wide floating assistant, included on every page via `{% include 'includes/aria_assistant.html' %}` in `base.html`. Two consumption paths: a plain-JSON endpoint and a Server-Sent-Events streaming endpoint, plus separate voice transcribe/TTS endpoints.
- **Exact endpoints**: `POST /api/riya/chat/` (plain JSON), `POST /api/riya/chat/stream/` (SSE — `{"t": "<token>"}` per chunk, terminated by `data: [DONE]`), `POST /api/voice/transcribe/`, `POST /api/voice/tts/` — all `@csrf_exempt`, **none require login** (works for anonymous users).
- **Request/response**: chat request = `message, page, path, hash, input_mode, language, want_audio`; response = `success, reply, message, actions, source, language, speak, audio`. Full field list in §5.
- **AI backend**: Sarvam AI chat-completions (`sarvam-105b`), invoked only as a fallback after a large deterministic intent-matching layer (navigation phrase matching, premium/portal gating, Skill-Up grounding, canned quick replies) — the LLM is not the first responder for most messages.
- **Activity knowledge**: static category-level summary + title/category-only navigation matching (see Conflict 3) — does not recite per-activity descriptions.
- **Current Flutter implementation**: none — confirmed by exhaustive grep, zero chatbot code exists.
- **Exact missing work**: an entire new feature — chat UI, SSE-consuming HTTP client logic (Dio supports streaming responses), voice recording (reuse existing `AudioRecorderService`) + the two voice endpoints, and TTS playback (reuse `flutter_tts` or call `/api/voice/tts/` for a server-generated audio clip).
- **Backend-blocked**: no — every endpoint needed already exists and requires no auth, making this one of the least backend-constrained remaining features.
- **Browser-only areas**: none that must be replicated — the web's own Web-Speech-API voice fallback is optional; the *real*, always-available path is the Sarvam voice endpoints, which any HTTP client (including Flutter) can call directly.
- **Priority**: P2 (large, standalone feature; not blocking any other exercise-type work).

### B. Resume Parsing
- **Existing web functionality**: `POST /resume-builder/match/` (multipart `file` + optional JD `text`), session-gated by `_can_access_resume` plan check.
- **Actual backend**: `career_app/views.py:718-818` + `career_app/resume_utils.py` (PDF/DOCX/plain-text extraction with multi-library fallback; `validate_resume_fields` presence checklist; `extract_experience_years` regex).
- **Current Flutter implementation**: none.
- **Exact missing work**: file-picker integration, multipart upload, a result screen.
- **Backend-blocked**: no.
- **Priority**: P2.

### C. ATS / Resume Score
- **Existing web functionality**: `compute_ats_score()` — **deterministic, rule-based** (weighted checklist out of 100: contact info, core sections, bonus sections, action verbs, quantified achievements, length, dates, keyword match), **not** AI-generated, computed in the same `resume_job_match` view as parsing. A separate Sarvam call (`analyze_resume_with_sarvam`) supplies `missing_skills`/`matching_skills`/`analysis`/`career_advice` text, but its own `match_percentage` is discarded in favor of the deterministic score.
- **Current Flutter implementation**: none.
- **Exact missing work**: same screen as Resume Parsing (one combined upload→result flow on the web).
- **Backend-blocked**: no.
- **Priority**: P2 (bundled with B).

### D. AI Interview
- **Existing web functionality**: gated behind a paid plan AND a previously-parsed resume (cannot be triggered independently). 20 questions (5 fixed behavioural + 10 adaptive domain questions), 30s time limit + 10s grace per question, text or voice answers (voice transcribed via Sarvam STT then graded as text), each answer scored 0-5 by a Sarvam LLM call, optional webcam video recording (only persisted if the candidate passes, score ≥70).
- **Exact endpoints**: `resume_start_interview` (POST), `resume_get_next_question` (GET), `resume_submit_answer` (POST), `resume_transcribe_answer` (POST, audio field `audio`), `resume_upload_interview_video` (POST, field `video`), plus proctoring/violation-tracking endpoints.
- **Current Flutter implementation**: none — only the *result* (`interview_score`) is consumed, via the Dashboard API, already correctly wired.
- **Exact missing work**: an entire new feature, and it depends on Resume Parsing (B) being built first (per the web's own gating).
- **Backend-blocked**: no, but has the largest number of dependent sub-endpoints of any remaining feature.
- **Browser-only areas**: webcam recording is decorative/conditional on the web too (only uploaded if the candidate passes); voice answers already have a clean Sarvam STT endpoint, no browser-only blocker.
- **Priority**: P3 (depends on B/C being built first; highest implementation cost of any remaining feature).

### E. Skill-Up
- **Existing web functionality**: a large bundle of genuinely static HTML content (English & Vocab, Aptitude, Tech guides, CEFR, Phonics) served by `skillup_hub()` reading a static `index.html` off disk and injecting it verbatim, navigated client-side via hash routing — no DB, no API, confirming `static.docx`'s claim for this part.
- **Actual backend**: The "mock tests" embedded in that same static bundle are **not** a separate static system — they call the exact same live `activities/quiz/<subject>/submit/`, `amcat/submit/`, `cocubes/submit/` endpoints already implemented in Flutter (see Conflict 2).
- **Current Flutter implementation**: the dynamic mock-test half is fully implemented (OOP/Subject Quiz/AMCAT/CoCubes). The static content-browsing half (guides/lessons) is not implemented at all.
- **Exact missing work**: a static content-browsing UI (course/lesson list + reader), if pursued — genuinely low-risk (no API contract to get wrong, just content to reproduce), but a large volume of content to transcribe faithfully.
- **Backend-blocked**: no.
- **Priority**: P3.

### F. Grammar
- **Existing web functionality**: 9 hardcoded topics (noun, pronoun, verb, adjective, adverb, conjunction, tenses, sentence-structure, types-of-sentences), delivered via a real `@login_required` Django view (not a plain static page), including dynamically-served protected video and server-generated SVG slide illustrations per topic.
- **Current Flutter implementation**: none.
- **Exact missing work**: a content-browsing screen; video streaming would need a video-player integration (not yet used anywhere in this app).
- **Backend-blocked**: no.
- **Priority**: P3.

### G. Certificates
- **Existing web functionality**: a real, non-trivial feature (`skillup_assessment` app) — `Certificate` model with a PDF file field, `render_certificate_pdf`, views for name submission/edit/download/generate/regenerate. Eligibility is strictly server-derived from `QuizAttempt` (score ≥70%) across ~27 subjects built from the same activities-app quiz registry — not client-trusted.
- **Current Flutter implementation**: none.
- **Exact missing work**: name-entry form, generate/download flow, PDF viewing/saving on mobile.
- **Backend-blocked**: no.
- **Priority**: P3.

### H. Jobs / Recommended Jobs
- **Existing web functionality**: two distinct things. (1) The small "Recommended Jobs" card already on the Dashboard — already fully implemented in Flutter via `GET /dashboard/api/`. (2) A **separate, standalone** public job-browse/apply flow (`job_openings`, `job_detail`, `resume_apply_job`) — entirely server-rendered HTML, no JSON API, no filter/search API (filtering is via GET query params on the HTML view itself).
- **Current Flutter implementation**: (1) complete. (2) only a `ComingSoonScreen` placeholder (`RoutePaths.jobDetail`).
- **Exact missing work**: for (2), since there's no JSON API, this would need the same HTML-extraction technique already proven for exercises — extract job data from the rendered `job_openings`/`job_detail` HTML, or (more likely, given the apply flow is a plain HTML form POST) submit application data the same way. A genuinely more involved integration than the exercise-type work, since apply requires a resume file upload too.
- **Backend-blocked**: no, but requires HTML extraction/scraping of a page not designed for that (no embedded JSON script tag confirmed here, unlike the exercise pages).
- **Priority**: P2.

### I. Employer Portal
- **Existing web functionality**: a full, separate portal — same Django `User` model, differentiated by an `EmployerProfile` relation + a `request.session['portal']='employer'` flag (not a separate auth system). Dashboard, job posting, candidate search (deterministic regex/keyword text matching against a free-typed skill query — **not** an AI/job-description match, and **not** a separate "API" in the REST sense, just a normal HTML view), application review. Offer-letter generation does **not exist** as a real feature.
- **Current Flutter implementation**: only a `ComingSoonScreen` placeholder.
- **Determination strictly from source evidence**: this is explicitly out of scope for the current mobile application. The mobile app's entire architecture (Login → Dashboard → Activities) is built for the **candidate/student** experience; nothing in the Flutter codebase's routing, auth, or domain models anticipates an employer-role session. Building this would mean a second, parallel auth/session model and an entirely separate app section — a materially different scope decision than any other remaining item, not a natural next increment.
- **Priority**: OUT OF SCOPE for now, not merely low-priority.

### J. Subscriptions / Razorpay
- **Existing web functionality**: `pro_page` (plan display), `create_razorpay_order` (rate-limited 10/min, returns `order_id`/`amount`/`key_id` for the Razorpay Checkout widget), `verify_razorpay_payment` (server-side signature verification, re-fetches the order from Razorpay, trusts only server-set `notes` — never the client's claimed plan), `razorpay_webhook` (the one `@csrf_exempt` endpoint, HMAC-verified, idempotent, independently activates the plan). Plan state lives on `UserProfile` (`is_pro`, `plan_type`, `subscription_start`), and `_can_access_activity`/`_can_access_interview` read it through `_get_user_plan()`.
- **Current Flutter implementation**: only a `ComingSoonScreen` placeholder; no `razorpay_flutter` (or similar) dependency exists in `pubspec.yaml`.
- **Exact missing work**: integrate Razorpay's Flutter SDK (a genuinely new dependency — the task's "don't introduce a second networking architecture" constraint doesn't block this, since Razorpay Checkout is a payment SDK, not a competing HTTP client), call `create-order`, launch checkout, call `verify-payment` with the checkout result.
- **Backend-blocked**: no — every endpoint needed already exists.
- **Priority**: P1 — this is the one remaining feature that directly gates a large amount of *already-implemented* functionality (full Activities access, AI Interview access) behind payment; without it, a real (non-Free-Plan) user has no way to actually upgrade from the mobile app.

### K. Landing Page
- Pre-login marketing page. The mobile app's own architecture starts at Login (no pre-login marketing/browse experience exists or is implied by any other part of the app). Testimonials/5-Steps sections are hardcoded static HTML; a "Featured Activities" row is genuinely DB-driven (`home()` queries `Activity.objects.filter(is_active=True)[:6]`).
- **Priority**: N/A — not applicable to a logged-in mobile app's scope, per the same reasoning as prior UI-parity phases.

### L. Sitemap
- A hardcoded static HTML section (`<!-- SITEMAP -->`) inside the same static Skill-Up `index.html` bundle, listing links to the Skill-Up content tree. No DB, no API.
- **Priority**: N/A — a navigation aid for the static Skill-Up content only; relevant only if/when Skill-Up content browsing (E) is ever built.

### M. Dashboard
See Conflict 1 (§3). Already fully, correctly implemented as dynamic API data.

### N. Mock Tests
Re-verified this pass, independent of `static.docx`: `oop_quiz_questions`/`quiz_questions`/`amcat_questions`/`cocubes_questions` (GET, random subset per attempt, no auth required) and their `*_submit` counterparts (POST, server-side grading, `@csrf_exempt`) are genuinely live, dynamic, server-authoritative JSON APIs — confirmed twice now (once in the original implementation phase, once via the Skill-Up research agent's independent discovery that the *same* endpoints are called from the Skill-Up static bundle's own mock-test pages). Already fully implemented in Flutter (OOP, ~24 Subject Quizzes, AMCAT, CoCubes) with no discrepancy found.

### O/P/Q. JAM / Roleplay / Group Discussion
All three exist as `category='workshop'` Activities (orders 25-27), correctly listed and navigable as cards via the already-implemented Workshop Dashboard/Activities list (`activity_list_api`). None has an interactive practice-flow screen built. Of the three, only Roleplay has real backing APIs already confirmed to exist (`roleplay_practice`/`analyze_roleplay`, generate+analyze JSON endpoints, no session state to fetch back) — JAM and Group Discussion have no sub-activities/exercises at all in the seed data (`exercises: []`), meaning there is currently no discovered interactive mechanic for either beyond "attend a session" (their web pages were not deep-audited this pass beyond what earlier phases already established). **Priority**: Roleplay P1 (real APIs already exist, clean generate+analyze contract); JAM/Group Discussion P2 pending a dedicated audit of their own templates (not performed this pass — flagged as an open item, not fabricated).

## 13. Asset Audit

Real, non-decorative image/SVG assets found under `static/` (excluding the `static/001 Career Buddy/` static-HTML-app subtree, which contains its own embedded images not relevant to any currently-implemented Flutter screen):

| Asset | Path | Purpose | Used In (template) | Flutter Uses It? | Should It Be Reused? |
|---|---|---|---|---|---|
| Login brand mark | inline `<svg>` in `templates/users/login.html:10-17` (**not a separate file** — literal inline markup) | Login branding pane logo | `login.html` | No — approximated with `Icon(Icons.school_outlined)` in a colored box | Minor gap — see §14; not a file to "copy," would need hand-reproducing the inline SVG path data |
| `static/img/career-buddy-icon.svg` | `static/img/career-buddy-icon.svg` | Not found referenced in any template or CSS `url()` this pass | None found | No | No — appears orphaned; do not invent a use for it |
| `static/images/Ai_Robot.png`/`.jpg` | `static/images/` | Riya/"Buddy" chatbot launcher avatar | `templates/includes/aria_assistant.html:28` | No (chatbot unbuilt) | Yes, if/when Riya (§12.A) is implemented |
| `static/images/module_speaking.png`, `module_negotiation.png` | `static/images/` | Not found referenced in any template or CSS this pass | None found | No | No — appears orphaned |
| Testimonial headshots (`priya_sharma.jpg`, `rohit_verma.jpg`, etc., ~16 files, `.jpg`+`.svg` pairs) | `static/images/` | Landing-page testimonials | `home.html` (testimonials section) | No | No — Landing Page is out of scope (§12.K) |
| `employer_hiring.png`, `employer_interview.png`, `job_seekers.png`, `student_job_applying.png`, `student_learning.png`, `clients.png` | `static/images/` | Landing/Employer-home hero illustrations | `home.html`/`employer_home.html` | No | No — both out of scope |
| `template_executive_tech.png`, `template_minimalist_career.png`, `template_modern_professional.png` | `static/images/` | Resume Builder template previews | Resume Builder templates (not deep-audited for exact usage this pass) | No | Only if Resume Parsing (§12.B) is implemented |

**Icons**: every currently-implemented Flutter screen uses Material icons as deliberate stand-ins for the web's Font Awesome icon choices (an established, already-correct pattern from earlier phases) — no raster/SVG icon asset was found that any implemented screen should be using instead. No source asset found for most icon-level needs; Flutter currently uses an icon equivalent, consistent with this document's own instruction for that case.

## 14. UI Fidelity Gaps

This pass did not re-run a full UI fidelity re-audit (that was the dedicated, separate prior task) — the items below are the specific, concrete gaps surfaced incidentally while doing this audit's asset search, plus the still-open items already known from that prior pass.

| Screen | WEB | FLUTTER | GAP |
|---|---|---|---|
| Login branding pane | Inline `<svg>` brand mark, a stylized open-book/mortarboard glyph in a white rounded square (`login.html:10-17`) | `Icon(Icons.school_outlined)` in a white rounded square | Minor — generic Material icon standing in for a bespoke ~30×30px inline SVG mark; genuinely low visual impact, not corrected this pass (would require hand-porting SVG path data, not "copying a file," since no separate asset file exists) |
| Activity Detail hero / Activity Progress icon color | Per-activity `activity.color_class` (Bootstrap `bg-{{color_class}}`) | Single consistent navy/tier color (documented limitation, `docs/W012` inherits this from `activities/domain/entities/activity_progress.dart` and `ActivityDetail` both lacking a `colorClass` field) | **Confirmed, unchanged backend limitation** — `activity_list_api`/`activity_detail_api` do not expose `color_class` in their JSON (only `id,title,description,category,category_display,level,duration,...`); reproducing this would require a backend change, which is out of scope. Re-confirmed this pass by re-reading both API views in full (§5). |

No new UI fidelity gaps beyond these were discovered as a side effect of this pass's research; a dedicated re-audit was out of scope for W012 (explicitly an audit-only, not a UI-correction, task).

## 15. Flutter Architecture Gaps

- **Dead code**: `AppButtonVariant.secondary` (`lib/shared/widgets/app_button.dart:85`) is defined but has zero call sites anywhere in `lib/`. Harmless (unused enum value + unreachable style branch), not corrected this pass since W012 is audit-only.
- **No duplicate architecture found**: `find lib -iname "*.dart" | xargs -I{} basename {} | sort | uniq -d` returns zero duplicate filenames across the entire `lib/` tree — no evidence of parallel/competing implementations of the same concern.
- **No TODO/FIXME markers**: zero matches across `lib/`, indicating no self-flagged incomplete work left in the codebase outside what's tracked in this document.
- **13 feature folders, 12 `*_providers.dart` files** — one feature (`splash`) legitimately has no provider (it's a pure routing/timing screen); otherwise every feature has its own provider file, no missing-provider pattern found.
- **Demo repository coverage**: 8 demo repositories exist (`activities`, `mcq`, `matching`, `bingo`, `fill_blank`, and the 4 AI modules) — exactly matching the 8 currently-implemented exercise/activity-producing features. Mock Tests (OOP/Subject-Quiz/AMCAT/CoCubes) deliberately have **no** demo repository — this is correct, not a gap: their real endpoints require no authentication and no DB-seeded data at all (confirmed in the original W011 audit), so there is nothing for Demo Mode to stand in for.
- **5 `ComingSoonScreen` placeholders registered** (`register`, `passwordReset`, `employerLogin`, `jobDetail`, `pro`) — all deliberate, documented placeholders for genuinely unimplemented flows, consistent with this audit's findings (§12).
- No incorrect API mapping, no missing routes, and no inconsistent Riverpod/Dio usage pattern were found across the architecture — the codebase consistently follows one repository/provider/controller layering throughout.

## 16. Demo Mode Audit

- **Debug-only**: `demoModeActiveProvider` is hard-`false` unless `kDebugMode == true` — a compile-time Flutter constant, `false` in every release build, independent of any runtime toggle state. Re-confirmed by reading `lib/core/demo/demo_mode.dart` this pass.
- **Demo IDs never reach production APIs**: every `Demo*Repository` is a structurally separate class from its real `*RepositoryImpl` counterpart; there is no code path where a 9000+ demo id is passed to `ApiClient`/Dio.
- **Repositories switch correctly**: every one of the 8 `*_providers.dart` files reads `demoModeActiveProvider` and defaults to the real, Dio-backed implementation.
- **Production failures do not fall back to demo**: every real repository's error path returns `Failed(Failure)` through the standard `Result` type; none references any `Demo*` class.
- **Demo fixtures correspond to actual web content**: re-verified this pass — `9001 Professional Speaking`, `9002 Professional Passage Writing`, `9003 Listen & Write`, `9004 Professional Reading` all now match `setup_professional_modules.py:17-61`'s real `title`/`level`/`duration`/`objective` fields exactly (corrected in the immediately-preceding Data Correction pass, W012's predecessor task, and re-confirmed unchanged this pass). The 4 curriculum-style demo activities (Vocabulary Quiz/Matching/Bingo/Fill-in-Blank, ids 9008-9011) and the 3 workshop demo activities (Group Discussion/JAM/Role Play, ids 9005-9007) are Flutter-only fixtures representing already-implemented generic exercise types, not claiming to mirror any specific numbered curriculum activity.
- **Demo data does not replace real API data**: confirmed structurally, not just by convention — the provider-level `if (demoModeActiveProvider) return Demo...(); return Real...Impl(...);` pattern is the only place the two are ever compared, and it is identical across all 8 features.

## 17. Backend-Blocked Features

Strictly features where the *backend itself* has a genuine, verified gap (not a Flutter-side implementation-effort gap):

| Feature | Backend Limitation | Evidence |
|---|---|---|
| Activity/Activity-Progress `color_class` icon coloring | `activity_list_api`/`activity_detail_api` do not include `color_class` in their JSON response | `activities/views.py` response dict, re-read this pass (§14) |
| Ordering exercise type | Dead on the web itself — no amount of Flutter work can reproduce a UI the web doesn't render | §9 |
| Offer letter generation (Employer Portal) | Does not exist anywhere in source — not merely un-exposed via API, genuinely unbuilt on the web | §3 Conflict 4 |

No other feature audited this pass is backend-blocked in the strict sense — every other NOT_STARTED item has a real, already-existing endpoint or HTML-embedded-data mechanism it could use; the remaining work is Flutter-side implementation effort (and, for Generic Timer specifically, a mobile-side Speech-to-Text capability gap, which is a *mobile* limitation, not a *backend* one).

## 18. Implementation Readiness

| Feature | Readiness |
|---|---|
| Generic Writing | READY |
| Generic Timer | PARTIAL (blocked on a mobile STT capability decision, not backend) |
| Curriculum Activities #10, #15, #21-24 | READY (pending only DB seed data, which is explicitly out of scope to create) |
| Curriculum Activities #1-9, #11-14, #16-20 | READY once Generic Writing/Timer exist, otherwise PARTIAL |
| Roleplay practice flow | READY |
| JAM / Group Discussion practice flow | PARTIAL — no interactive mechanic discovered in source this pass |
| Riya Chatbot | READY |
| Subscriptions/Razorpay | READY |
| Jobs standalone browse/apply | READY (HTML-form-POST integration, more involved than a JSON API) |
| Resume Parsing + ATS | READY |
| AI Interview | PARTIAL — depends on Resume Parsing being built first (web's own gating) |
| Skill-Up static content browsing | READY |
| Grammar | READY |
| Certificates | READY |
| Ordering | DEAD |
| Employer Portal | BLOCKED — not a technical block, a scope decision (§12.I) |
| Landing Page / Sitemap | N/A — not applicable to this app's architecture |
| `color_class` icon theming | BLOCKED — backend does not expose the field |

## 19. Recommended Implementation Order

**P0 — Required/core functionality**: none remaining — every P0-tier item (auth, dashboard, activities navigation, the 4 already-implemented generic exercise types, the 4 AI modules, the 4 mock tests) is already COMPLETE.

**P1 — Major user functionality**:
- **Subscriptions/Razorpay** — gates access to everything else a paying user needs; every endpoint already exists; no backend dependency.
- **Roleplay practice flow** — real, already-existing generate+analyze APIs with no session state to fetch back; the cleanest remaining "real interactive exercise" after Generic Writing/Timer.

**P2 — Secondary functionality**:
- **Generic Writing** — same proven HTML-extraction pattern as 3 already-shipped exercise types; unlocks the AI-triggering sub-activity of 15 of the 20 remaining curriculum activities.
- **Riya Chatbot** — every endpoint already exists and requires no auth; large but self-contained, doesn't block anything else.
- **Jobs standalone browse/apply** — real flow exists but via HTML form POST, not JSON; more integration effort than a typical API feature.
- **Generic Timer** — same server-side plumbing as Writing, but genuinely gated on a mobile Speech-to-Text decision.
- **Resume Parsing + ATS** — no backend dependency; a self-contained upload→result flow.

**P3 — Secondary/supporting functionality**:
- **AI Interview** — depends on Resume Parsing; the highest sub-endpoint count of any remaining feature.
- **Skill-Up static content, Grammar, Certificates** — genuinely static or low-API-risk content-browsing features; large *content volume* to transcribe faithfully, but low *architectural* risk.

**BLOCKED**:
- **`color_class` activity theming** — requires a backend field that does not exist; explicitly out of scope to add.
- **Curriculum Activities #1-20 as real, seeded content** — every one of them is architecturally ready (their exercise types are either already implemented or covered by the P2 Generic Writing/Timer work); what blocks them specifically is the empty `Activity`/`SubActivity`/`Exercise` database, which this project is explicitly forbidden from seeding.

**DEAD — do not implement**:
- **Ordering** exercise type.

**OUT OF SCOPE (not ranked)**:
- **Employer Portal** — a distinct, parallel application surface for a different user role, not a natural extension of the current candidate-facing app.
- **Landing Page / Sitemap** — pre-login marketing pages with no equivalent in this app's architecture.

## 20. Next Implementation Plan

A sequential plan reflecting the priorities above, without re-ranking by preference:

1. **Generic Writing** (P2, but sequenced first since it unlocks the most curriculum content) — mirror the already-proven Matching/Bingo/Fill-in-Blank architecture exactly: `lib/features/generic_writing/` (domain/data/presentation), HTML extraction of `questions-data`, the existing `submit_exercise` POST, plain-string answers (not `{given,correct,result}` objects), and an explicit decision on `customSummaryHtml` (render vs. score-only).
2. **Subscriptions/Razorpay** (P1) — add the Razorpay Flutter SDK dependency, wire `create-order`/`verify-payment` through the existing repository/controller pattern, gate the existing `pro`/upgrade CTAs.
3. **Roleplay practice flow** (P1) — a new feature folder consuming the already-existing `roleplay_practice`/`analyze_roleplay` generate+analyze endpoints.
4. **Generic Timer** (P2) — same architecture as step 1, plus a deliberate, documented decision on the STT/typed-input question before writing any recording code.
5. **Riya Chatbot** (P2) — new feature folder; SSE-consuming HTTP layer via Dio's streaming response support; reuse the existing `AudioRecorderService` for voice input.
6. **Resume Parsing + ATS** (P2) — file-picker + multipart upload + result screen.
7. **Jobs standalone browse/apply** (P2) — HTML-form-POST integration for the apply flow; investigate whether `job_openings`/`job_detail` embed any script-tag JSON before committing to HTML scraping.
8. **AI Interview** (P3) — only after step 6 ships, since the web itself requires a parsed resume first.
9. **Skill-Up / Grammar / Certificates** (P3) — static/low-risk content features, sequenced last by user-facing importance relative to the interactive-exercise work above.

Not sequenced (require a human decision, not an engineering next-step): the 20 numbered curriculum activities cannot go live until real `Activity`/`SubActivity`/`Exercise` rows exist in the database — this project's own rules forbid creating that data, so this is a business/operations decision (running `populate_activities.py`/`setup_professional_modules.py` against the real database), not an implementation task.


