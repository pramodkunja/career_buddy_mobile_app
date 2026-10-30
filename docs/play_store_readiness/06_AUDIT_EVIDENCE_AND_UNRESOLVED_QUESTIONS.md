# Document 6 — Audit Evidence, Methodology, and Unresolved Questions

## Methodology

This audit was performed by six parallel, independent research passes, each
scoped to a distinct section of the brief, followed by a dedicated
reconciliation pass for one discovered contradiction, followed by synthesis
into Documents 1-5. Every pass was read-only: no file in `Mobile_app/`,
`royalStaffing_CB01`, or `Career_Buddy_LMS` was created, edited, or deleted
to produce these findings (only the six Markdown deliverables themselves
were written, inside `Mobile_app/docs/play_store_readiness/`).

Research passes:
1. Application overview + module/route inventory (Document 1).
2. User roles + registration/authentication (Document 1 §Auth, feeding
   Document 3).
3. Personal data collection inventory, categories A-F (Document 2, Parts
   A-B).
4. Third-party SDKs + Android/iOS permissions/manifest (Document 2, Parts
   C-D).
5. Account deletion and data-retention audit (Document 3, Part A).
6. Subscription/payment flow + support/grievance information (Document 2
   §A7 cross-reference, Document 3 pricing/payment detail, Document 4/5
   support gap).
7. A dedicated reconciliation pass resolving a contradiction between passes
   3 and 4 about Mock Interview's camera usage (see "Conflicts found and
   resolved" below).

## Files and source locations inspected

**Flutter app** (`Mobile_app/`):
- `lib/app/router/app_router.dart`, `route_paths.dart`, `route_guards.dart`
  — read in full.
- `lib/core/network/api_endpoints.dart` (1204 lines) — read in full for
  endpoint-to-backend evidence.
- `lib/core/network/api_client.dart` — read for session/cookie mechanics.
- `lib/features/auth/**` — registration/login/password-reset entities,
  screens, repositories.
- `lib/features/employer/**` (81 files) — surveyed at module/entity level.
- `lib/features/resume/**` (85 files) — surveyed at module level across all
  4 sub-features.
- `lib/features/mock_interview/**` — read in full for the camera/video
  investigation, including `interview_camera_service_impl.dart`,
  `mock_interview_screen.dart`, `mock_interview_controller.dart`,
  `mock_interview_remote_datasource.dart`.
- `lib/features/aria_chat/**` — surveyed for the Buddy/Riya AI data flow.
- `lib/features/skill_up/**`, `certifications/**` — cross-referenced
  against this project's own pre-existing Phase 76-79 audit trail rather
  than re-derived from scratch.
- `lib/features/subscription/**` — plan catalog and checkout controller.
- `pubspec.yaml`, `pubspec.lock` — read in full for dependency audit.
- `android/app/src/main/AndroidManifest.xml` (67 lines), `android/app/
  build.gradle.kts`, `android/build.gradle.kts`, `android/settings.gradle.kts`
  — read in full.
- `ios/Runner/Info.plist` (86 lines), `ios/Podfile` — read in full.

**Django backend** (`royalStaffing_CB01`, primary reference):
- `users/models.py`, `users/views.py`, `users/forms.py`, `users/backends.py`
  — read for registration/auth/profile/encryption findings.
- `accounts_app/views.py`, `accounts_app/forms.py` — employer
  registration/login.
- `core/crypto_fields.py`, `core/skillup_access.py`, `core/navigation.py`.
- `career_app/views.py`, `career_app/models.py` — resume parsing, ATS
  matching, Mock Interview (camera verification + video upload), payment
  order creation/verification/webhook, refund settlement.
- `career_app/admin.py` — `RazorpayPayment` admin read-only confirmation.
- `jobs_app/models.py`, `jobs_app/views.py` — job postings, applications,
  candidate search, `on_delete` cascade behavior.
- `jam_app/views.py` — the "reset progress" precedent.
- `riya_bot/riya_assistant.py`, `riya_bot/views.py`, `riya_bot/
  agents/utils.py`, `riya_bot/skillup_views.py`, `riya_bot/skillup_catalog.py`
  — Buddy/Riya AI data flow, Sarvam/Google provider confirmation.
- `skillup_assessment` app — certificate generation.
- `business_english_lms/settings.py` — checked for auth/third-party
  configuration names only; actual values of business-sensitive settings
  (company identity, API keys, secrets) were deliberately not read/
  disclosed.
