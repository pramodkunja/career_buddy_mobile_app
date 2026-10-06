# Career Buddy LMS — Web API Inventory

Every real backend request the web application makes (or, for HTML-only
views, the page itself), cross-referenced against the current Flutter
datasource/repository/screen. Compiled from the Phase 0 discovery pass
(7 parallel read-only agents covering all 11 Django apps) plus this
session's own direct work (Password Reset, Registration, Profile).

No backend API was created or modified to produce this document — every
row reflects a route that already exists in the checked-in Django source.

Classification:
- `MATCH` — Flutter calls the same endpoint, same method, same shape as web.
- `MISSING_IN_FLUTTER` — a real web endpoint with no Flutter caller.
- `BACKEND_NOT_DEPLOYED` — the endpoint exists in the local Django checkout
  (often as an uncommitted diff) but 404s on live production.
- `WEB_HTML_ONLY` — no JSON API exists on either side; Flutter reproduces
  the page via HTML-scraping (a documented, intentional pattern used
  throughout this app wherever the web itself has no JSON contract).
- `BLOCKED` — real, deliberately not exercised this session (destructive,
  or requires infrastructure outside this app's control).

---

## Authentication / Account

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Student login | `/users/login/` | GET+POST | No | `AuthRemoteDataSource.login()` | MATCH |
| Student logout | `/users/logout/` | POST | Yes | `AuthRemoteDataSource.logout()` | MATCH |
| Email OTP send | `/users/register/send-otp/` | POST | No | `AuthRemoteDataSource.sendOtp()` | MATCH |
| Email OTP verify | `/users/register/verify-otp/` | POST | No | `AuthRemoteDataSource.verifyOtp()` | MATCH |
| Student registration | `/users/register/` | GET+POST | No | `AuthRemoteDataSource.register()` | MATCH |
| Profile view/edit | `/users/profile/` | GET+POST | Yes | `ProfileRemoteDataSource.getProfile()/updateProfile()` | MATCH (HTML-scrape, `WEB_HTML_ONLY` in mechanism) |
| Password reset request | `/users/password-reset/` | GET+POST | No | `PasswordResetRemoteDataSource.requestReset()` | MATCH |
| Password reset confirm | `/users/reset/<uidb64>/<token>/` | GET+POST | No (token-gated) | `PasswordResetRemoteDataSource.checkResetLink()/confirmReset()` | MATCH (mobile adaptation: paste-link instead of app-link interception) |
| Employer login | `/employer/accounts/employer/login/` | GET+POST | No | `EmployerAuthRemoteDataSource.login()` | MATCH |
| Employer registration | `/employer/accounts/employer/register/` | GET+POST | No | `EmployerAuthRemoteDataSource.register()` | MATCH |
| Employer logout (`job_logout`) | `/employer/accounts/logout/` | GET | Yes | none | DEAD/ORPHANED on web itself — no template links it; real employer logout uses the shared `/users/logout/` |

## Dashboard / Activities

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Dashboard (HTML) | `/dashboard/` | GET | Yes | n/a (web-only) | WEB_HTML_ONLY |
| Dashboard (JSON) | `/dashboard/api/` | GET | Yes | `DashboardRemoteDataSource` | **BACKEND_NOT_DEPLOYED** — exists uncommitted in local Django checkout; 404 live on production |
| Activities list (HTML) | `/activities/` | GET | Yes | n/a | WEB_HTML_ONLY |
| Activities list (JSON) | `/activities/api/` | GET | Yes | `ActivityListController` | **BACKEND_NOT_DEPLOYED** |
| Activity detail (JSON) | `/activities/api/<pk>/` | GET | Yes | `ActivityDetailController` | **BACKEND_NOT_DEPLOYED** |
| Sub-activity detail (JSON) | `/activities/api/sub/<pk>/` | GET | Yes | `SubActivityDetailController` | **BACKEND_NOT_DEPLOYED** |
| Workshop dashboard | `/activities/workshop/` | GET | Yes | `WorkshopDashboardController` | MATCH |
| MCQ exercise (read) | `/activities/api/exercise/<pk>/` | GET | Yes | `McqExerciseController` | **BACKEND_NOT_DEPLOYED** |
| MCQ submit | `/activities/api/exercise/<pk>/submit/` | POST | Yes | `McqExerciseController` | **BACKEND_NOT_DEPLOYED** |
| Exercise detail (Fill-Blank/Matching/Bingo/Writing/Timer) | `/activities/exercise/<pk>/` | GET | Yes | 5 exercise-type screens | WEB_HTML_ONLY (no JSON API exists for these on the web either) |
| Generic exercise submit | `/activities/exercise/<pk>/submit/` | POST | Yes | 5 exercise-type controllers | MATCH — with a live, unexplained anomaly: a correctly-shaped Matching submission scored 0 in one production test (flagged for backend investigation, not a Flutter defect) |
| Delete attempt | `/activities/exercise/attempt/<pk>/delete/` | POST | Yes | none | MISSING_IN_FLUTTER |
| Mark sub complete | `/activities/sub/<pk>/complete/` | POST | Yes | `MarkSubCompleteController` | MATCH |
| AI Speaking analyze | `/activities/exercise/<pk>/analyze/speaking/` | POST | Yes | `AiSpeakingController` | MATCH |
| AI Writing analyze | `/activities/exercise/<pk>/analyze/writing/` | POST | Yes | `AiWritingController` | MATCH |
| AI Listening analyze | `/activities/exercise/<pk>/analyze/listening/` | POST | Yes | `AiListeningController` | MATCH (incl. `attempt_token` anti-replay) |
| AI Reading analyze | `/activities/exercise/<pk>/analyze/reading/` | POST | Yes | `AiReadingController` | MATCH |

## Mock Tests

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| OOP Mastery questions/submit | `/activities/oop-quiz/{questions,submit}/` | GET/POST | No | `OopMasteryMockTestScreen` | MATCH |
| 24 generic subject quizzes | `/activities/quiz/<subject>/{questions,submit}/` | GET/POST | No | `SubjectQuizMockTestScreen` | MATCH |
| AMCAT questions/submit | `/activities/amcat/{questions,submit}/` | GET/POST | No | `AmcatMockTestScreen` | MATCH |
| CoCubes questions/submit | `/activities/cocubes/{questions,submit}/` | GET/POST | No | `CocubesMockTestScreen` | MATCH |

## Grammar

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Subject library | `/subject/` | GET | Yes | `grammar_data.json` (bundled) | MATCH (static content, verified complete — all 9 real topics present) |
| Topic detail | `/subject/<slug>.html` | GET | Yes | `GrammarDetailScreen` | MATCH |
| Slide image | `/subject/slides/<slug>/<file>` | GET | Yes | `ApiEndpoints.subjectSlideImage` | MATCH |
| Video | `/subject/video/<slug>.mp4` | GET | Yes | `ApiEndpoints.subjectVideo` | MATCH |
| Illustration (SVG fallback) | `/subject/illustrations/<slug>/<i>.svg` | GET | Yes | none | DEAD/ORPHANED — unreachable on web too (every topic has a real PNG deck) |

## Skill-Up / Certifications

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Skill-Up hub | `/skill-up/` | GET | No (web view has no `@login_required`) | `SkillUpScreen` | MATCH |
| Lesson pages (~64 static files) | `static/001 Career Buddy/**` | GET | No | `SkillUpLessonScreen` (WebView) | MATCH |
| Certifications hub | `/skill-up/assessment/` | GET | Yes | `certifications_section.dart` | MATCH (structurally different: tab vs. standalone page) |
| Certifications status (JSON) | `/skill-up/assessment/api/status/` | GET | Yes | `CertificationsRemoteDataSource` | MATCH |
| Module detail | `/skill-up/assessment/<module>/` | GET | Yes | inline in `certifications_section.dart` | MATCH |
| Certificate generate (JSON) | `/skill-up/assessment/api/<module>/certificate/generate/` | POST | Yes | `CertificateFormController.generate()` | MATCH |
| Certificate regenerate (JSON) | `/skill-up/assessment/api/<module>/certificate/regenerate/` | POST | Yes | `CertificateFormController.regenerate()` | MATCH |
| Certificate download | `/skill-up/assessment/<module>/certificate/download/` | GET | Yes | `CertificateDownloadController` | MATCH |

## Resume Builder / ATS / AI Mock Interview

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Resume home | `/resume-builder/` | GET | Yes | `ResumeBuilderScreen` | MATCH |
| Upload + ATS/JD match | `/resume-builder/match/` | POST | Yes | `_UploadForm` | MATCH |
| Reanalyze stored resume | `/resume-builder/reanalyze/<id>/` | POST | Yes | `ResumeHistoryScreen` | MATCH |
| Resume history | `/resume-builder/history/` | GET | Yes | `ResumeHistoryScreen` | MATCH (HTML-scrape) |
| Start interview | `/resume-builder/start-interview/` | GET | Yes (Normal/Pro) | `MockInterviewController` | MATCH |
| Camera verified | `/resume-builder/camera-verified/` | POST | Yes | `InterviewCameraServiceImpl` | MATCH |
| Violation state / record | `/resume-builder/violation-state/`, `/record-violation/` | GET/POST | Yes | `malpractice.dart` | MATCH (partial by design — face-detection violations not fired; no ML equivalent) |
| Upload interview video | `/resume-builder/upload-interview-video/` | POST | Yes | camera service | MATCH |
| Get next question | `/resume-builder/get-question/` | GET | Yes | `mock_interview_question_view.dart` | MATCH |
| Submit answer | `/resume-builder/submit-answer/` | POST | Yes | same | MATCH |
| Transcribe answer (server STT) | `/resume-builder/transcribe-answer/` | POST | Yes | none — substituted with on-device `speech_to_text` | INTENTIONAL SUBSTITUTION, not a gap |
| Interview analytics | `/resume-builder/analytics/` | GET | Yes | `mock_interview_results_view.dart` | MATCH (HTML/embedded-JSON scrape, fragile) |

## Subscriptions / Payments

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Plan comparison | `/pro/` | GET | Yes | none (`ComingSoonScreen`) | **MISSING_IN_FLUTTER — biggest gap in the whole app** |
| Downgrade to free | `/pro/toggle/` | POST | Yes | none | MISSING_IN_FLUTTER |
| Razorpay create order | `/pro/create-order/` | POST | Yes | none | MISSING_IN_FLUTTER — no Razorpay SDK dependency at all |
| Razorpay verify payment | `/pro/verify-payment/` | POST | Yes | none | MISSING_IN_FLUTTER |
| GST invoice | `/pro/invoice/<pk>/` | GET | Yes (owner/staff) | none | MISSING_IN_FLUTTER |

## AI Chatbot (ARIA / Buddy)

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Chat (non-streaming) | `/api/riya/chat/` | POST | No | `AriaRemoteDataSource.sendMessage()` | MATCH |
| Chat (SSE streaming — the real path web uses) | `/api/riya/chat/stream/` | POST | No | none | MISSING_IN_FLUTTER |
| Voice transcribe | `/api/voice/transcribe/` | POST | No | none | MISSING_IN_FLUTTER |
| Voice TTS | `/api/voice/tts/` | POST | No | none | MISSING_IN_FLUTTER |

## JAM

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Dashboard | `/jam/dashboard/` | GET | Yes | folded into `jam_topics_screen.dart` | MATCH (partial — recent-sessions list/total-minutes dropped) |
| Session start (random/topic) | `/jam/session/start/[<topic_id>/]` | GET | No | `JamSessionController` | MATCH |
| Save audio | `/jam/session/save-audio/` | POST | No | same | MATCH, with a real improvement (retryable failure state vs. web's silent-success) |
| Complete session | `/jam/session/complete/<id>/` | GET | No | same | MATCH |
| Session detail | `/jam/session/<id>/` | GET | Yes | `jam_result_screen.dart` | MATCH |
| History | `/jam/history/` | GET | Yes | consumed internally only (eligibility calc) | MATCH (data), MISSING_IN_FLUTTER (as a UI list) |
| Topics | `/jam/topics/` | GET | No | `jam_topics_screen.dart` | MATCH |
| Profile settings | `/jam/profile/` | GET | No | none | MISSING_IN_FLUTTER |
| Assessment start/session/result | `/jam/assessment/{start,session/<id>,result/<id>}/` | GET | No | full 3-stage flow | MATCH |
| Delete session/assessment, reset progress | `/jam/{session/delete,assessment/delete}/<id>/`, `/jam/reset-progress/` | POST | Yes | none | MISSING_IN_FLUTTER |

## Roleplay

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Home | `/roleplay/` | GET | Yes | `RoleplayHomeScreen` | MATCH |
| Practice page | `/roleplay/<feature>/` | GET | Yes | `RoleplayPracticeScreen` | MATCH |
| Generate scenario | `/roleplay/practice/` | POST | Yes | `RoleplayController` | MATCH |
| Analyze | `/roleplay/analyze/` | POST | Yes | same | MATCH |

## Group Discussion

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Arena / topic picker | `/gd/` | GET | Yes | `GdTopicScreen` | MATCH (minor: 499-char counter not reproduced) |
| Create session | `/gd/create/` | POST | Yes | `GdSessionController` | MATCH |
| Live room (HTTP) | `/gd/room/<id>/` | GET | Yes | `gd_discussion_screen.dart` | MATCH |
| Live room (WebSocket) | `ws/GD_app/<id>/` | WS | Yes (cookie) | `gd_websocket_service.dart` | MATCH — 1:1 protocol, plus a real improvement (reconnect without resending `start`) |
| Report | `/gd/report/<id>/` | GET | Yes | `gd_report_screen.dart` | MATCH |
| Sessions list | `/gd/api/sessions/` | GET | Yes | `gd_history_screen.dart` | MATCH |

## Employer Portal / Jobs

| Feature | URL | Method | Auth | Flutter | Status |
|---|---|---|---|---|---|
| Employer home | `/employer-home/` | GET | No | `employer_home_screen.dart` | MATCH |
| Employer dashboard | `/employer/employer/dashboard/` | GET | Yes | `employer_dashboard_screen.dart` | MATCH (HTML-scrape, read-only) |
| Company profile create/edit | `/employer/employer/profile/{create,edit}/` | GET+POST | Yes | none (`ComingSoonScreen`) | MISSING_IN_FLUTTER |
| Post new job | `/employer/employer/jobs/new/` | GET+POST | Yes | none | MISSING_IN_FLUTTER |
| Edit job | `/employer/employer/jobs/<pk>/edit/` | GET+POST | Yes | none — no route at all | MISSING_IN_FLUTTER |
| Delete job | `/employer/employer/jobs/<pk>/delete/` | POST | Yes | none | MISSING_IN_FLUTTER |
| Job applications (per-job) | `/employer/employer/jobs/<pk>/applications/` | GET | Yes | none | MISSING_IN_FLUTTER |
| All applications | `/employer/employer/applications/` | GET | Yes | none (`ComingSoonScreen`) | MISSING_IN_FLUTTER |
| Application detail (status change) | `/employer/employer/applications/<pk>/` | GET+POST | Yes | none — no route at all | **MISSING_IN_FLUTTER — most consequential gap** |
| Job openings (browse+apply) | `/employer/employer/job-openings/` | GET+POST | Yes | none (`ComingSoonScreen`) | MISSING_IN_FLUTTER |
| Candidate search | `/employer/employer/candidates/search/` | GET | Yes | none (`ComingSoonScreen`) | MISSING_IN_FLUTTER |
| Candidate CSV export | `/employer/employer/candidates/download-csv/` | GET | Yes | none | DEAD/ORPHANED on web itself (no UI button links it) |
| Public job detail | `/employer/jobs/<pk>/` | GET | No | none (`ComingSoonScreen`) | MISSING_IN_FLUTTER |
| Quick apply | `/employer/employer/resume-apply/` | POST | Yes | none | MISSING_IN_FLUTTER |
| My application detail | `/applications/<pk>/` | GET | Yes | none | MISSING_IN_FLUTTER |

---

## Summary

| Classification | Count (approx.) |
|---|---|
| MATCH | ~75 |
| MISSING_IN_FLUTTER | ~25 |
| BACKEND_NOT_DEPLOYED | 7 |
| WEB_HTML_ONLY (intentional, both sides) | ~6 |
| DEAD/ORPHANED (web-side, exclude from parity tracking) | 5 |

No backend API was created or modified to produce this document.
**Web source modified: NO.**
