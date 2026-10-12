# Phase 9 — Mock Interview: Typed-Answer & Proctoring Decision Audit

Audit-only phase. No application source, test, dependency, configuration,
or backend file was modified in either repository. No implementation was
attempted. This report is the only file created this phase.

## 1. Executive summary

Both previously-identified gaps are **confirmed still open** against current
source (re-verified, not assumed from prior reports):

- **Typed answers**: the web interview (`templates/resume_interview.html`)
  has **no text input for theory questions at all** — only a microphone
  button driving the Web Speech API plus a server-side Sarvam STT refinement
  call. A plain `<textarea>` exists only for **coding** questions. Flutter's
  `MockInterviewQuestionView` shows an always-available `TextField` for
  **every** question (theory and coding alike), with on-device
  `speech_to_text` layered on top only when the plugin initializes
  successfully. This is a genuine, confirmed behavioral difference — not a
  stale finding.
- **Face detection / proctoring**: the web page genuinely runs `face-api.js`
  (a real, loaded-from-CDN, on-device face-presence/count model — not
  identity verification) against the live camera feed every 1.5s during the
  interview, and reports `FACE_NOT_DETECTED`/`MULTIPLE_FACES` as
  server-recorded violations. Flutter implements the mandatory-camera gate,
  continuous video recording, and app-lifecycle-based tab-switch/background
  detection, but **no face-presence monitoring of any kind** — confirmed via
  both the controller's own doc comment and the absence of any face-detection
  dependency in `pubspec.yaml`.
- **Technically important finding for both**: the backend contract already
  supports both without any backend change. `resume_submit_answer` accepts
  any `answer_text` regardless of its origin (voice-transcribed or typed) —
  the server does not distinguish. `resume_record_violation` already accepts
  `FACE_NOT_DETECTED`/`MULTIPLE_FACES` as valid violation types (this is
  mirrored correctly in Flutter's `ViolationType` enum already, just never
  triggered). The only missing piece for proctoring is an **on-device face
  detection capability**, which does not currently exist in this codebase
  and is not a small addition.
- This report makes **no implementation changes** and takes **no product
  decision** on the user's behalf. Section 11 lists exactly which decisions
  require the project owner's input.

## 2. Scope and files inspected

