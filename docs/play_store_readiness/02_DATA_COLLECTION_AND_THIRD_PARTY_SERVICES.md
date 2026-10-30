# Document 2 — Data Collection, Processing & Third-Party Services

Read-only audit. Evidence cited as `file:line` wherever practical. Values
that cannot be verified from source are marked **Unknown / Requires
confirmation** — never guessed or invented. Credentials/secrets are never
printed; providers are named without exposing key values.

Primary backend reference: `royalStaffing_CB01`. Flutter app: `Mobile_app/`.

---

## Part A — Personal data collection inventory

### A1. Personal information

| Field | Collected where | Required? | Storage | Evidence |
|---|---|---|---|---|
| First/last name | Registration (both roles) | Required | Django `User.first_name`/`last_name` | `student_registration_data.dart:19-20` |
| Email | Registration (both roles) | Required | `User.email` | — |
| HR contact email (employer) | Employer registration | Required | `EmployerRegisterForm` | `employer_registration_data.dart:40` |
| Username | Registration | Required | `User.username` | `student_registration_data.dart:22` |
| Mobile / alternate mobile | Registration | Mobile optional for candidate; HR phone required for employer | `UserProfile` | `users/models.py:207-208` |
| Third-party contact (a referenced employer's HR contact name/mobile/email) | Candidate registration, optional | Optional | `UserProfile` | `student_registration_data.dart:46-48` — **this is personal data about someone other than the account holder**, worth flagging separately in the Privacy Policy |
| Gender | Candidate registration, optional | Optional | `UserProfile.gender` | `users/models.py:206` |
| Date of birth | — | **Not collected anywhere** — confirmed absent from every model/entity inspected | — | — |
| Blood group | Candidate registration, optional | Optional | `UserProfile.blood_group` | `users/models.py:208` — sensitive health-adjacent data |
| Selfie | Candidate registration, optional (server supports it; **not implemented in the Flutter form** — a documented scope decision) | Optional, server-side only | `UserProfile.selfie`, `upload_to='selfies/'` | `users/models.py:219` |
| Avatar/profile photo | Profile | Optional | `UserProfile.avatar`, `upload_to='avatars/'` | `users/models.py:113` |
| Company logo | Employer registration, optional | Optional | `accounts_app/forms.py` | `employer_registration_data.dart:19` |
| Address (city-level only) | Candidate `current_location`/`preferred_location` | Free text, not structured | `UserProfile` | `users/models.py:279-280` |
| Address (free text) | Employer `company_address`, optional | Optional | Employer profile table | `employer_registration_data.dart:22` |
| **Aadhaar number** | Candidate registration | **Required** | `UserProfile.aadhar_number`, encrypted at rest | `users/models.py:224-227` |
| **PAN number** | Candidate registration | Optional | `UserProfile.pan_number`, encrypted at rest | same |
| **Passport number** | Candidate registration | Optional | `UserProfile.passport_number`, encrypted at rest | same |

**Encryption finding (notable, positive)**: Aadhaar/PAN/passport are the
only three fields using `EncryptedCharField` (`core/crypto_fields.py`) — a
real, Fernet-based, application-level field encryption, confirmed from
source. This is specific to these three fields; it must not be generalized
into a blanket "all data is encrypted" claim anywhere in the Privacy
Policy. The exact key-management scheme was not inspected (out of scope,
and not something a public Privacy Policy would normally need to detail).

### A2. Professional and educational information

| Field | Purpose | Visible to | Evidence |
|---|---|---|---|
| Education (2 full sets + optional JSON array) | Job matching | Employer candidate search | `student_registration_data.dart:87-96`; `users/models.py:228-247` |
| Skills, experience years, current/expected CTC, certification (free text) | Job matching | Employer candidate search | `users/models.py:253-264` |
| Career preferences (location, abroad-experience block) | Job matching | Employer candidate search | `users/models.py:279-285` |
| Resume file | Registration (required) + optional repeated ATS-matcher uploads | Employer candidate search; AI analysis | `users/models.py:21-33`; `career_app/views.py:852-897` |
| **Resume extracted text (plaintext)** | Made searchable for employers; AI ATS analysis | Employer candidate search; **Sarvam AI** | `users/models.py:282-283,300-318`; `career_app/views.py:890,897` |
| Job description text (ATS flow) | AI resume-to-JD matching | **Sarvam AI** | `career_app/views.py:852,897,903` |
| Employer company info (name, industry, GST, PAN/TIN, address, logo) | Company profile, job postings | Public job listings (name) | `employer_registration_data.dart:15-47` |
| Job application record (name, email, phone, resume, cover letter, skills, salary) | Submitted when a candidate applies | The receiving employer | see Document 3 — **this record persists even after a hypothetical account deletion** |

### A3. Uploaded files

| File type | Purpose | Storage/retention | Evidence |
|---|---|---|---|
| Resume (registration) | Required at signup; searchable by employers | `UserProfile.resume`, hashed filename, **overwritten on re-upload** (no version history) | `users/models.py:21-33` |
| Resume (ATS-matcher) | Repeated analysis runs | A separate `Resume` row per upload; retention policy `Unknown / Requires confirmation` | `career_app/models.py` |
| Selfie | Optional, registration (server-side field only; unused by the Flutter form) | `upload_to='selfies/'`; retention `Unknown / Requires confirmation` | `users/models.py:219` |
| Avatar | Profile picture | `upload_to='avatars/'`; retention `Unknown / Requires confirmation` | `users/models.py:113` |
| Company logo | Employer registration | retention `Unknown / Requires confirmation` | `accounts_app/forms.py` |
| **Interview video (Mock Interview)** | Anti-malpractice record of the AI mock interview | **Persisted only if the session passed** (`session.is_passed`); otherwise uploaded then discarded unpersisted server-side | `career_app/views.py:1318-1348` (see Part B below for the full, resolved finding) |
| Certificate PDF | Generated on request, contains the user's own name | Skill-Up certifications module; retention `Unknown / Requires confirmation` | `skillup_assessment` app |
| Certificates (external documents, e.g. a scanned degree certificate) | **No dedicated upload field was found anywhere** for this | — | Confirmed absent in the models/entities inspected; the in-app "Certifications" module is about *earning* in-app certificates, not uploading external ones |

**Important exposure characteristic (source-documented, not inferred)**:
registration resumes are served from `MEDIA_URL` **with no login check** —
the backend's own code comment states the filename is deliberately a
non-guessable hashed token specifically to prevent "a trivial bulk-download
of every candidate's résumé by iterating small integers"
(`users/models.py:22-30`). In plain terms: **anyone who obtains a specific
resume's URL can view that file without logging in** — the protection is
"the URL is hard to guess," not "the server checks who's asking." This
should be disclosed candidly in the Privacy Policy's security section
rather than omitted.

### A4. Application and technical information

- **Device/app info**: no device-info-collection package (e.g.
  `device_info_plus`) exists in `pubspec.yaml`. Standard HTTP headers
  (User-Agent, IP) reach Django as part of normal request handling; exact
  server log retention is `Unknown / Requires confirmation`.
- **Crash logs / analytics**: **confirmed absent** — no Firebase, Sentry,
  Crashlytics, or any analytics SDK exists anywhere in the project (full
  `pubspec.yaml` read, Android/iOS build config grepped, no
  `google-services.json`/`GoogleService-Info.plist` found).
- **Session data**: a Django session cookie, persisted on-device via a
  plain file-backed cookie jar (`cookie_jar`/`dio_cookie_manager`,
  `lib/core/network/api_client.dart:43-47`) in app-private storage — **not**
  OS Keychain/Keystore. Separately, exactly two small cached values
  (`auth.cached_username`, `auth.cached_is_employer`) use real OS-secure
  storage via `flutter_secure_storage`. The same secure-storage service is
  also reused (unrelated to auth) for locally-cached resume-builder drafts
  and mock-test attempt history.
- **Learning/activity progress**: per-user progress and exercise scores are
  stored server-side (`UserProfile.get_total_completed()`/
  `get_total_score()`, reading related progress/exercise-result tables).

### A5. AI-related information — Riya / ARIA assistant

**External provider confirmed: Sarvam AI** (`api.sarvam.ai`), used for
three distinct purposes (all confirmed directly from
`royalStaffing_CB01/riya_bot/riya_assistant.py` and `career_app/views.py`):

1. **Chat/assistant replies** — each chat turn sends the user's message,
   current page name/summary, input mode, the list of navigable actions for
   that user's role, and, from within Skill-Up, a grounding block, to
   Sarvam's chat-completion endpoint (model `sarvam-105b`). If
   authenticated, the user's **first name only** is included so the
   assistant can address them by name. **No resume content or other profile
   fields are included in this payload** (confirmed by reading the full
   payload construction).
2. **Resume/ATS analysis** — a separate, more significant flow: the **full
   extracted resume text** and **full job-description text** are sent to
   Sarvam AI for matching/analysis (`career_app/views.py:897`,
   `analyze_resume_with_sarvam`).
3. **Voice** — speech-to-text and most text-to-speech calls also go to
   Sarvam AI; a **separate TTS path exists for Google** for some
   languages/voices (`GOOGLE_TTS_LANGS`, `riya_bot/agents/utils.py`) — so
   **Google is a second, confirmed external voice-processing provider**.
4. **Conversation history**: **not persisted server-side** — the `riya_bot`
   Django app defines no models at all, and the chat endpoint reads
   `history` directly from each incoming request rather than a database.
   On the Flutter side, chat history lives only in in-memory Riverpod state
   with no local-persistence package referenced anywhere — it does not
   survive an app restart. **Conversation history is ephemeral on both
   sides of this app**; it is forwarded to Sarvam AI per request only.
5. **Sarvam's / Google's own retention or training behavior on submitted
   data cannot be verified from this codebase** — `Unknown / Requires
   confirmation` directly from those vendors' own data-processing terms.

### A6. Camera (Mock Interview) — resolved finding

Two investigative passes initially produced conflicting claims about this
feature; the discrepancy was deliberately resolved by a dedicated follow-up
read of both the Flutter and Django source, reconciling two genuinely
separate backend endpoints that had been conflated:

- **What is captured**: `InterviewCameraServiceImpl`
  (`lib/features/mock_interview/data/services/interview_camera_service_impl.dart:33`)
  opens the front camera with `enableAudio: true` and implements a real,
  working `startVideoRecording()`/`stopVideoRecording()` pair (lines
  46-70) — **this is a genuine continuous video+audio recording of the
  entire interview**, not merely a live preview. (An in-code comment nearby
  claiming "this app doesn't record continuous video today" is **stale and
  factually incorrect** — flagged as a documentation/code conflict in
  Document 6.)
- **What is transmitted**: `mock_interview_screen.dart:94` starts recording
  when the camera gate is passed; `:104`/`:108` stop recording and upload
  the file when the interview ends, via
  `MockInterviewRemoteDataSource.uploadInterviewVideo`
  (`mock_interview_remote_datasource.dart:163`) → a multipart POST to
  `resume_upload_interview_video` (`/resume-builder/upload-interview-
  video/`).
- **Two distinct Django endpoints exist**, which is what caused the
  original conflation: (1) `resume_camera_verified`
  (`career_app/views.py:1194`) — sets only a `camera_verified_at`
  timestamp at the **start** of the interview, no file. (2)
  `resume_upload_interview_video` (`career_app/views.py:1318-1348`) —
  receives the **actual video file** at the **end** of the interview and,
  **only if the session's score passed** (`session.is_passed`, line 1346),
  saves it to the `interview_video` field; otherwise the uploaded file is
  discarded server-side, unpersisted.
- **Conclusion**: the app genuinely records and uploads continuous video
  and audio of the candidate for every mock interview attempt; the backend
  conditionally **retains** that file only for passing attempts. **This is
  the single most significant personal/biometric-adjacent data-capture fact
  in the application and must be disclosed prominently** in the Privacy
  Policy and the Play Data Safety declaration (likely under both
  Audio/Video and, depending on how strictly the business wants to
  categorize it, a biometric-adjacent category — flag for legal review on
  the exact Play category).

### A7. Payment and subscription information

| Item | Stored | Evidence |
|---|---|---|
| Razorpay payment ID, order ID, invoice number, plan, amount (paise), currency, status | `RazorpayPayment` model | `career_app/models.py:184-229` |
| Card/bank/UPI details | **Never reaches this app or its backend** — handled entirely by Razorpay's own checkout UI/SDK; no such field exists on any model or Flutter entity | Confirmed by architecture — `razorpay_flutter`'s integration pattern (`key`/`order_id`/`amount`/`prefill` only) |
| Subscription plan state | `UserProfile.plan_type`, `subscription_start`, `pending_expiry_notice` — a single mutable field, not an append-only ledger | `users/models.py:112-141` |

See Document 1 §13-equivalent detail (reproduced fully in Document 5's Play
Console payments section) for the full checkout/verification/refund flow.

---

## Part B — Summary data inventory table

| Data category | Specific data | Where collected | Purpose | Sent to backend/provider | Storage location | Third-party sharing | Retention/deletion | Evidence/status |
|---|---|---|---|---|---|---|---|---|
| Personal | Name, email, username | Registration (both roles) | Account identity, login | Django `User` | `auth_user` table | None found | Unknown / Requires confirmation | `student_registration_data.dart:19-22` |
| Personal | Mobile numbers | Registration | Contact | `UserProfile` | DB | None found | Unknown / Requires confirmation | `users/models.py:207-208` |
| Personal | Gender, blood group | Registration (optional) | Profile | `UserProfile` | DB | None found | Unknown / Requires confirmation | `users/models.py:206,208` |
| Personal | Selfie, avatar, company logo | Registration/profile (optional) | Identity/display | ImageField uploads | `media/selfies/`, `media/avatars/` | None found | Unknown / Requires confirmation | `users/models.py:113,219` |
| Personal | City-level location | Registration/profile | Job matching | `UserProfile` | DB | None found | Unknown / Requires confirmation | `users/models.py:279-280` |
| Personal (sensitive) | Aadhaar, PAN, passport numbers | Candidate registration | Identity verification | `UserProfile` | **Encrypted at rest (Fernet)** | None found | Unknown / Requires confirmation | `users/models.py:224-227` |
| Professional | Education, skills, experience, CTC, certifications | Registration/profile | Job matching, candidate search | `UserProfile` | DB | Visible to employers via search | Unknown / Requires confirmation | `users/models.py:228-264` |
| Professional | Resume file + extracted text | Registration + ATS flow | Job matching, AI analysis | `UserProfile.resume`/`resume_text`; `Resume` model | `media/resumes/`; DB | **Sarvam AI** (ATS flow) | Unknown / Requires confirmation | `career_app/views.py:852-897` |
| Professional | Job description text | ATS flow | AI matching | `JobDescription` model | DB | **Sarvam AI** | Unknown / Requires confirmation | `career_app/views.py:852,897,903` |
| Professional | Job application PII (name/email/phone/resume/salary) | Applying to a job | Recruiting | `JobApplication` | DB | The receiving employer | **Persists after a hypothetical account deletion** (see Document 3) | `jobs_app/models.py:600-621` |
| Technical | Session cookie | Login | Authentication | Django session framework | Server session store + on-device file-backed cookie jar | None found | Unknown / Requires confirmation | `api_client.dart:5,44` |
| Technical | Crash/analytics data | — | — | — | — | — | — | **Confirmed not collected — no SDK present** |
| Technical | Learning progress & scores | Using learning modules | Progress tracking, certificates | Progress/exercise-result tables | DB | None found | Unknown / Requires confirmation | `users/models.py` |
| AI | Chat text, page context, first name | Using Buddy/Riya | Conversational assistant | **Sarvam AI** | Not persisted server-side; client in-memory only | **Sarvam AI** | Ephemeral — confirmed, not stored beyond the live request | `riya_bot/riya_assistant.py`, `riya_bot/views.py` |
| AI | Resume + job-description text | ATS analysis | AI matching | **Sarvam AI** | DB (the source text); request-only at Sarvam | **Sarvam AI** | Unknown / Requires confirmation | `career_app/views.py:897` |
| AI | Spoken audio / transcribed speech | Voice input | STT/TTS | **Sarvam AI**, and **Google** for some TTS paths | Not found to be persisted | **Sarvam AI**, **Google** | Unknown / Requires confirmation | `riya_bot/agents/utils.py` |
| Biometric-adjacent | **Continuous interview video + audio** | Mock Interview | Anti-malpractice verification | First-party backend (`resume_upload_interview_video`) | `interview_video` field, **only if the session passed**; discarded unpersisted otherwise | None found | Conditional — persisted only for passing sessions; no further retention/deletion logic found | `career_app/views.py:1318-1348`; `interview_camera_service_impl.dart:33-70` |
| Payment | Razorpay payment/order IDs, invoice number, amount, plan, status | Checkout | Billing, invoicing | Razorpay (verify + webhook) | `RazorpayPayment` table | **Razorpay** | Unknown / Requires confirmation — `CASCADE`s with the user today, see Document 3 | `career_app/models.py:184-229` |
| Payment | Card/bank/UPI details | Checkout | Payment processing | **Razorpay only — never reaches this app** | Not stored here | **Razorpay** | N/A to this app | Confirmed by architecture |

**Biggest unresolved unknowns**: exact backend retention/deletion periods
for every stored field (no retention-policy code or scheduled-deletion job
found anywhere); the full field list of the `Resume`/`JobDescription`
models (usage traced, full schema not read); Sarvam's and Google's own data
retention/training policies (outside this codebase by definition).

---

## Part C — Third-party services, SDKs and integrations

### C1. Explicit absence confirmations (checked directly)

- **No Firebase module of any kind** (Analytics, Crashlytics, FCM, Auth,
  Remote Config) — no `google-services.json`/`GoogleService-Info.plist`
  anywhere in the repo.
- **No Google Sign-In, Facebook SDK, Sentry, ad SDK, or standalone
  analytics SDK.**
- **No `permission_handler` package** — runtime permission prompts come
  entirely from each plugin's own built-in OS request flow.
- No manually-added native Android/iOS SDK beyond what Flutter's own
  plugins bring in (`android/build.gradle.kts`, `ios/Podfile` both read in
  full).

### C2. Third-party service table

| Provider/service | Purpose | Data involved | Trigger | Evidence | Privacy-policy relevance |
|---|---|---|---|---|---|
| **Razorpay** | Subscription checkout | Payment amount/order id/plan to the checkout UI; raw card/UPI/bank data handled entirely by Razorpay itself | Tapping Subscribe/Upgrade | `lib/features/subscription/.../razorpay_checkout_launcher.dart` | **Directly verified** — must be disclosed as a payment processor |
| **Sarvam AI** | Chat replies, resume/ATS analysis, speech-to-text, most text-to-speech | Chat text + page context + first name; full resume + JD text; spoken audio/transcripts | Using Buddy, submitting a resume for ATS, using voice input | `riya_bot/riya_assistant.py`, `career_app/views.py:897`, `riya_bot/agents/utils.py` | **Directly verified** — a backend-side (Django→Sarvam) integration; must be disclosed as an AI/voice data processor |
| **Google** (TTS only, specific languages) | Text-to-speech for a subset of languages/voices | Text to be spoken | Buddy voice replies in those languages | `GOOGLE_TTS_LANGS`, `riya_bot/agents/utils.py` | **Directly verified** — a second voice-processing vendor, distinct from any Google Android service |
| On-device speech recognition (`speech_to_text` plugin) | Live transcription for Timer exercise, Group Discussion, Mock Interview's question view | Spoken audio, processed via the OS's own native speech API | Speaking during those features | `gd_speech_service_impl.dart`, `timer_speech_service_impl.dart` | **SDK present; whether the OS itself routes to a cloud speech service is platform/device-dependent, outside this app's control** — mark OS-level behavior Unverified, not a direct integration by this app |
| `webview_flutter` | Renders Skill-Up's static lesson pages | Loads only `${baseUrl}/static/001 Career Buddy/...` — **the app's own backend, never a third-party/external URL** | Opening a Skill-Up lesson | `skill_up_lesson_screen.dart:139-140`; `environment.dart:99-121` | No third-party content loaded |
| `video_player` | Grammar lesson videos; Home tutorial video | Plays files from the app's own protected media / static endpoints only | Opening a video | `grammar_video_player_sheet.dart:38`; `home_tutorial_video_dialog.dart:41` | First-party only — no YouTube/Vimeo embed |
| `web_socket_channel` | Group Discussion's live session | Real-time messages over the app's own Django Channels backend | Starting a session | `pubspec.yaml` comment | First-party real-time channel |
| `flutter_secure_storage` | OS Keychain/Keystore-backed storage for a small set of cached values | Cached username/employer-flag, local resume-draft/mock-test-history caches | App usage | `secure_storage_service.dart` | OS-level, not a third-party cloud service |
| `cookie_jar`/`dio_cookie_manager` | Persists the Django session cookie on-device | The session cookie itself | Every authenticated request | `api_client.dart` | First-party session mechanism |
| `google_fonts` | Loads the app's font stack | Font assets — **whether this build bundles fonts locally or fetches from Google's CDN at runtime was not verified** | App startup | `pubspec.yaml` comment | `Requires confirmation` — if CDN-fetched, a minor IP-address-level network call to Google at font-load time |
| `image_picker` / `file_picker` | Logo/resume selection from the device | A single user-selected file | Employer registration, Resume Parsing | `employer_register_screen.dart:77` | Local picker only; selected file is uploaded to the app's own first-party backend |
| `open_file` | Opens a downloaded file in another installed app | The local file path, handed to a user-chosen app | Tapping "Open" on a document | `pubspec.yaml` comment | Standard OS file hand-off |
| `url_launcher` | Opens browser/mailto/tel links | A URL/email/phone number | Tapping a link | `pubspec.yaml` comment | Standard OS intent hand-off |

Dev-only dependencies (`fake_async`, `html`, platform-interface packages,
`flutter_lints`) never ship in the compiled app and are not relevant here.

### C3. Camera and microphone — permissions and precise usage

See Section A6 above for the full Mock Interview camera finding. The
microphone (`record` plugin) is additionally used for: AI Speaking practice
(audio sent to the backend for transcription/evaluation), Buddy voice
input, Group Discussion, Timer exercise, JAM, and Roleplay.

---

## Part D — Android/iOS permissions and manifest audit

### D1. Android (`android/app/src/main/AndroidManifest.xml`, read in full)

| Permission | Purpose (verified) | Feature | Required/optional | Runtime-requested? | App functions without it? | Play Console disclosure |
|---|---|---|---|---|---|---|
| `INTERNET` | All network access | Entire app | Required | No (install-time) | No — the app is fundamentally networked | Not a "dangerous" permission |
| `RECORD_AUDIO` | Microphone capture | AI Speaking, Buddy voice input, Group Discussion, Timer exercise, JAM, Roleplay, Mock Interview's audio track | Required for those features only | Yes, via each plugin's own native prompt | Partially — non-audio features still work | **Yes** — sensitive permission, Data Safety disclosure required |
| `CAMERA` | Live preview + **continuous video recording** | Mock Interview | Required for Mock Interview only | Yes, via the `camera` plugin's own native prompt | Yes for every other feature | **Yes** — sensitive permission, Data Safety disclosure required |
| `<uses-feature android:name="android.hardware.camera" required="false">` | Declares camera hardware is used but not install-mandatory | N/A | Optional by design | N/A | Yes | No runtime-permission disclosure; informs device filtering only |

No `READ_EXTERNAL_STORAGE`/`WRITE_EXTERNAL_STORAGE` is declared (consistent
with the modern system picker used by `image_picker`/`file_picker`). **No
declared-but-unused permission was found** — all three real permissions
have a confirmed, active call site.

### D2. iOS (`ios/Runner/Info.plist`, read in full)

| Key | Shown purpose string | Feature | Required/optional |
|---|---|---|---|
| `NSMicrophoneUsageDescription` | "Career Buddy needs microphone access to record your speaking practice for AI feedback." | AI Speaking (and, functionally, every other audio-using feature — the shown string names only AI Speaking, a minor wording gap worth tightening) | Required for audio features only |
| `NSCameraUsageDescription` | "Career Buddy needs camera access for the AI Mock Interview's live camera check." | Mock Interview — **this description undersells what actually happens: it mentions only a "check," not a full continuous recording that is uploaded** — recommend the business update this string to accurately describe the recording before the next App Store submission | Required for Mock Interview only |
| `NSSpeechRecognitionUsageDescription` | "Career Buddy uses on-device speech recognition to capture your spoken answers." | Timer exercise, Group Discussion, Mock Interview's question view | Required for those features only |

No `NSPhotoLibraryUsageDescription` is declared even though `image_picker`
is used for the employer logo upload — likely not a gap, since
`image_picker` on iOS 14+ defaults to `PHPickerViewController`, which does
not require this key (Apple's picker runs out-of-process). **This should
still be confirmed empirically during an actual App Store Connect/
TestFlight submission**, since it depends on exact OS-version runtime
behavior not verifiable from source alone.

---

## Summary for the parent audit

- No analytics, crash-reporting, advertising, or social-login third-party
  SDK exists in this app — do not invent a Firebase/Crashlytics/AdMob
  disclosure where none applies.
- **Razorpay**, **Sarvam AI**, and **Google** (TTS only) are the three
  confirmed external data processors.
- **The single most important disclosure item for the whole audit**: Mock
  Interview records continuous video and audio of the candidate and uploads
  it to the backend, which retains it only for passing sessions. The
  in-app camera permission description currently undersells this.
- Camera and microphone are the only two Android "dangerous" permissions;
  both have confirmed, narrowly-scoped, legitimate feature usage — no
  evidence of background/always-on capture.
- `google_fonts`'s exact runtime network behavior is the one minor open
  item in the third-party section requiring a quick follow-up.