- `templates/landing.html`, `templates/pro.html` — footer/contact content,
  pricing copy verification.
- Full-tree searches across `templates/` and every app's `views.py`/
  `urls.py`/`models.py` for: privacy/terms/refund/cookie pages, account-
  deletion logic, soft-delete flags, contact-form logic, grievance
  mentions.

**Career_Buddy_LMS** (secondary/original reference): consulted only for
drift comparison; no material differences were found for the fields audited
here, so it is not separately cited beyond the template-search pass in
Document 1 §1.

## Relevant API endpoints (non-exhaustive — see `api_endpoints.dart` for the
full 1204-line catalog)

`/users/login/`, `/users/register/`, `/users/register/send-otp/`, `/users/
register/verify-otp/`, `/users/password-reset/...`, `/employer/accounts/
employer/login/`, `/employer/accounts/employer/register/`, `career_app`'s
resume-parsing/ATS/mock-interview family (`resume_job_match`,
`resume_camera_verified`, `resume_upload_interview_video`,
`resume_get_next_question`, `resume_submit_answer`, `resume_record_
violation`, `resume_analytics`, `create_razorpay_order`,
`verify_razorpay_payment`, `razorpay_webhook`, `payment_invoice`),
`jobs_app`'s employer family (`job_create`, `job_edit`, `job_applications`,
`search_candidates`, `employer_profile_edit`), `riya_bot`'s assistant family
(`riyaChat`, `riyaChatStream`, `riyaVoiceTranscribe`, `riyaTts`,
`skillup_hub`).

## Relevant Django models/views/serializers (non-exhaustive)

`django.contrib.auth.models.User` (unmodified default), `users.UserProfile`
(`users/models.py:~100-320`), `jobs_app.EmployerProfile`, `jobs_app.
JobPosting`, `jobs_app.JobApplication` (`jobs_app/models.py:~600-621`),
`career_app.Resume`, `career_app.JobDescription`, `career_app.
RazorpayPayment` (`career_app/models.py:184-229`), `career_app.
ResumeInterviewSession`, `skillup_assessment.QuizAttempt`,
`skillup_assessment.Certificate`. `riya_bot` has **no models module at all**
— a confirmed, deliberate architectural fact relevant to the AI
conversation-history finding.

## Evidence supporting the most important findings

- **No account deletion exists**: zero matches for deletion-related UI
  across all of `lib/`; zero matching endpoints across all of
  `royalStaffing_CB01`'s `views.py`/`urls.py`; no soft-delete flag on any
  model (`grep -rniE "is_deleted|deleted_at|soft.?delete" --include=
  "models.py"` → zero matches).
- **Mock Interview records continuous video+audio**:
  `interview_camera_service_impl.dart:33` (`enableAudio: true`), `:46-70`
  (`startVideoRecording`/`stopVideoRecording`), `mock_interview_screen.
  dart:94,104,108`, `mock_interview_controller.dart:437`,
  `mock_interview_remote_datasource.dart:163` (multipart upload to
  `resume_upload_interview_video`), `career_app/views.py:1318-1348`
  (conditional server-side persistence on `session.is_passed`).
- **Aadhaar/PAN/passport are encrypted at rest**: `users/models.py:224-227`
  (`EncryptedCharField`), `core/crypto_fields.py:1-9` (Fernet
  implementation, confirmed from source without reading the key material).
- **Resume text is sent to Sarvam AI**: `career_app/views.py:897`
  (`analyze_resume_with_sarvam(clean_text, jd_text)`).
- **No analytics/crash SDK exists**: full `pubspec.yaml` read; `grep`
  across Android build files for `firebase|crashlytics|sentry|analytics`
  → zero matches; no `google-services.json`/`GoogleService-Info.plist`
  anywhere in the repository.
- **No support contact info exists**: `templates/landing.html:7349-7402`
  (the footer, read in full) contains no email/phone/address; `grep -rn
  "def contact|contact_us|ContactForm"` across all non-vendor `.py` files
  found no contact-form feature.
- **`JobApplication` PII survives account deletion**: `jobs_app/
  models.py:600-601` (`applicant_user = ForeignKey(User, null=True,
  on_delete=SET_NULL)`), fields at `:613-621`.

## Conflicts found and resolved

**Mock Interview camera/video behavior** — two independent research passes
produced contradictory initial claims:
- Pass 4 (third-party/permissions) found the Flutter client genuinely
  implements continuous video+audio recording and upload.
