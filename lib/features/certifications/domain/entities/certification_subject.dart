import 'certificate_info.dart';
import 'certification_result.dart';
import 'certification_state.dart';

/// One subject's full certification status — `_subject_state_json`
/// (`skillup_assessment/views.py:286-298`)'s exact JSON shape.
class CertificationSubject {
  const CertificationSubject({
    required this.subject,
    required this.label,
    required this.category,
    required this.state,
    required this.passThreshold,
    required this.result,
    required this.certificate,
    required this.prefillName,
    required this.nameUrl,
  });

  /// The backend slug (e.g. `dsa`, `oop`, `amcat`, `cocubes`, `english`,
  /// `aptitude`) — one of `skillup_assessment.subjects.SUBJECTS`'s ~27
  /// keys. Corresponds 1:1 with `kQuizSubjects`' slugs EXCEPT `oop`
  /// (its own dedicated flow) and `amcat`/`cocubes` (their own standalone
  /// mock-test endpoints) — see `CertificationsSection`'s routing helper.
  final String subject;

  final String label;

  /// `english` | `aptitude` | `tech` — matches the parent
  /// [CertificationCategory.key] it's nested under.
  final String category;

  final CertificationState state;

  /// `PASS_THRESHOLD_PCT` (`skillup_assessment/subjects.py:48`) — currently
  /// always `70`, but read from the payload rather than hardcoded here.
  final int passThreshold;

  final CertificationResult result;

  /// Non-null only once a certificate has actually been generated for this
  /// subject (independent of [state] == certified being derivable from
  /// `certificate.is_generated`; both are read directly from the server).
  final CertificateInfo? certificate;

  /// `_profile_display_name(request.user)` — the account's existing name,
  /// used to pre-fill the "Generate Certificate" name field. Never a
  /// client-invented default.
  final String prefillName;

  /// `reverse("skillup_certificate_name", args=[subject])` — the web's own
  /// HTML form-POST target for the FIRST generation. Kept for payload
  /// parity; this app posts to `ApiEndpoints.certificateGenerate` (the JSON
  /// sibling) instead, the same way `editUrl` on [CertificateInfo] is kept
  /// but not navigated to.
  final String nameUrl;
}
