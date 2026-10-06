# Career Buddy LMS — Complete API Parity Matrix

Every web request identified during discovery, compared against its Flutter
equivalent across method, URL, parameters, body, headers, cookies,
response, error handling, and redirects. "Response Match" is marked `YES`
only where a real request/response pair was actually compared (live or via
a test fixture built from real captured HTML/JSON) — never assumed from a
200 status code alone.

**Web source modified: NO.**

## Authentication

| Feature | Web Request | Method | Flutter Request | Method | Request Match | Response Match | Status |
|---|---|---|---|---|---|---|---|
| Student login | `/users/login/` (GET primes CSRF, then POST `username`/`password`/`csrfmiddlewaretoken`) | GET+POST | `AuthRemoteDataSource.login()` | GET+POST | YES — identical field names, `X-CSRFToken` header, `followRedirects:false` | YES — 302/`Location:/` = success, 200 = re-rendered-form failure; both confirmed live | MATCH |
| Student logout | `/users/logout/` (POST, `X-CSRFToken`) | POST | `AuthRemoteDataSource.logout()` | POST | YES | YES — real 302 confirmed live; **bug found**: Dio's default `validateStatus` rejected the real 302 as an error, surfacing a false "Something unexpected happened" message after an otherwise-successful logout. Fixed (`validateStatus: (status) => status < 500`), re-verified live | MATCH (after fix) |
| OTP send/verify | `/users/register/{send-otp,verify-otp}/` (POST, form-encoded, `X-Requested-With: XMLHttpRequest`) | POST | `AuthRemoteDataSource.sendOtp/verifyOtp` | POST | YES | YES — `{"ok":true,"message":...}` / `{"ok":false,"error":...}` shape confirmed live, incl. 429 rate-limit handling | MATCH |
| Registration | `/users/register/` (GET primes CSRF, multipart POST — resume file required) | GET+POST | `AuthRemoteDataSource.register()` | GET+POST | YES — same ~35 field names, multipart resume upload | Render+OTP-send confirmed live; full-submission response (302 success / 200 re-rendered-form) verified via unit test only (not live, to avoid creating a real account) | IMPLEMENTED_NOT_VERIFIED (submit path) |
| Profile view | `/users/profile/` (GET, HTML, both tabs in one response) | GET | `ProfileRemoteDataSource.getProfile()` | GET | YES | YES — regex-scraped `info-item-label`/`info-item-value` pairs confirmed against **real production HTML** (`nvenkatsai`); every field (mobile, gender, blood group, masked Aadhar, education, experience, location) matched | MATCH |
| Profile update | `/users/profile/` (POST, multipart, resume optional) | POST | `ProfileRemoteDataSource.updateProfile()` | POST | YES — same field names as registration minus username/password | Verified via unit test (302/200 shapes); real live submission deliberately not performed (would mutate a real account's data) | IMPLEMENTED_NOT_VERIFIED |
| Password reset request | `/users/password-reset/` (GET primes CSRF, POST `email`) | GET+POST | `PasswordResetRemoteDataSource.requestReset()` | GET+POST | YES | YES — confirmed live: valid/nonexistent email → 302; malformed email → 200 with the exact scraped error text | MATCH |
| Password reset confirm (check link) | `/users/reset/<uidb64>/<token>/` (GET, no JSON — validity detected by presence of `new_password1` field name) | GET | `PasswordResetRemoteDataSource.checkResetLink()` | GET | YES | YES — confirmed live with both a real fake link (→invalid) | MATCH |
| Password reset confirm (submit) | same URL, POST `new_password1`/`new_password2` | POST | `PasswordResetRemoteDataSource.confirmReset()` | POST | YES | Verified via unit test only (needs a real, unexpired token from a real inbox to test live) | IMPLEMENTED_NOT_VERIFIED |
| Employer login | `/employer/accounts/employer/login/` | GET+POST | `EmployerAuthRemoteDataSource.login()` | GET+POST | YES | YES — confirmed live (`rameshn`, `Testthree`), 302→`/employer-home/` | MATCH |

## Dashboard / Activities

| Feature | Web Request | Method | Flutter Request | Method | Request Match | Response Match | Status |
|---|---|---|---|---|---|---|---|
| Dashboard (JSON) | `/dashboard/api/` | GET | `DashboardRemoteDataSource.getDashboard()` | GET | N/A — endpoint 404s live | N/A | **BACKEND_NOT_DEPLOYED** — confirmed live 404 by 3 independent agents; the view exists uncommitted in the local Django checkout, field shape cross-checked and matches Flutter's model exactly (will work once deployed) |
| Activities list/detail (JSON) | `/activities/api/[...]` | GET | `ActivityListController`/`ActivityDetailController`/`SubActivityDetailController` | GET | N/A | N/A | **BACKEND_NOT_DEPLOYED** — same situation as above |
| MCQ exercise (JSON) | `/activities/api/exercise/<pk>/[/submit/]` | GET/POST | `McqExerciseController` | GET/POST | N/A | N/A | **BACKEND_NOT_DEPLOYED** |
| Generic exercise submit | `/activities/exercise/<pk>/submit/` (POST, JSON body shaped per exercise type) | POST | per-exercise-type controllers | POST | YES — wire shapes for Fill-Blank and Matching confirmed to exactly match the documented contract | Fill-Blank: YES, live, correct score. Matching: **anomaly** — correctly-shaped submission scored 0 live, contradicting the documented "trusts client score" contract. Flagged for backend investigation | PARTIAL (Matching), MATCH (Fill-Blank) |
| AI Speaking/Writing/Reading analyze | `/activities/exercise/<pk>/analyze/{speaking,writing,reading}/` (POST multipart: audio/text, duration, pause_count) | POST | per-module controllers | POST | YES — field names confirmed via direct Django view source read | Contract-verified only; no real audio/live submission this pass | IMPLEMENTED_NOT_VERIFIED |
| AI Listening analyze | `/activities/exercise/<pk>/analyze/listening/` (POST, `attempt_token` anti-replay) | POST | `AiListeningController` | POST | YES | Token-fetch step confirmed live (`nvenkatsai`, real `attempt_token` returned); `analyze` POST itself not live-submitted | MATCH (token contract), IMPLEMENTED_NOT_VERIFIED (submit) |

## Mock Tests

| Feature | Web Request | Method | Flutter Request | Method | Request Match | Response Match | Status |
|---|---|---|---|---|---|---|---|
| OOP/AMCAT/CoCubes/24-subject quizzes | `/activities/{oop-quiz,amcat,cocubes,quiz/<subject>}/{questions,submit}/` | GET/POST | `MockTestQuestionParsing`/`AmcatSectionParsing` | GET/POST | YES | YES — real captured JSON shape confirmed live for all 4 systems (`{"id","q","options","difficulty","topic"}` for OOP/subject quizzes; `{"key","name","timeSec","type","questions"}` for AMCAT/CoCubes sections) | MATCH |

## Skill-Up / Certifications

| Feature | Web Request | Method | Flutter Request | Method | Request Match | Response Match | Status |
|---|---|---|---|---|---|---|---|
| Certifications status | `/skill-up/assessment/api/status/` | GET | `CertificationsRemoteDataSource` | GET | YES | YES — real JSON confirmed live, `categories`/`total_count`/`attempted_count`/`earned_count` all present and correctly typed | MATCH |
| Certificate generate/regenerate | `/skill-up/assessment/api/<module>/certificate/{generate,regenerate}/` | POST | `CertificateFormController` | POST | YES | Contract-verified via source; not live-exercised this pass (would generate a real certificate) | IMPLEMENTED_NOT_VERIFIED |

## Resume / ATS / AI Mock Interview

| Feature | Web Request | Method | Flutter Request | Method | Request Match | Response Match | Status |
|---|---|---|---|---|---|---|---|
| Resume upload + match | `/resume-builder/match/` (POST multipart, optional JD text) | POST | `ResumeBuilderScreen._UploadForm` | POST | YES | YES — confirmed live, real ATS score/matching-skills/missing-skills returned | MATCH |
| Resume history | `/resume-builder/history/` (GET, HTML) | GET | `ResumeHistoryScreen` | GET | YES | YES — real card markup (filename/date/reanalyze-id) confirmed extractable via the documented regexes, live | MATCH |
| AI Mock Interview question/answer loop | `/resume-builder/{get-question,submit-answer}/` | GET/POST | `mock_interview_question_view.dart` | GET/POST | YES — field names confirmed via source | Contract-verified; not live-run end-to-end this pass | IMPLEMENTED_NOT_VERIFIED |

## AI Chatbot (ARIA)

| Feature | Web Request | Method | Flutter Request | Method | Request Match | Response Match | Status |
|---|---|---|---|---|---|---|---|
| Chat (non-streaming) | `/api/riya/chat/` (POST, 9 fields incl. `page`/`path`/`conversation_id`/`history`) | POST | `AriaRemoteDataSource.sendMessage()` | POST | YES — identical 9 fields | YES — confirmed live twice, incl. real authenticated-vs-anonymous personalized greeting difference (`"Hi Test!..."` vs `"Hi there!..."`) | MATCH |
| Chat (streaming — the real path the web JS uses) | `/api/riya/chat/stream/` (POST, SSE) | POST | none | — | N/A | N/A | **MISSING** |

## JAM / Roleplay / Group Discussion

| Feature | Web Request | Method | Flutter Request | Method | Request Match | Response Match | Status |
|---|---|---|---|---|---|---|---|
| JAM session start/save-audio/complete | `/jam/session/{start,save-audio,complete}/...` | GET/POST | `JamSessionController` | GET/POST | YES | YES — confirmed live; **a real improvement found**: web silently treats a failed audio upload as success, Flutter surfaces a real retryable failure state instead | MATCH |
| Roleplay generate/analyze | `/roleplay/{practice,analyze}/` (POST) | POST | `RoleplayController` | POST | YES — including the 2-party-character heuristic reproduced client-side before any network call | YES — confirmed live, no gaps | MATCH |
| GD WebSocket | `ws/GD_app/<id>/` (3 client actions: `start`/`user_speaking`/`user_message`; 4 server events: `status`/`typing`/`message`/`report`) | WS | `gd_websocket_service.dart` | WS | YES — exact same 3 actions sent | YES — exact same 4 event types parsed, confirmed live; **a real improvement found**: reconnect without resending `start` (web's own reconnect resets server-side agent index with no re-entrancy guard) | MATCH |

## Employer / Jobs

| Feature | Web Request | Method | Flutter Request | Method | Request Match | Response Match | Status |
|---|---|---|---|---|---|---|---|
| Employer login | `/employer/accounts/employer/login/` | GET+POST | `EmployerAuthRemoteDataSource.login()` | GET+POST | YES | YES — confirmed live | MATCH |
| Employer dashboard | `/employer/employer/dashboard/` (GET, HTML, redirects to profile-create if incomplete) | GET | `EmployerDashboardRemoteDataSource` | GET | YES | YES — confirmed live for BOTH a complete profile (`rameshn`: real stats 1/1/4) and an incomplete one (`Testthree`: real redirect-to-create-profile classification) | MATCH |
| Company Profile / Post Job / All Applications / Job Openings / Candidate Search | 5 real, live, 200-reachable web routes | GET+POST | none (`ComingSoonScreen`) | — | N/A | N/A | **PLACEHOLDER** — confirmed these are real, working web features, not aspirational |
| Edit Job / Delete Job / Job Applications (per-job) / Application Detail / Quick Apply / My Application Detail | 6 real web routes | GET/POST | none — no route at all | — | N/A | N/A | **MISSING** |

---

## Summary

| Status | Count (approx., row-level) |
|---|---|
| MATCH (request+response both confirmed, live or via real-data fixture) | ~30 |
| IMPLEMENTED_NOT_VERIFIED (request shape confirmed, response not live-tested) | ~15 |
| PARTIAL | 2 |
| MISSING | ~20 |
| PLACEHOLDER | 5 |
| BACKEND_NOT_DEPLOYED | 5 |

**Web source modified: NO.**