- Pass 3 (data inventory) found a Django endpoint (`resume_camera_
  verified`) that stores only a boolean/timestamp, no file, and concluded
  no video is ever transmitted.

**Resolution**: both were factually correct about what they individually
read, but each had found only one of **two distinct Django endpoints** that
exist for this one feature — `resume_camera_verified` (start-of-interview
boolean gate, no file) and `resume_upload_interview_video` (end-of-
interview video upload, conditionally persisted). A dedicated follow-up
pass read both the full Flutter call chain and both Django view functions
together and confirmed: the app does record and upload continuous video
and audio on every attempt; the backend persists the file only for passing
sessions. This resolved finding is what appears in Documents 1, 2, and 5.
It is flagged here explicitly as an example of why this audit used
independent, source-verifying passes rather than accepting a single
pass's claim at face value — and as a **real, separate finding in its own
right**: the in-app code contains a comment claiming "this app doesn't
record continuous video today," which is **stale and factually wrong**.
**Recommend the engineering team correct or remove that comment**, since
anyone relying on it (including a future privacy audit) would reach the
wrong conclusion.

## Unverified functionality (explicitly not claimed as confirmed)

- Whether the Free-plan 4-upload Resume Parsing limit is enforced
  server-side or only shown as marketing copy.
- Whether employer accounts have any subscription/paid tier distinct from
  the candidate Pro plan.
- The exact field list of the `Resume`/`JobDescription` ATS-flow models
  (their usage was traced; their full schemas were not transcribed).
- Whether a certificate-file **upload** feature exists anywhere (the
  Certifications module appears to be about *earning* in-app certificates,
  not uploading external ones, but this was not separately, exhaustively
  re-audited).
- The exact OTP send-rate-limit and login-lockout thresholds.
- Whether `google_fonts` fetches assets from Google's CDN at runtime or
  uses bundled fonts.
- Whether `NSPhotoLibraryUsageDescription`'s absence is truly safe on all
  iOS versions this app targets (depends on runtime OS behavior, not
  verifiable from source alone).
- Whether all production API traffic is HTTPS-only (outside this
  audit's scope — no server/infrastructure configuration was inspected).
- Sarvam AI's and Google's own data retention/training policies on
  submitted content (outside this codebase by definition).

## Missing implementation (confirmed gaps, not merely unverified)

- No account-deletion mechanism, in-app or backend.
- No `/profile` screen (`ComingSoonScreen` placeholder) despite a complete
  domain model already existing.
- No in-app subscription cancellation/management screen.
- No in-app refund-request flow (refunds are a manual, outside-the-app
  Razorpay process).
- No support/contact information anywhere in the app or the local template
  checkouts.
- No named grievance/privacy officer.
- No data-retention policy code or scheduled-deletion job anywhere.
- No age-verification or minimum-age field in registration.

## Conflicting behavior between Flutter and Django worth flagging

- The iOS `NSCameraUsageDescription` string ("a live camera check") does
  not match the actual, more significant behavior (continuous recording +
  upload) implemented in both the Flutter client and the Django backend.
- `RazorpayPayment.invoice_number` is documented in its own code comment as
  a GST tax-invoice serial that "must never shift," yet its `on_delete` is
  `CASCADE` with the user — inconsistent with the record's own stated
  importance.
- The Manual Resume Builder is gated login-only in the Flutter app **by
  deliberate product decision**, even though the real backend endpoint
  itself carries no login requirement — not a bug, but worth the business
  knowing the client is stricter than the server here.

## Questions requiring business, legal, or backend-team confirmation (recap)

See Document 4's "Business/legal questions" section and Document 5, Part G
for the consolidated list — repeated here for completeness:
1. Legal entity name/address for the Privacy Policy (likely already in
   `settings.py`).
2. Real support email/phone/address and a named grievance officer.
3. Data-retention periods for every data category.
4. Policy for `JobApplication` and `RazorpayPayment` data after account
   deletion.
5. Minimum-age / children's-privacy stance.
6. Whether the Razorpay-only payment model needs a dedicated Google Play
   payments-policy review.
7. Whether/when to invest in real backend account-deletion capability.
8. Whether to update the iOS camera-permission string.
9. Whether employers have a distinct paid tier.
10. Whether to surface JAM's existing "reset progress" capability, and any
    future account-deletion capability, inside the Flutter app itself.
