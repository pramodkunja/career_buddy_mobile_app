# Career Buddy LMS — Complete Web Screen Inventory (Phase 0)

Read-only discovery pass across the entire Django web application, cross-referenced
against the current Flutter implementation. Produced by 7 parallel discovery passes,
one per functional area, each reading every relevant `urls.py`/`views.py`/template/JS
file in its scope and grepping the Flutter tree for an existing equivalent.

**Web project modified: NO.** Every finding below came from reading, never editing,
`Career_Buddy_LMS/`.

> **Update (this session)**: Registration, Profile, and the full Password Reset
> flow (§A) are now built and largely live-verified — see the updated rows
> below. A real navigation dead-end was also found and fixed: Dashboard (and
> 5 other landing/hub screens) had no way to reach any other screen if their
> own data failed to load, unlike the real web, whose persistent top navbar
> (`templates/base.html`) is reachable from every page regardless of that
> page's own content — see `docs/WEB_COVERAGE_REPORT.md`'s Navigation
> section. Two new companion documents now exist:
> `docs/WEB_API_INVENTORY.md` (every backend request, MATCH/MISSING/
> BACKEND_NOT_DEPLOYED/WEB_HTML_ONLY classified) and
> `docs/WEB_STATIC_CONTENT_INVENTORY.md` (every hardcoded web content
> source and its Flutter reproduction status). `docs/WEB_COVERAGE_REPORT.md`
> has the final numeric completeness tally.

Status legend: `NOT_STARTED` (no Flutter code at all, not even a placeholder) ·
`INSPECTED` (endpoint/contract understood, no UI) · `IMPLEMENTED` (backend contract
wired) · `PARTIAL` (some but not all of the web behavior/states ported) ·
`VERIFIED-looking` (appears complete on inspection; not the same as live-tested —
see `docs/PRODUCTION_E2E_VERIFICATION_REPORT.md` for what has actually been
exercised against production) · `DEAD/ORPHANED` (route exists in Django but is
unreachable from any real web page — not a porting gap) · `N/A` (infra, not a screen,
or a deliberate, documented substitution).

---

