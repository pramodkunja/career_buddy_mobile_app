import 'certification_subject.dart';

/// One category grouping of subjects — matches `api_certifications_status`'s
/// per-category dict (`skillup_assessment/views.py:310-320`):
/// `{"key", "label", "total", "attempted", "earned", "subjects"}`. The 3
/// real category keys (`skillup_assessment/subjects.py:26-30`): `english`
/// ("English & Vocabulary"), `aptitude` ("Aptitude & Reasoning"), `tech`
/// ("Tech Center") — labels always read from the payload, never hardcoded
/// here, since the backend is the single source of truth (spec section 23:
/// "Dynamic Architecture").
class CertificationCategory {
  const CertificationCategory({
    required this.key,
    required this.label,
    required this.total,
    required this.attempted,
    required this.earned,
    required this.subjects,
  });

  final String key;
  final String label;
  final int total;
  final int attempted;
  final int earned;
  final List<CertificationSubject> subjects;
}