**Required prior reports read this phase**:
`docs/PHASE_5_REMAINING_PARITY_REVIEW.md` (full),
`docs/PHASE_7_GD_JAM_LANGUAGE_SELECTION_REPORT.md` (read in a prior session
this conversation continues from — unrelated to Mock Interview, consulted
for continuity only), `docs/PHASE_8_MOCK_INTERVIEW_SUITABLE_JOBS_REPORT.md`
(authored immediately prior in this same engagement),
`docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` (Mock Interview rows),
`docs/PRE_UPDATE_BASELINE_REPORT.md` (checked for Mock Interview/camera/voice
mentions — none found; it predates this feature's build-out).

**Django/web files read this phase** (read-only):
- `templates/resume_interview.html` (all 1869 lines — confirmed via
  `TEMPLATES['DIRS']` in settings that this file, not the 352-line
  `ResumeBuilder_module/templates/resume_interview.html`, is the one Django
  actually renders, since `DIRS` is checked before `APP_DIRS`).
- `career_app/views.py` — `resume_start_interview` (930-957),
  `resume_interview_chat` (959-972), `_save_timeout_answer` (982-995),
  `_score_and_finalize_session` (998-1018), `resume_camera_verified`
  (1021-1038), `resume_violation_state` (1047-1064),
  `resume_record_violation` (1067-1142), `resume_upload_interview_video`
  (1145+), `resume_get_next_question` (~1180-1311), `resume_submit_answer`
  (1313-1369), `resume_transcribe_answer` (1372-1479+), `resume_analytics`
  (1506-1601, re-confirmed from Phase 8).
- `career_app/models.py` — `ResumeInterviewSession` (26-67), `ResumeQuestion`
  (70-100), `ResumeAnswer` (103-114), `InterviewViolation` (117-159).

**Flutter files read this phase** (read-only — no edits):
- `lib/features/mock_interview/presentation/widgets/mock_interview_question_view.dart`
- `lib/features/mock_interview/presentation/widgets/mock_interview_camera_gate_view.dart`
- `lib/features/mock_interview/data/services/interview_camera_service_impl.dart`
- `lib/features/mock_interview/presentation/controllers/mock_interview_controller.dart`
- `lib/features/mock_interview/domain/entities/malpractice.dart`
- `lib/features/mock_interview/domain/entities/interview_question.dart`
- `lib/core/network/api_endpoints.dart` (the `resume*` block)
- `pubspec.yaml` (dependency check only)
- `android/app/build.gradle.kts`, `ios/Podfile` (platform version check only)
- `mock_interview_screen.dart`, `mock_interview_results_view.dart` (already
  fully read in Phase 8 this session; re-confirmed, not re-pasted here)

**Read-only commands run** (no state changed by any of them):
- `grep -rn "cameraInterrupted|CameraRequiredFailure|camera_required" lib/features/mock_interview/`
- `grep -n "camera:|speech_to_text:|google_mlkit|tflite|ml_kit|face" pubspec.yaml`
- `grep -rn "minSdk|minSdkVersion" android/app/build.gradle*` /
  `grep -n "platform :ios" ios/Podfile`
- `grep -n "resume.*nterview|resumeTranscribe|..." lib/core/network/api_endpoints.dart`
- `find . -iname "*interview*"` in the Django repo
- `grep -n -A 15 "^TEMPLATES" settings.py`
- `diff templates/resume_interview.html ResumeBuilder_module/templates/resume_interview.html`

No `flutter test`/`flutter analyze`/build was run this phase — not needed
for a static, read-only audit, per the task's own instruction not to run
the full suite without a specific reason.

## 3. Verified Django/web behavior

### Answer capture (voice vs. typed)

- **Theory questions**: no text input exists in the markup at all. The only
  answer-entry affordance is `#speak-btn` (a microphone icon,
  `resume_interview.html:552`) plus a read-only live-transcript preview
  (`#speech-preview-text`, line 528). **Source-verified.**
- **Coding questions**: a real `<textarea id="coding-answer">` exists
  (lines 534-538), shown only when `currentIsCoding` is true, submitted via
  `submitCodingAnswer()`. Typed input is real but **scoped to coding
  questions only**. **Source-verified.**
- **Voice flow**: `toggleSpeak()` (979-1001) starts both (a) the Web Speech
  API (`ensureRecognition()`, 911-937) for an instant, client-side-only live
  transcript, and (b) a parallel `MediaRecorder` audio capture
  (`initRecorder()`, 953-976). On stop, `submitSpokenAnswer()` (1065-1141)
  POSTs the recorded blob to `resume_transcribe_answer`, which calls Sarvam
  AI's `/speech-to-text` endpoint (`career_app/views.py:1374-1479`) for a
  more accurate transcript; the returned text **replaces** the live
  Web-Speech transcript before scoring, only falling back to the live text
  on an exception (not on an explicit server error — see `submitSpokenAnswer`
  vs `forceSubmitSpokenAnswer`'s different error-handling, below).
  **Source-verified.**
- **If the browser lacks `SpeechRecognition`** (not Chrome/Edge): `toggleSpeak()`
  shows `"⚠️ Live voice input needs Chrome or Edge. Please switch browser."`
  and does nothing further — **there is no fallback path at all** for a
  theory question in an unsupported browser. **Source-verified.**
- **If the microphone permission is denied**: `initRecorder()`'s
  `getUserMedia` call throws, is caught, and returns `false` (953-976) —
  but `toggleSpeak()` still calls `rec.start()` on the Web Speech object
  regardless (which itself also needs mic permission). `interviewRecognition.onerror`
  is an empty no-op (935) — so a denied permission produces **no visible
  error to the candidate at all**; they see "Listening…" indefinitely with
  no transcript ever appearing. **Source-verified** (this is a pre-existing
  web-side UX gap, not something this audit was asked to fix, noted for
  completeness since the task asks about permission-denial handling).
- **Silence / no speech detected**: `stopSpeaking()` (1003-1024) shows
  `"No speech detected. Tap Speak to try again."` when `finalTranscript` is
  empty — the candidate can retry freely (no attempt limit). **Source-verified.**
- **STT failure on manual submit**: `submitSpokenAnswer()` shows an
  `alert()` with the server's error (or a generic "Recording failed or too
  short"), removes the in-progress message bubble, re-enables input, and
  **restarts the 30s timer from where it left off** (`startQuestionTimer(questionTimeRemaining)`,
  1097) — the candidate can retry within the same question. **Source-verified.**
- **STT failure on timer-expiry forced submit**: `forceSubmitSpokenAnswer()`
  (1159-1199) **never aborts or alerts** — it silently falls back to the
  live Web-Speech text (even if empty) and proceeds to scoring, since the
  30s deadline has already passed and must still produce a saved,
  server-scored answer. **Source-verified.**
- **Minimum length**: a client-side-only rule in `submitSpokenAnswer()`
  (1124-1137) rejects a manual submit under 15 words with a warning/alert
  and restarts the timer; this check does **not** exist in
  `forceSubmitSpokenAnswer()` (timer-expiry path always submits whatever
  exists) and — importantly — **does not exist server-side either**:
  `resume_submit_answer` (`career_app/views.py:1313-1369`) accepts and
  scores any `answer_text` it receives, with no length validation.
  **Source-verified.**
- **Backend-contract neutrality (important for Section 5A)**:
  `resume_submit_answer` reads `request.POST.get("answer_text", "")` and
  scores it via `evaluate_answer(question.question_text, ans_text)` — there
  is **no field, flag, or code path that distinguishes a voice-transcribed
  answer from a typed one**. The server is fully input-method-agnostic.
  **Source-verified.**

### Mandatory camera

- `requestCameraAccess()` (686-745) requests `video+audio` together (audio
  is needed so the *video recording* isn't silent — not for the per-answer
  mic capture, which is a separate, later `getUserMedia(audio)` call inside
  `initRecorder()`). A live frame is explicitly verified
  (`verifyCameraStream`, 747-762) before the Start button is enabled — a
  granted-but-blank permission is not accepted as "live." **Source-verified.**
- **Permission denied**: shown as "Camera access is required... Please allow
  camera access and try again," button re-enabled to retry.
  **Source-verified.**
- **No camera device present / other getUserMedia failure**: a distinct,
  slightly different message ("...connect or enable a working camera...").
  **Source-verified.**
- **Mid-interview camera loss**: `attachCameraTrackWatchers()` (817-831)
  continuously polls `cameraTrack.readyState`/listens for `onended`/`onmute`
  and shows a full-screen "Camera Disconnected" overlay
  (`handleCameraLost`, 833-842) that **disables all inputs** until
  `reconnectCamera()` (850-875) succeeds. This is also logged as a
  `CAMERA_INTERRUPTED` violation (1828-1842), but only once per loss episode
  (de-duplicated against the overlay already being shown). **Source-verified.**
- Both `resume_get_next_question` and `resume_submit_answer` independently
  re-check `session.camera_verified_at` server-side (confirmed at
  `resume_submit_answer:1323-1327`) — so the mandatory-camera rule is
  enforced in application logic, not only by the frontend gate.
  **Source-verified.**

### Face detection / proctoring

- **Real, not merely mentioned**: `face-api.js@0.22.2` is loaded from a CDN
  (`resume_interview.html:641`), its `tinyFaceDetector` model loaded from a
  second, different public CDN
  (`https://justadudewhohacks.github.io/face-api.js/models`, line 1785).
  This is genuinely wired up — not a stub or a dead script tag.
  **Source-verified.**
- **This is face detection, not face recognition/identity verification**:
  `faceapi.detectAllFaces(...)` only returns a count of detected faces in
  the frame (used to check zero vs. one vs. more-than-one) — no embedding
  comparison, no identity matching, no stored reference face anywhere in
  this flow. **Source-verified** — an important distinction per this
  phase's own instructions.
- **Cadence and thresholds**: checked every 1.5s
  (`FACE_CHECK_INTERVAL_MS`, 1775); a no-face streak must reach **3**
  consecutive checks (~4.5s) before counting as a `FACE_NOT_DETECTED`
  violation, and a multi-face streak must reach **2** (~3s) for
  `MULTIPLE_FACES` (1773-1812) — explicitly debounced against a blink or a
  brief head turn. **Source-verified.**
- **Fail-open, not fail-closed**: if the model fails to load (offline,
  CDN blocked, etc.), `faceApiReady` stays `false` and face monitoring is
  silently skipped for the whole session — the rest of the interview
  (camera gate, tab/window detection, scoring) is entirely unaffected.
  **Source-verified** (`loadFaceApiModel`, 1782-1791; `startMalpracticeMonitoring`,
  1814-1822).
- **Violation escalation (server-authoritative)**: `resume_record_violation`
  (`career_app/views.py:1067-1142`) always reads/writes the session's
  `malpractice_violation_count` from the DB — never trusts a client-supplied
  count. Thresholds: **≥3 total violations → `flagged`** (session continues,
  flagged for manual review), **≥5 total violations → `terminated`**
  (`MALPRACTICE_FLAG_THRESHOLD`/`MALPRACTICE_TERMINATE_THRESHOLD`,
  `career_app/views.py:1041-1042`). Termination runs the exact same
  `_score_and_finalize_session` path a normal completion uses — a
  terminated session is still scored on whatever was actually answered.
  **Source-verified.**
- **A violation never blocks submission directly** — it shows a blocking
  "I Understand, Continue" modal (`showMalpracticeWarningModal`,
  1614-1638) that disables inputs only until acknowledged, then the
  candidate continues normally (unless the cumulative count has reached the
  terminate threshold). **Source-verified.**
- **One additional, client-side-only rule** not mirrored server-side: for
  `TAB_SWITCH`/`WINDOW_BLUR` specifically, if that violation **type's own**
  occurrence count exceeds 3 (`data.type_occurrence_number > 3`, line 1662),
  the client calls `handleMalpracticeTermination()` **locally** and redirects
  to `resume_analytics` — independent of whatever the server's own
  total-count-based `status` says. This local-only termination does not
  appear to update `session.malpractice_status`/`is_completed` in the DB (no
  further server call is made in that branch beyond the violation POST
  itself). This is harmless in practice because `resume_analytics`
  recomputes the score fresh from whatever `ResumeAnswer` rows exist
  regardless of `is_completed`/`malpractice_status` (confirmed,
  `career_app/views.py:1506-1556`) — but it means "terminated" as shown to
  the candidate does not always mean the DB row says so. **Source-verified**,
  noted because the task asks precisely "whether these rules differ by...
  violation type" — they do, in this one specific, narrow way.
- **`FULLSCREEN_EXIT` is a modeled-but-dead violation type on the web
  itself**: it has a message string (`MALPRACTICE_MESSAGES.FULLSCREEN_EXIT`,
  line 1604) and a DB `TYPE_CHOICES` entry (`career_app/models.py:130`), but
  grepping the whole template for `fullscreen` (case-insensitive) finds only
  that one message string — **no `fullscreenchange` listener, no
  `requestFullscreen()` call exists anywhere**. The web's Mock Interview does
  not actually enforce fullscreen (unlike Mock Tests/AMCAT/CoCubes, which
  do — per Phase 5's P1-4 finding, a separate feature). **Source-verified.**
- **Copy/paste and screenshot-attempt detection** are real (`'copy'`/`'cut'`/`'paste'`
  listeners, 1746-1750; `PrintScreen`/Cmd+Shift+3/4/5 keydown detection,
  1759-1766, explicitly documented in the web's own code as "best effort...
  cannot detect a screenshot taken via a phone camera... or a screen-recording
  tool"). **Source-verified.**

### Consent / disclosure

- The only user-facing disclosure text anywhere in this flow is the camera
  gate's: *"This AI Mock Interview requires your camera to stay on for the
  entire session."* There is **no explicit mention anywhere in this
  template** that a third-party face-detection model will analyze the video
  feed, that the session is continuously recorded, or that the recording may
  be retained (grepped for `recorded`/`consent`/`privacy`/`disclos` across
  the whole file — only variable-name matches, no user-facing text).
  **Source-verified.** This is a real, if modest, disclosure gap on the
  **web's own side** — relevant context for Section 8, not something
  mobile needs to "match," since matching it would reproduce the same gap.

## 4. Verified Flutter behavior

### Answer capture

- `MockInterviewQuestionView` (`mock_interview_question_view.dart`) always
  renders a `TextField` (key `answer-text-field`, lines 167-180) regardless
  of `question.isCoding` — only the hint text differs ("Write your SQL
  query / code here…" vs. "Type your answer here…", line 175). Typed input
  is **never gated** behind anything — it is the baseline input method for
  every question. **Source-verified.**
- An on-device `speech_to_text` mic button (key `mic-button`) is shown
  **only when** `stt.SpeechToText().initialize()` succeeds (`_initSpeech`,
  48-64) — a real plugin capability check, not a stub. When available, its
  partial/final results are written directly into the same `TextField`
  (lines 84-88) — voice is a convenience filler for the same typed input,
  not a separate submission path. **Source-verified.**
- This client **never calls** `resume_transcribe_answer` — confirmed absent
  from `api_endpoints.dart`'s `resume*` constant block, and explicitly
  documented as a deliberate choice in `mock_interview_question_view.dart`'s
  own doc comment (lines 16-19): on-device STT only, no server-side Sarvam
  refinement step. **Source-verified.**
- **No minimum-word-count validation exists anywhere in the Flutter
  submission path** (`MockInterviewController.submitAnswer`/`_autoSubmit`,
  `mock_interview_controller.dart:260-286`) — any non-empty (or even empty,
  on auto-submit) text is sent as-is. Since the server itself also has no
  length check (Section 3), this does not create a server-side
  inconsistency, but it does mean Flutter's **manual** submit path is more
  permissive than the web's manual submit path (which blocks under-15-word
  answers client-side). **Source-verified.**
- The doc comment at the top of `mock_interview_question_view.dart` already
  states this is a **deliberate design choice** ("Answering is typed text at
  minimum (always available)") — not framed anywhere in the codebase as an
  accidental gap. Whether that deliberate choice is the *right* product
  policy is exactly what Section 11 asks the project owner to decide.

### Camera / proctoring

- The mandatory camera gate is implemented
  (`MockInterviewCameraGateView`/`InterviewCameraServiceImpl`): requests a
  front camera via the `camera` plugin, confirms `isInitialized &&
  !hasError` before allowing Start, shows the same disclosure copy as the
  web (word-for-word, `mock_interview_camera_gate_view.dart:70-71`).
  **Source-verified.**
- Continuous video recording is implemented for real
  (`InterviewCameraServiceImpl.startVideoRecording`/`stopVideoRecording`,
  using the `camera` plugin's own recorder) and uploaded via
  `uploadRecordedVideo` → `resume_upload_interview_video`, matching the
  web's "only kept if passed" server-side rule (unchanged, confirmed in
  Phase 8 context). **Source-verified.**
- **No face-presence detection of any kind exists** — confirmed by: (a) the
  controller's own top-level doc comment explicitly scoping this out
  (`mock_interview_controller.dart:22-39`); (b) no face-detection package
  (ML Kit, TFLite, or otherwise) anywhere in `pubspec.yaml`; (c) no
  periodic frame-sampling loop anywhere in
  `interview_camera_service_impl.dart` or the screen/controller.
  **Source-verified.**
- **No mid-interview camera-liveness re-check exists** — `InterviewCameraServiceImpl`
  only confirms liveness once, at the gate. There is no equivalent of the
  web's `attachCameraTrackWatchers`/`cameraMonitorInterval`/"Camera
  Disconnected" overlay. The `ViolationType.cameraInterrupted` enum value
  exists and its doc comment (`malpractice.dart:38`) claims this client
  reports it "if the live camera preview drops mid-interview," but **no
  call site anywhere calls `reportViolation(ViolationType.cameraInterrupted, ...)`**
  — grepped exhaustively. This is a small, stale/overclaiming doc comment
  (the same class of finding as Phase 5/8's other stale-comment items), not
  a functional regression, since nothing ever relied on this being true.
  **Source-verified** (new finding this phase).
- Tab-switch/backgrounding detection (`WidgetsBindingObserver`, confirmed
  in Phase 8 context) and `FACE_NOT_DETECTED`/`MULTIPLE_FACES` as valid,
  already-accepted `ViolationType` enum values (never triggered) are both
  present, exactly as Phase 5's P1-2 finding already stated — re-confirmed,
  unchanged. **Source-verified.**
- `FULLSCREEN_EXIT`/`COPY_PASTE`/`SCREENSHOT_ATTEMPT` are modeled in the enum
  but explicitly documented as "browser-only concepts with no meaningful
  native equivalent" and never reported — consistent with Section 3's
  finding that `FULLSCREEN_EXIT` is dead on the web too, and that
  copy/paste/screenshot detection are JS/DOM-specific capabilities with no
  direct native analogue. **Source-verified.**

### Platform/dependency baseline (for Section 7)

- `camera: ^0.12.1`, `speech_to_text: ^7.5.0` are the only
  camera/speech-related dependencies. **No ML/face-detection package is
  present** (`google_mlkit_face_detection`, TFLite, or otherwise) —
  confirmed via a full dependency grep. **Source-verified.**
- `android/app/build.gradle.kts` sets `minSdk = flutter.minSdkVersion`
  (Flutter's own default, not pinned to a specific API level in this
  project's own config) and `ios/Podfile` sets `platform :ios, '15.0'`.
  **Source-verified** as written; whether a specific future face-detection
  library's own minimum OS/API requirement is compatible with these values
  is **Unverified** — it depends on which library a future phase would
  choose, which this audit does not select.

## 5. Voice-versus-typed-answer gap analysis

The gap is real and precisely scoped: **theory questions only**. Coding
questions already match (typed-only on both sides). The server does not
care which path produced the text.

Three things currently differ in practice, independent of any "is this
allowed" policy question:
1. Mobile has **no minimum answer length enforced anywhere** (web enforces
   ≥15 words client-side only, on manual submit only).
2. Mobile never calls the server-side Sarvam STT refinement step — its
   transcript accuracy depends entirely on the on-device `speech_to_text`
   plugin's quality, which is a different (not necessarily worse, not
   necessarily better) transcription source than what web candidates get.
3. Mobile's typed path has no web equivalent at all for theory questions —
   so a mobile candidate can answer by typing in a way a web candidate
   structurally cannot.

None of these three are proctoring/security failures — they are
input-method and scoring-consistency differences, addressed as trade-offs
in Section 9A.

## 6. Face-detection/proctoring gap analysis

The gap is real, and is **the single largest remaining capability gap**
between the two platforms for this feature: a genuine real-time, on-device
ML inference capability (face-api.js's `tinyFaceDetector`) runs continuously
on web and has no mobile equivalent at all. This is qualitatively different
from every other gap in this audit — it requires either a new on-device ML
dependency (with its own model file, inference cost, and platform-specific
behavior) or accepting that this specific signal cannot be reproduced on
mobile today.

Everything **else** proctoring-adjacent (mandatory camera, continuous video
recording kept only on a pass, tab-switch/backgrounding detection, the
3-warn/5-terminate server-side escalation, the blocking acknowledgment
modal) is **already implemented and already parity-equivalent** on mobile.
Face presence/count detection is the one missing signal, not "proctoring in
general."

## 7. Platform and backend-contract constraints

- **Backend contract**: no backend change is required for either gap.
  `resume_submit_answer` is already input-method-agnostic (Section 3).
  `resume_record_violation`'s `ALLOWED_VIOLATION_TYPES` already includes
  `FACE_NOT_DETECTED`/`MULTIPLE_FACES` (`career_app/views.py:1044`, backed
  by `InterviewViolation.TYPE_CHOICES`, `career_app/models.py:125-142`) —
  confirmed these were never backend-gated, only client-side unimplemented.
  **Source-verified.**
- **Typed-answer policy options** (Section 9A) are all implementable with
  **zero new dependencies** — they are UI-only changes to an existing
  widget (`MockInterviewQuestionView`).
- **Face-detection options** (Section 9B) that keep any on-device inference
  would require **a new dependency** (an ML Kit/TFLite/ONNX-based face
  detector, or similar) — none exists in this project today. Adding one is
  out of this phase's permitted scope (no dependency changes) and would be
  the first concrete action item of any future implementation phase, not
  something this audit can verify compiles/runs/performs acceptably on
  real Android/iOS hardware without actually adding it. **This is why
  Section 9B's technically-equivalent option is marked "Unverified" for
  feasibility, not "confirmed feasible."**
- Camera/microphone permission plumbing (the `camera` and `speech_to_text`
  plugins' own runtime-permission flows) already exists and works today —
  any proctoring addition would reuse the same already-granted camera
  permission, not request a new one.

## 8. Privacy, consent, accessibility, and assessment-integrity considerations

- **Consent/disclosure**: the web's own disclosure is already minimal (camera
  must "stay on," nothing about face-analysis or recording retention —
  Section 3). If mobile adds face detection, the honest, user-respecting
  choice is to disclose it explicitly in the camera-gate copy — not to
  silently match the web's own under-disclosure. This is a recommendation
  for *if* proctoring is approved, not a requirement already met by parity.
- **Data minimization**: `face-api.js`'s `tinyFaceDetector` on web runs
  **entirely client-side** — no frame is ever uploaded merely for face
  detection; only the resulting violation type/count/duration is sent to
  `resume_record_violation`. Any mobile equivalent should preserve this
  on-device-only property (an on-device ML Kit/TFLite model, inferring
  locally from the already-live camera preview) rather than streaming video
  frames to any server for face analysis — the continuous video *recording*
  already uploaded (kept only if passed) is a separate, already-existing,
  already-disclosed mechanism and should not be conflated with a
  face-detection signal.
- **Accessibility — voice-only theory questions**: a candidate who cannot
  speak, has a speech impairment, or is in an environment where speaking
  aloud is impractical (shared housing, public space, hearing-impaired
  companion needing to follow along via text) has **no way to complete the
  web interview's theory questions at all**. Mobile's always-available
  typed input is, today, strictly more accessible than the web for this
  reason — a relevant, non-trivial consideration for Section 9A's
  "match web strictly" option.
- **Accessibility — camera/face detection**: a candidate without a working
  camera, or unable to stay continuously framed (e.g. certain mobility or
  visual impairments, or simply a poor/unstable camera mount on a phone)
  would be disproportionately affected by face-detection violations
  compared to a desktop/webcam setup. This is a real fairness consideration
  for Section 9B, independent of the technical feasibility question.
- **Assessment integrity**: the inverse of the above — typed answers (and
  pasted answers specifically) create a path to use an external tool to
  draft an answer that voice does not, since dictating a memorized/looked-up
  answer aloud is slower and more conspicuous than typing or pasting one.
  Mobile has no copy/paste detection equivalent (not meaningfully portable
  from a browser DOM event to a native text field in the same way — though
  not literally impossible, see Section 9A's option framing).

## 9. Options and trade-off comparison tables

### A. Answer input method

| Option | Web/mobile parity | Accessibility | Integrity/scoring consistency | Technical feasibility (current contract) | Failure/retry handling | UI/testing impact | Risk of changing existing behavior | Product decision required? |
|---|---|---|---|---|---|---|---|---|
| 1. Require voice only (remove/hide the always-on `TextField` for theory questions, keep it for coding) | Full — matches web exactly | Removes mobile's only answer path for candidates who can't/won't speak aloud; also removes the browser-support fallback web itself lacks (mobile already has no "needs Chrome/Edge" problem, so this would be a pure accessibility regression vs. mobile's current state) | Matches web's integrity model exactly (same vulnerability/strength profile as web) | Fully feasible with existing `speech_to_text` plugin only — no backend change | Needs a mobile-native equivalent of "no speech detected, tap to retry" and a no-STT-available dead-end state (worse than web's, since there's no "switch browser" equivalent on a phone) | Removes/hides an existing, tested widget path; several existing tests assert the `TextField` is always present and would need updating | Medium — removes a capability candidates may already rely on | **Yes** |
| 2. Keep voice as primary, keep typed as an explicitly documented accessibility/hardware fallback (e.g., shown prominently only when STT is unavailable, or kept as-is but explicitly labeled) | Partial by design — a documented, defensible difference, not an oversight | Best of the three — preserves mobile's current accessibility advantage | Slightly weaker than strict parity (typing is still always possible) but the server already has no minimum-length or input-method check either way, so this doesn't create a *new* loophole beyond what exists today | Fully feasible — this is close to current behavior, formalized and documented rather than silently "just how it works" | Already has retry handling today (the current `TextField` + optional mic) | Smallest — mostly a labeling/documentation change, optionally minor UI emphasis change | Low | **Yes** (confirms, rather than changes, current behavior — still a decision, not a default) |
| 3. Product-configurable policy (e.g. a server-driven or remote-config flag deciding which mode applies) | Depends entirely on configuration | Depends on configuration | Depends on configuration | **Not justified by current evidence** — no existing remote-config/feature-flag mechanism was found in this codebase for this feature, and introducing one is a disproportionate amount of new complexity/surface for a single screen's input mode | N/A until designed | Adds a new axis of test configurations to maintain | Adds ongoing maintenance cost disproportionate to the problem | **Yes**, and likely not recommended regardless (see Section 10) |

### B. Face detection and proctoring

| Option | Android/iOS support | Consent/disclosure | On-device vs. uploaded | Privacy/retention | False positives / fairness | Performance/battery/maintenance | Backend enforcement | Scoring/completion fairness | Product decision required? |
|---|---|---|---|---|---|---|---|---|---|
| 1. Implement an equivalent on-device face-presence detector (e.g. ML Kit Face Detection or a TFLite tiny-face model), sampling the already-live preview on an interval, reporting the same `FACE_NOT_DETECTED`/`MULTIPLE_FACES` types to the existing, unmodified `resume_record_violation` endpoint | **Unverified** — no such dependency exists in this project today; compatibility with this project's exact `minSdk`/iOS 15.0 floor and real-device performance has not been tested this phase | Must be disclosed explicitly in the camera-gate copy (stronger than web's own under-disclosure, per Section 8) | Can be kept fully on-device, matching web's own property, if an on-device-inference library is chosen | Same as web if on-device only: no frame ever leaves the device for this signal | Needs the same kind of debounce/streak logic web uses (web's 3-check/2-check thresholds) tuned for mobile's typically-closer, often-handheld camera framing — lighting/angle differ meaningfully from a desktop webcam | Real, ongoing cost: a new dependency, a model asset, continuous inference during every interview, battery draw, and a new platform-specific failure mode to maintain | Already works unmodified — the exact same endpoint and thresholds as web | Improves fairness/parity with web's own integrity model | **Yes** |
| 2. Clearly disclosed, limited mobile policy (keep mandatory camera + continuous video recording + tab/background detection as the mobile-specific integrity signal set; explicitly state face-presence monitoring is not performed on mobile) | N/A — no new dependency | Must explicitly state what mobile *does* and *does not* monitor, so neither candidates nor reviewers assume parity that doesn't exist | N/A | No new privacy surface at all | N/A | Zero added cost | Existing signals (camera gate, video, tab/background) remain server-enforced exactly as today | A terminated/flagged mobile session has a narrower evidence base than a terminated/flagged web session for the same violation count — worth knowing before treating the two as equivalent for review purposes | **Yes** |
| 3. Leave proctoring out of scope (no change, keep today's status quo and its existing, accurate doc comments) | N/A | Current camera-gate disclosure already covers what's actually done (mandatory camera + recording) | N/A | N/A | N/A | Zero cost | Unchanged | Mobile remains the weaker-evidence platform for malpractice review, as it already is today | **Yes** (even "do nothing" is a decision here, since Phase 5 already flagged this as P1-2 and it has been open for multiple phases) |

## 10. Recommended technical approach (engineering judgment, not a decision)

- **Section 9A**: Option 2 (keep voice as the primary/featured method, keep
  typed input, but make the "this is an accessibility/hardware fallback"
  framing *explicit* rather than implicit) is the engineering
  recommendation — it is the only option that doesn't trade away mobile's
  current accessibility advantage, requires no new dependency, and doesn't
  introduce a maintenance-heavy configurable-policy mechanism this codebase
  has no existing pattern for. Option 3 (configurable policy) is explicitly
  **not** recommended given the lack of any existing remote-config precedent
  in this codebase for a single-screen input mode. This is a
  recommendation, not a decision — see Section 11.
- **Section 9B**: given the magnitude of the new-dependency commitment
  (Section 7), this is not a call an engineering recommendation should make
  unilaterally. If forced to recommend a starting point *conditional on* a
  "yes, build it" decision, Option 1 (an on-device-only detector reusing
  the exact existing endpoint/thresholds) is the only one that preserves
  web's own privacy property (no frame upload) and requires no backend
  change — but whether the cost (new dependency, battery, maintenance, a
  second platform-specific ML surface in an app that has none today) is
  worth it relative to Option 2 (explicit, honest non-parity) is squarely a
  product call, not an engineering one.
- **Assumption stated explicitly**: this recommendation assumes the project
  owner has not already decided elsewhere that mobile proctoring parity is
  a hard requirement (e.g. for a specific enterprise/compliance commitment).
  No such requirement was found in any file read this phase or any prior
  report: Phase 5's P1-2/P1-3 entries both independently describe these as
  "product decision required," not as settled requirements, and this audit
  found nothing to contradict that.

## 11. Explicit product decisions required from the project owner

1. **Typed answers for theory questions**: keep as an explicit, documented
   accessibility/fallback input method (current de facto behavior,
   formalized), restrict to match web's voice-only behavior, or build a
   configurable policy? (Section 9A)
2. **If typed answers are kept**: should a minimum-answer-length rule be
   added to match the web's own (client-side-only, ≥15-word) rule, given
   neither platform enforces it server-side today?
3. **Face detection**: build an on-device equivalent (accepting a new
   dependency and its ongoing maintenance/performance cost), adopt an
   explicitly-disclosed narrower mobile proctoring policy, or leave this
   capability out of scope entirely? (Section 9B)
4. **If face detection is built**: what disclosure text should the mobile
   camera gate show, given the web's own disclosure is thinner than what a
   newly-added, clearly-labeled capability arguably deserves? (Section 8)
5. **Stale doc comment** (Section 4, new finding): should
   `malpractice.dart`'s claim that this client reports `cameraInterrupted`
   "if the live camera preview drops mid-interview" be corrected to reflect
   that no such mid-interview monitoring currently exists — independent of
   and prior to any face-detection decision? (A documentation-only
   correction, not a functional change — low-risk, but still a change this
   audit was told not to make unilaterally this phase.)

## 12. Implementation scope and test plan for a potential future phase

Not an approved plan — a scoping sketch only, to size each decision once
made, per the task's request for an "implementation scope and test plan for
a potential future phase."

- **If Option 2 (9A) is chosen**: change is confined to
  `mock_interview_question_view.dart` (labeling/emphasis only) and its doc
  comment; optionally a length-validation addition to
  `MockInterviewController.submitAnswer`/`_autoSubmit` if decision #2 above
  is "yes." Tests: widget tests asserting the fallback framing/label is
  shown; a controller test for the length-validation branch if added. No
  backend, no new dependency.
- **If Option 1 (9B) is chosen**: new dependency selection and vetting (out
  of this phase's scope to pick), a new `FaceDetectionService` abstraction
  (mirroring `InterviewCameraService`'s own pattern), a periodic-sampling
  loop wired into `MockInterviewScreen`'s existing lifecycle (next to the
  existing `WidgetsBindingObserver` wiring), reusing the existing
  `reportViolation(ViolationType.faceNotDetected/.multipleFaces, ...)`
  path unchanged. Tests: a fake `FaceDetectionService` double (same pattern
  as this feature's existing `_FakeInterviewCameraService`) driving
  controller-level violation tests; a widget test confirming the gate's
  updated disclosure copy. Requires real-device verification before
  release (inference performance, false-positive rate on phone cameras) —
  explicitly flagged as **not verifiable from source/unit tests alone**.
- **If Option 2 (9B) is chosen**: documentation-only — update the
  camera-gate disclosure copy and the controller's existing scope-note doc
  comment (already mostly accurate) to be explicit that face-presence
  monitoring is a deliberate, disclosed non-parity, not an oversight. No
  tests required beyond a widget test asserting the (updated) disclosure
  text renders.

## 13. Verification performed and limitations

- Every finding above is sourced from direct reads of the files listed in
  Section 2, cited inline by path and line number (or function name where
  line numbers would drift).
- **No live device, emulator, browser, or production account was used.**
  No camera or microphone hardware was exercised. No claim in this report
  describes behavior as observed live — every behavioral claim is either
  **Source-verified** (read directly from code) or explicitly labeled
  **Unverified**/**Environment-dependent** where source alone cannot settle
  it (e.g., real-device face-detection performance, exact `minSdk`
  compatibility of an unselected future library).
- No test was run or written this phase (the task did not ask for one, and
  none of this phase's findings required executing code to confirm —
  static inspection was sufficient for every claim made).
- The one item carried from Phase 5 still genuinely **blocked on live
  verification** (unrelated to this report's two topics) is P1-6 (Skill-Up
  WebView cookie sharing) — not re-examined this phase, out of scope.

## 14. Confirmation of no modifications

- **Only `docs/PHASE_9_MOCK_INTERVIEW_PROCTORING_DECISION_AUDIT.md` was
  created.** No other file in either repository was created, edited, or
  deleted this phase.
- `docs/WEB_MOBILE_FEATURE_PARITY_MATRIX.md` was **read but not modified** —
  this phase's task explicitly scoped matrix changes out ("Do not modify
  the existing parity matrix or previous reports").
- No Flutter application source file, test file, backend/Django file,
  `pubspec.yaml`/dependency lock file, Gradle/Podfile configuration, or any
  other previously-written report was changed.
- No package was installed, no dependency version was changed, no platform
  permission/configuration file was touched.
- No build, signing, deploy, or upload step was run.
- No authentication/OTP/subscription/permission restriction was bypassed;
  no live or production account, device, camera, or microphone was used —
  every finding in this report is traceable to a specific file read this
  phase or in the immediately preceding Phase 8 session, not to any live
  observation.

---

Audit complete. **No implementation was attempted.** Waiting for explicit
approval and direction on Sections 11's decisions before any future phase
begins.
