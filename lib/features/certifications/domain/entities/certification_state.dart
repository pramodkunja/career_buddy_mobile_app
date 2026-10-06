/// One subject's certification state, always re-derived server-side from
/// `QuizAttempt` (`skillup_assessment/views.py:_subject_state` /
/// `mock_test_integration.get_mock_test_result`+`is_eligible`) — never
/// computed or trusted client-side. The 4 raw wire values, confirmed
/// directly from the view (`_subject_state`'s `state = "..."` assignments):
/// `not_attempted`, `locked`, `eligible`, `certified`.
enum CertificationState {
  notAttempted,
  locked,
  eligible,
  certified;

  static CertificationState fromApi(String value) {
    switch (value) {
      case 'not_attempted':
        return CertificationState.notAttempted;
      case 'locked':
        return CertificationState.locked;
      case 'eligible':
        return CertificationState.eligible;
      case 'certified':
        return CertificationState.certified;
      default:
        throw FormatException('Unknown certification state: $value');
    }
  }
}
