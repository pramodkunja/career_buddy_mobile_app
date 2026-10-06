/// `ResumeInterviewSession.MALPRACTICE_STATUS_CHOICES`
/// (`career_app/models.py:55-64`) — `resume_violation_state`/
/// `resume_record_violation` both serialize this as the lowercase string
/// (`'clean'`/`'flagged'`/`'terminated'`).
enum MalpracticeStatus { clean, flagged, terminated }

extension MalpracticeStatusApi on MalpracticeStatus {
  static MalpracticeStatus fromApi(String? value) => switch (value) {
    'flagged' => MalpracticeStatus.flagged,
    'terminated' => MalpracticeStatus.terminated,
    _ => MalpracticeStatus.clean,
  };
}

/// `resume_record_violation`'s own escalation decision
/// (`career_app/views.py:1119-1126`): `warn` for the first couple of
/// violations, `flagged` once `MALPRACTICE_FLAG_THRESHOLD` (3) is reached
/// (session keeps running, just flagged for manual review), `terminated`
/// once `MALPRACTICE_TERMINATE_THRESHOLD` (5) is reached (the interview is
/// force-ended server-side, same scoring path as a normal completion).
enum ViolationAction { warn, flagged, terminated }

extension ViolationActionApi on ViolationAction {
  static ViolationAction fromApi(String? value) => switch (value) {
    'flagged' => ViolationAction.flagged,
    'terminated' => ViolationAction.terminated,
    _ => ViolationAction.warn,
  };
}

/// `InterviewViolation.TYPE_CHOICES` (`career_app/models.py:125-142`) —
/// the exact strings `resume_record_violation`'s `type` field must be one
/// of (`ALLOWED_VIOLATION_TYPES`, `career_app/views.py:1044`).
///
/// This mobile client only ever actively reports [tabSwitch]/[windowBlur]
/// (via `WidgetsBindingObserver.didChangeAppLifecycleState` — the real,
/// native equivalent of the web's `document.visibilitychange`/`window.blur`
/// listeners) and [cameraInterrupted] (if the live camera preview drops
/// mid-interview). [faceNotDetected]/[multipleFaces] are **not** reported by
/// this client — see the mock_interview feature's top-level doc comment for
/// why live face detection is explicitly out of scope for this batch.
/// [fullscreenExit]/[copyPaste]/[screenshotAttempt] are browser-only concepts
/// with no meaningful native equivalent on a mobile app and are likewise
/// never actively reported — all eight are still modeled here (rather than
/// only the three this client uses) so the enum stays a complete, honest
/// mirror of what the server actually accepts.
enum ViolationType {
  faceNotDetected,
  multipleFaces,
  tabSwitch,
  windowBlur,
  cameraInterrupted,
  fullscreenExit,
  copyPaste,
  screenshotAttempt,
}

extension ViolationTypeApi on ViolationType {
  String get apiValue => switch (this) {
    ViolationType.faceNotDetected => 'FACE_NOT_DETECTED',
    ViolationType.multipleFaces => 'MULTIPLE_FACES',
    ViolationType.tabSwitch => 'TAB_SWITCH',
    ViolationType.windowBlur => 'WINDOW_BLUR',
    ViolationType.cameraInterrupted => 'CAMERA_INTERRUPTED',
    ViolationType.fullscreenExit => 'FULLSCREEN_EXIT',
    ViolationType.copyPaste => 'COPY_PASTE',
    ViolationType.screenshotAttempt => 'SCREENSHOT_ATTEMPT',
  };
}

/// `resume_violation_state`'s response (`career_app/views.py:1047-1064`).
class ViolationState {
  const ViolationState({
    required this.count,
    required this.status,
    required this.flagThreshold,
    required this.terminateThreshold,
  });

  final int count;
  final MalpracticeStatus status;
  final int flagThreshold;
  final int terminateThreshold;
}

/// `resume_record_violation`'s response (`career_app/views.py:1137-1142`,
/// or the shorter already-terminated shape at `1096-1100` which omits
/// `type_occurrence_number` entirely — hence [typeOccurrenceNumber] is
/// nullable here, not defaulted to a misleading `0`/`1`).
class ViolationRecordResult {
  const ViolationRecordResult({
    required this.count,
    required this.status,
    required this.action,
    required this.typeOccurrenceNumber,
  });

  final int count;
  final MalpracticeStatus status;
  final ViolationAction action;
  final int? typeOccurrenceNumber;
}
