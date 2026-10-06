/// Exceptions thrown by data sources when a request cannot be fulfilled.
/// These carry technical detail; [ExceptionMapper] converts them into
/// user-facing [Failure]s before they reach the presentation layer.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class NetworkUnavailableException extends AppException {
  const NetworkUnavailableException([super.message = 'No network connection.']);
}

final class RequestTimeoutException extends AppException {
  const RequestTimeoutException([super.message = 'The request timed out.']);
}

final class ServerException extends AppException {
  const ServerException(this.statusCode, [super.message = 'Server error.']);
  final int? statusCode;
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Not authenticated.']);
}

final class ForbiddenException extends AppException {
  const ForbiddenException([super.message = 'Not permitted.']);
}

final class ValidationException extends AppException {
  const ValidationException(this.fieldErrors, [super.message = 'Invalid input.']);
  final Map<String, List<String>> fieldErrors;
}

final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Not found.']);
}

final class RateLimitException extends AppException {
  const RateLimitException([super.message = 'Too many requests.']);
}

final class UnexpectedResponseException extends AppException {
  const UnexpectedResponseException([super.message = 'Unexpected response from server.']);
}

/// `jobs_app.views.employer_dashboard` redirects here
/// (`employer_portal:employer_profile_create`) whenever
/// `_employer_profile_complete(profile)` is false — true for most
/// self-registered employers, since `EmployerRegisterForm` leaves
/// `company_gst`/`company_pan_tin` optional (`jobs_app/views.py:482-493`).
/// Building the profile-completion screen itself is out of scope for this
/// batch — see `EmployerDashboardScreen`'s doc comment.
final class EmployerProfileIncompleteException extends AppException {
  const EmployerProfileIncompleteException([
    super.message =
        'Your company profile isn\'t complete yet (GSTIN and PAN are required). '
        'Please complete it on the Career Buddy website to unlock your dashboard.',
  ]);
}

/// AI Mock Interview (`resume_get_next_question`/`resume_submit_answer`,
/// `career_app/views.py:1190-1194`/`1323-1327`) — both independently return
/// this exact `{"error": "camera_required", ...}` shape (HTTP 403) whenever
/// `ResumeInterviewSession.camera_verified_at` isn't set server-side, e.g. a
/// session resumed without ever calling `resume_camera_verified`. Kept as its
/// own exception (rather than falling into the generic [ForbiddenException])
/// so the mobile UI can route the user back to the camera gate instead of a
/// dead-end permission error.
final class CameraRequiredException extends AppException {
  const CameraRequiredException([
    super.message = 'Camera access is required to attend the interview. Please allow camera access and try again.',
  ]);
}

/// AI Mock Interview (`resume_get_next_question`/`resume_submit_answer`,
/// `career_app/views.py:1195-1199`/`1328-1332`) — this exact
/// `{"error": "malpractice_terminated", ...}` shape (HTTP 403) once
/// `ResumeInterviewSession.malpractice_status` reaches
/// `MALPRACTICE_TERMINATED` (`resume_record_violation`'s own escalation, see
/// `MALPRACTICE_TERMINATE_THRESHOLD`). Kept distinct from [ForbiddenException]
/// so the UI can show the real "interview terminated" outcome (and still load
/// `resume_analytics`) rather than a generic permission error.
final class MalpracticeTerminatedException extends AppException {
  const MalpracticeTerminatedException([
    super.message = 'This interview was ended due to repeated malpractice violations.',
  ]);
}