## A. Authentication, Public/Home, Profile, Password Reset

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/` | Home / Landing | `activities/views.py:76 home()` | `home_screen.dart` (+`public_home_body.dart`/`authenticated_home_body.dart`) | PARTIAL | Only the top hero/portal-card section is ported. Web's Seven Core Skill Areas, Featured Activities carousel, How It Works (5 steps), dual Testimonials, and closing CTA sections (`home.html:1339-1943`) are explicitly out of scope per Flutter's own doc comment. |
| `/users/register/` | Candidate Registration | `users/views.py:153 register_view` | `RegisterScreen` | IMPLEMENTED | Full multi-section form built (account/personal/identity/education×2/experience/resume/location/abroad) + reused OTP widget. Rendering and email-OTP send verified live against production; full submission deliberately not performed (creates a real account). 3 disclosed simplifications: selfie upload, dynamic multi-education rows beyond 2, per-language proficiency pairs (uses the server's own `languages_known` fallback instead). |
| `/users/register/send-otp/`, `/users/register/verify-otp/` | Email OTP (AJAX) | `users/views.py:71,124` | `AuthRemoteDataSource.sendOtp/verifyOtp` | VERIFIED-looking | Now used by both student and employer registration; live-verified for student this session. |
| `/users/login/` | Job Seeker Login | `users/views.py:222 login_view` | `login_screen.dart` | VERIFIED-looking | Pixel-parity doc comments confirm direct CSS cross-check. |
| `/users/logout/` | Logout | `users/views.py:248 logout_view` | `AuthController.logout()` | VERIFIED-looking (fixed this session — see `PRODUCTION_E2E_VERIFICATION_REPORT.md` §9.2) | |
| `/users/profile/` | My Profile (Overview + Edit tabs) | `users/views.py:255 profile_view` | `ProfileScreen` | VERIFIED | Both tabs built (HTML-scrape parser for Overview, pre-filled Edit form). **Live-verified against a real production account** — parser confirmed correct against real data, and a real phone-number pre-fill bug this surfaced (bare-digit stored values with no `+` prefix) was found and fixed. Disclosed limits: avatar upload, dynamic multi-education rows, contact-person sub-fields on edit (start blank rather than reverse-parsed from the combined display string). |
| `/users/password-reset/` | Forgot Password | Django `PasswordResetView` | `ForgotPasswordScreen` | VERIFIED | Live-verified: real 302 success path and malformed-email field error both confirmed against production. |
| `/users/password-reset/done/` | Check Your Email | `PasswordResetDoneView` | `CheckEmailScreen` | VERIFIED | Live-verified on-device. |
| `/users/reset/<uidb64>/<token>/` | Set New Password | `PasswordResetConfirmView` | `ResetPasswordScreen` | VERIFIED (link-validity states) / IMPLEMENTED (submit) | Mobile adaptation: paste-link instead of app-link interception (no `assetlinks.json`/`apple-app-site-association` hosting available). Invalid-link detection live-verified; the "valid link → submit new password → success" state is unit-tested only (needs a real inbox to verify live). |
| `/users/reset/done/` | Password Reset Complete | `PasswordResetCompleteView` | `PasswordResetCompleteScreen` | IMPLEMENTED | Static confirmation. |
| `/media/{resumes,selfies,interview_videos}/<file>` | Protected media serving | `core/media_views.py:85` | N/A | N/A (infra) | Ownership-checked; any authenticated Flutter request already sends the required session cookie. |
| `/admin/` | Django Admin | Django built-in | N/A | OUT_OF_SCOPE | Staff-only, explicitly out of scope for mobile. |
| — | Contact / Terms / Privacy / Help pages | — | — | — | **Do not exist anywhere in the web app itself** — not a Flutter gap, a genuine absence in the source of truth. |

## B. Activities / Exercises / Mock Tests

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/activities/` (+ `/activities/api/`) | Activity List | `activities/views.py:770,777` | `ActivityListScreen` | VERIFIED-looking | Free-plan shows only 4 titles; 1-slot claim logic. |
| `/activities/workshop/` | Workshop Dashboard | `activities/views.py:862` | `WorkshopDashboardScreen` | IMPLEMENTED | Flutter added a real entry point the web itself barely links to. |
| `/activities/module/<slug>/` | Module deep-link redirect | `activities/views.py:824` | N/A | N/A | Pure web convenience redirect; Flutter navigates by id directly. |
| `/activities/<pk>/` (+ `/activities/api/<pk>/`) | Activity Detail | `activities/views.py:927,962` | `ActivityDetailScreen` | VERIFIED-looking | |
| `/activities/<a>/sub/<s>/` (+ api sibling) | Sub-Activity Detail | `activities/views.py:1042,1075` | `SubActivityDetailScreen` | VERIFIED-looking | "Mark Complete" gated on all exercises done. |
| `/activities/api/exercise/<pk>/` (+ submit) | MCQ exercise | `activities/views.py:1218,1267` | `McqExerciseScreen`/Controller | VERIFIED-looking | Only exercise type with a real JSON API. |
| `/activities/exercise/<pk>/` (+ `/submit/`) | Fill-Blank / Matching / Bingo / Generic-Writing / Timer exercises | `activities/views.py:1328,1411` | `FillBlankExerciseScreen`/`MatchingExerciseScreen`/`BingoExerciseScreen`/`GenericWritingScreen`/`TimerExerciseScreen` | PARTIAL (functioning, architecturally fragile) | **No JSON API exists for these 5 types** — Flutter reads/scrapes the rendered HTML page, documented in `docs/EXERCISE_FEASIBILITY_AUDIT.md`. Recommend real JSON endpoints eventually, mirroring MCQ's pattern. |
| `Exercise.EXERCISE_TYPE_CHOICES` includes `ordering` | Ordering exercise | `models.py:24`, hero icon only in `exercise.html:91` | Excluded, shows "Not available in the app yet." | DEAD/ORPHANED (both sides) | No render branch exists on the web template either — dead type on both platforms, not a porting gap. |
| `/activities/exercise/attempt/<pk>/delete/` | Delete a past attempt | `activities/views.py:1529` | NONE | NOT_STARTED | Web can delete a past attempt from exercise history; no Flutter caller. |
| `/activities/sub/<pk>/complete/` | Mark sub-activity complete | `activities/views.py:1544` | `MarkSubCompleteController` | IMPLEMENTED | |
| `/activities/exercise/<pk>/analyze/{speaking,writing,listening,reading}/` | AI-graded modules | `activities/views.py:1629,1688,1771,1914` | `features/ai_{speaking,writing,listening,reading}/` (full stacks) | VERIFIED-looking | Listening has `attempt_token` anti-replay + anti-copy-from-reveal detection, fully reproduced. |
| `/activities/{oop-quiz,quiz/<subject>,amcat,cocubes}/{questions,submit}/` | Mock Tests (OOP, 24 subject quizzes, AMCAT 5-section, CoCubes 4-section) | `activities/views.py:2145-2388` | `OopMasteryMockTestScreen`/`SubjectQuizMockTestScreen`/`AmcatMockTestScreen`/`CocubesMockTestScreen` | VERIFIED-looking | All 27 mock-test subjects have a Flutter screen — more complete than assumed going in. |
| `/roleplay/`, `/roleplay/<feature>/`, `/roleplay/practice/`, `/roleplay/analyze/` | Roleplay (home + practice + generate + analyze) | `activities/views.py:1976-2124` | `RoleplayHomeScreen`/`RoleplayPracticeScreen`/`RoleplayController` | VERIFIED-looking | Two-party-character heuristic reproduced client-side before any network call. No gaps found. |

## C. Grammar

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/subject/` | Subject Library (9 topics) | `subject_views.py:1604` | `grammar_index_screen.dart` | VERIFIED-looking | All 9 real topics present, field-for-field match in `grammar_data.json`. |
| `/subject/<slug>.html` | Topic detail | `subject_views.py:1615` | `grammar_detail_screen.dart` | VERIFIED-looking | Every media type (slides/video/audio/tables/rule-boxes/examples/exercises) implemented. |
| `/subject/slides/<slug>/<file>` | Slide image | `subject_views.py:1630` | `grammar_image_carousel_sheet.dart` | IMPLEMENTED | |
| `/subject/video/<slug>.mp4` | Lesson video | `subject_views.py:1642` | `grammar_video_player_sheet.dart` | IMPLEMENTED | Real mp4 exists for all 9 topics — web's YouTube-embed fallback is dead code. |
| `/subject/illustrations/<slug>/<i>.svg` | Generated SVG fallback | `subject_views.py:1708` | NONE | NOT_STARTED (moot) | Only reachable if a topic's real PNG deck is removed — currently unreachable for all 9 topics. |
| — | Language dropdown (en/vi/ar/ru) | client-side only | NONE | NOT_STARTED | Cosmetic client-side translation, not core content. |

**Grammar has essentially no real gap** — contrary to the a-priori assumption that the 9-topic list might be incomplete.

## D. Skill-Up

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/skill-up/` | Skill-Up Hub (wraps a static SPA) | `riya_bot/skillup_views.py:52` | `skill_up_screen.dart` (4 tabs) | VERIFIED-looking | Web is 1 URL + in-page hash anchors; Flutter deliberately reproduces this as 4 tabs (documented design choice). No `@login_required` on the web view — worth confirming intent. |
| `#depth-english/aptitude/tech` | 3 content sections, 19 subsections, ~64 lesson cards | static SPA content | `skill_up_data.dart` (hand-transcribed) | VERIFIED-looking, with a maintenance-drift risk | Flutter's data is a **manual copy**, not auto-derived — the Django side has `riya_bot/skillup_catalog.py` explicitly built to avoid this exact problem for the chatbot. Any future lesson add/rename/remove on web will silently desync `skill_up_data.dart` unless updated by hand. Also: Flutter's own doc comment says "48" lesson pages; direct count of the real SPA found **64** — worth reconciling. |
| Individual lesson pages (64 real static HTML files) | Lesson viewer | static files | `skill_up_lesson_screen.dart` (WebView) | IMPLEMENTED | |
| `/skill-up/assessment/` + `/api/status/` | Certifications Hub | `skillup_assessment/views.py:91,302` | `certifications_section.dart` (Skill-Up's 4th tab) | PARTIAL (functionally covered, structurally different) | No standalone Flutter screen for `module_detail`'s locked/eligible/certified full-page state — folded into inline per-card actions instead. |
| `/skill-up/assessment/<module>/` | Module detail | `skillup_assessment/views.py:125` | inline in `certifications_section.dart` | PARTIAL | **Web-side bug found** (informational): the view returns `state: 'not_attempted'` but the template checks `{% if state == 'not_completed' %}` — never matches, so the real web page renders blank for a never-attempted subject. Flutter's own state handling is arguably more correct than the current live web page. |
| Certificate name-submit/edit/generate/regenerate/download (HTML + JSON twins) | Certificate flow | `skillup_assessment/views.py:135-374` | `CertificateFormController`/`CertificateDownloadController` | IMPLEMENTED | Flutter uses the JSON API twins exclusively; solid parity. |
| — | `HP/` folder (7 files: EmployerConnect.html, Resume.html, MockInt.html, etc.) | static, unreferenced by any real card/sitemap | N/A | DEAD/ORPHANED (web-side) | Not linked from anywhere on the live site — correctly has no Flutter equivalent. |

## E. Resume Builder / ATS

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/resume-builder/` | Resume Upload / ATS Home | `career_app/views.py:712` | `ResumeBuilderScreen` | VERIFIED-looking | `resume_locked.html`'s gate is effectively dead code — `_can_access_resume()` only checks `is_authenticated`, so every logged-in user (incl. Free) passes. |
| `/resume-builder/match/` | Upload + ATS/JD Analysis | `career_app/views.py:719` | Same screen, `_UploadForm`/`_ResultView` | VERIFIED-looking | |
| `/resume-builder/reanalyze/<id>/` | Re-run ATS on stored resume | `career_app/views.py:846` | Wired via `ResumeHistoryScreen` | VERIFIED-looking | |
| `/resume-builder/history/` | Resume History | `career_app/views.py:822` | `ResumeHistoryScreen` | PARTIAL | "View File" opens an external browser without session cookies, forcing re-login — a documented known limitation. |
| Resume templates (3 static downloadable `.docx`, surfaced on the ATS result page) | Modern Professional / Executive Tech / Minimalist Career | `resume_match_result.html:312-455` | `_ResumeTemplatesSection` | VERIFIED-looking, 1:1 match | **Not a gap** — despite the initial assumption of a rich template gallery, the web reality is 3 static downloadable files with no in-app section editor; Flutter reproduces exactly this. `ResumeBuilder_module/` is a dormant, unintegrated reference package, not the live app. |
| `/resume-builder/{start-interview,interview/chat,camera-verified,violation-state,record-violation,upload-interview-video,get-question,submit-answer,transcribe-answer}/` | AI Mock Interview (camera-gated, anti-malpractice) | `career_app/views.py:930-1374` | `features/mock_interview/` (full native stack) | VERIFIED-looking, one documented gap | Camera gate, violation reporting (tab-switch/window-blur), 30s timer, adaptive difficulty, pass/fail video retention — all implemented. **Missing**: live face detection (web uses `face-api.js`; Flutter has no ML equivalent — explicitly documented as out of scope in `malpractice.dart:31-46`). Server-side Sarvam STT substituted with on-device `speech_to_text` (reasonable equivalent, not a gap). |
| `/resume-builder/analytics/` | Interview results | `career_app/views.py:1506` | `mock_interview_results_view.dart` | VERIFIED-looking, fragile | No real JSON API — Flutter regex-scrapes an embedded `<script>` JSON block. |

## F. Subscriptions / Payments / Certificates

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/pro/` | Plan Comparison (Free/Normal ₹499/Pro ₹999) | `career_app/views.py:159` | `RoutePaths.pro` → `ComingSoonScreen` | **NOT_STARTED** | **Biggest gap found across the entire audit.** |
| `/pro/toggle/` | Downgrade to Free | `career_app/views.py:184` | NONE | NOT_STARTED | |
| `/pro/create-order/`, `/pro/verify-payment/` | Razorpay checkout | `career_app/views.py:453,524` | NONE | NOT_STARTED | **No Razorpay SDK dependency exists in `pubspec.yaml` at all.** Users cannot upgrade from Free→paid inside the app today. |
| `/pro/webhook/razorpay/` | Server-to-server webhook | `career_app/views.py:1612` | N/A | N/A | Not a client screen. |
| `/pro/invoice/<pk>/` | GST Tax Invoice | `career_app/views.py:386` | NONE | NOT_STARTED | Flutter only has a read-only `PaymentRecord` list on the dashboard, not an invoice detail/print view. |
| Certificates (see §D) | — | — | — | IMPLEMENTED | Solid parity, JSON-twin endpoints used. |

## G. AI Chatbot (ARIA / Buddy)

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `POST /api/riya/chat/` | Chat (non-streaming) | `riya_bot/views.py:50` | `aria_remote_datasource.dart` | VERIFIED-looking | |
| `POST /api/riya/chat/stream/` | Chat (SSE streaming — **the real path the web JS actually uses**) | `riya_bot/views.py:108` | NONE | NOT_STARTED | Flutter uses the non-streaming sibling instead of the one the web itself calls. |
| `POST /api/voice/transcribe/`, `POST /api/voice/tts/` | Voice input/output | `riya_bot/views.py:144,173` | NONE | NOT_STARTED | No mic input, no TTS playback, no speaker controls in the Flutter chat. |
| — | Language selector (en/hi/vi/ar/ru) | client + inline `<LANG:code>` directive | NONE | NOT_STARTED | Flutter hardcodes `'language':'english'`. |
| Widget global include (`base.html:286`, every page) | Floating launcher + chat panel | template include | `buddy_chatbot_overlay.dart` | PARTIAL | Manually added to only ~10 Flutter screens vs. truly global on web (absent from activities list/detail, mock_interview, dashboard, splash, the 5 AI-graded exercise screens). |
| Action chips returned by the bot (32-destination `ACTION_DEFINITIONS` map) | Navigation actions | `riya_bot/riya_assistant.py:77+` | `ActionChip` widgets | **Deliberate divergence, documented** | Web auto-navigates the browser after narration (chips aren't even clickable — `setActionChips()` is a no-op). Flutter renders them as tappable chips that resend the label as a new message instead of navigating, since the 32 Django routes have no 1:1 GoRouter mapping. Worth a product decision, not a bug. |

## H. JAM

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/jam/dashboard/` | Dashboard | `jam_app/views.py:129` | Folded into `jam_topics_screen.dart` | PARTIAL | Assessment-progress bar reproduced; recent-sessions list + total-minutes stat dropped (documented simplification). |
| `/jam/session/start/[<topic_id>/]`, `/save-audio/`, `/<id>/` result | Regular practice session | `jam_app/views.py:180-227,634,718` | `jam_recording_screen.dart`/`jam_result_screen.dart` | VERIFIED-looking, with a real improvement | Web silently treats a failed audio upload as success; Flutter surfaces a real retryable `JamUploadFailed` state instead. |
| `/jam/history/` | Practice History (Regular + Assessments tabs) | `jam_app/views.py:730` | NONE as a UI list (only consumed internally for eligibility calc) | NOT_STARTED (UI) | |
| `/jam/topics/` | Curated Topics | `jam_app/views.py:746` | `jam_topics_screen.dart` | VERIFIED-looking | |
| `/jam/profile/` | Profile Settings | `jam_app/views.py:754` | NONE | NOT_STARTED | Consistent with the app's global `/profile` gap (§A). |
| `/jam/assessment/{start,session/<id>,result/<id>}/` | 3-stage Assessment | `jam_app/views.py:230-707` | `JamRecordingScreen(startAsAssessment:true)`/`jam_assessment_result_screen.dart` | VERIFIED-looking | Eligibility mirrored client-side via `JamAssessmentEligibilityController`. |
| `/jam/session/delete/<id>/`, `/jam/assessment/delete/<id>/`, `/jam/reset-progress/` | Delete/reset actions | `jam_app/views.py:779,801,93` | NONE | NOT_STARTED | Zero Flutter callers confirmed via repo-wide grep. |

## I. Group Discussion

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/gd/` | GD Arena / topic picker | `GD_app/views.py:12` | `gd_topic_screen.dart` | VERIFIED-looking (minor gap) | Web's 499-char client-side topic counter not reproduced (server itself has no hard limit either). |
| `/gd/create/` | Create session | `GD_app/views.py:38` | `GdSessionController.startDiscussion()` | VERIFIED-looking | Real `_can_access_workshop('gd')` gate enforced. |
| `/gd/room/<id>/` + WebSocket | Live discussion room | `GD_app/views.py:54`, `GD_app/consumers.py:17` | `gd_discussion_screen.dart`/`gd_websocket_service.dart` | VERIFIED-looking, with a real improvement | Full WS protocol (3 client actions, 4 server event types) reproduced 1:1. Web silently reconnects+resends `start` (resetting server-side agent index with no re-entrancy guard); Flutter reconnects without resending `start`, preserving the in-progress transcript — a deliberate, documented improvement. |
| `/gd/report/<id>/` | Performance Report | `GD_app/views.py:69` | `gd_report_screen.dart` | VERIFIED-looking | |
| `/gd/api/sessions/` | Past sessions list | `GD_app/views.py:89` | `gd_history_screen.dart` | VERIFIED-looking | |

## J. Employer Portal

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/employer-home/` | Recruiter Portal Landing | `jobs_app/views.py:342` | `employer_home_screen.dart` | VERIFIED-looking | |
| `/employer/accounts/employer/register/`, `.../login/` | Employer Register/Login | `accounts_app/views.py:44,86` | `employer_register_screen.dart`/`employer_login_screen.dart` | VERIFIED-looking | |
| `/employer/accounts/logout/` (`job_logout`) | — | Django `LogoutView` | N/A | DEAD/ORPHANED | No template links this route — employer logout actually posts to the shared global `users:logout`. |
| `/employer/employer/dashboard/` | Employer Dashboard | `jobs_app/views.py:497` | `employer_dashboard_screen.dart` | VERIFIED-looking (read-only) | **Per-job Edit/Delete/View-Applications actions have no Flutter destination.** |
| `/employer/employer/profile/{create,edit}/` | Company Profile | `jobs_app/views.py:540,559` | `RoutePaths.employerCompanyProfile` → `ComingSoonScreen` | NOT_STARTED | Full field list captured in agent report (company identity, GST/PAN masked-reveal, HR contact, etc.) — same `ComingSoonScreen` for both create and edit today, web has 2 distinct titles/behaviors. |
| `/employer/employer/jobs/new/` | Post New Job | `jobs_app/views.py:575` | `RoutePaths.employerJobCreate` → `ComingSoonScreen` | NOT_STARTED | 14-field form incl. 4 radio-pill groups (work environment, interview mode, notice period, gender preference) — full spec captured in agent report for future implementation. |
| `/employer/employer/jobs/<pk>/edit/` | Edit Job | `jobs_app/views.py:606` | **NONE — no route at all** | **GAP, no placeholder** | |
| `/employer/employer/jobs/<pk>/delete/` | Delete Job | `jobs_app/views.py:623` | **NONE — no route at all** | **GAP, no placeholder** | POST-only, JS `confirm()` dialog, hard delete. |
| `/employer/employer/jobs/<pk>/applications/` | Job Applications (per-job) | `jobs_app/views.py:632` | **NONE — no route at all** | **GAP, no placeholder** | |
| `/employer/employer/applications/<pk>/` | Application Detail | `jobs_app/views.py:684` | **NONE — no route at all** | **GAP, most important missing screen** | Only place an employer can change applicant status (triggers a candidate-facing email). Full field list captured in agent report. |
| `/employer/employer/applications/` | All Applications | `jobs_app/views.py:712` | `RoutePaths.employerAllApplications` → `ComingSoonScreen` | NOT_STARTED | |
| `/employer/employer/job-openings/` | Job Openings (browse+apply) | `jobs_app/views.py:743` | `RoutePaths.employerJobOpenings` → `ComingSoonScreen` | NOT_STARTED | Also the student-facing "apply to any job" grid. |
| `/employer/employer/candidates/search/` | Candidate Search | `jobs_app/views.py:1066` | `RoutePaths.employerSearchCandidates` → `ComingSoonScreen` | NOT_STARTED | Full search-engine behavior captured in agent report. |
| `/employer/employer/candidates/download-csv/` | CSV export | `jobs_app/views.py:354` | NONE | DEAD/ORPHANED | No UI button links it anywhere on the live web app either. |

## K. Jobs / Career (student-facing)

| Web Route | Screen | Django View | Flutter Screen | Status | Notes |
|---|---|---|---|---|---|
| `/employer/jobs/<pk>/` | Public Job Detail | `jobs_app/views.py:428` | `RoutePaths.jobDetail` → `ComingSoonScreen` | NOT_STARTED | View branches on employer-vs-student session (hides apply form for employer) — a future implementation needs 2 render modes, not 1. |
| `/employer/employer/resume-apply/` | Quick Apply from resume match | `jobs_app/views.py:804` | **NONE — no route at all** | **GAP, no placeholder** | POST-only, invoked from Resume Builder → Job Match. |
| `/applications/<pk>/` | My Application Detail | `jobs_app/views.py:148` | **NONE — no route at all** | **GAP, no placeholder** | Student-facing, deep-linked from status-change emails. |
| (dead) `jobs_app/urls.py` / `job_list()` | — | `jobs_app/views.py:391` | — | DEAD/ORPHANED | `jobs_app.urls` is never `include()`d anywhere; its own template file doesn't even exist. Not a real screen. |

---

## Summary Counts (approximate — see individual sections for exact row-level detail)

- **Web routes/screens catalogued this phase**: ~150 (across all 7 discovery passes; some overlap where two agents' scopes both touched a shared route, e.g. certificate endpoints, has been noted inline rather than double-counted in this total).
- **VERIFIED-looking (web flow appears fully reproduced)**: the large majority — Login/Logout, all 6 real exercise types, all 4 AI-graded modules, all 4 mock-test systems (27 subjects), Grammar (all 9 topics), Skill-Up content browsing, Resume/ATS, AI Mock Interview, Certificates, JAM regular+assessment, Roleplay, Group Discussion, Employer auth+dashboard(read).
- **NOT_STARTED (`ComingSoonScreen` or literally nothing)**: Student Registration, Profile view/edit, 3-step Password Reset, Company Profile create/edit, Post New Job, All Applications, Job Openings, Candidate Search, Public Job Detail, entire Subscriptions/Payments flow (`/pro/*`), GST Invoice, ARIA streaming/voice/language-selector, JAM History/Profile/delete-actions.
- **GAP with no placeholder at all (worse than `ComingSoonScreen`)**: Job Edit, Job Delete, per-job Applications list, Application Detail (status-change — the single most consequential missing screen), My Application Detail (student), Quick Apply.
- **DEAD/ORPHANED on the web itself (not a Flutter gap)**: `job_logout`, `jobs_app.urls`/`job_list()`, Candidate CSV export, `resume_userguide.html`, the Skill-Up `HP/` folder, the `ordering` exercise type, `/subject/illustrations/` SVG fallback.
- **Biggest single finding**: Subscriptions/Payments is ~0% implemented — no Razorpay SDK dependency exists at all, so users cannot upgrade their plan inside the app today.
