import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/certification_category.dart';
import 'certification_subject_model.dart';

/// Parses one entry of `api_certifications_status`'s `categories` list
/// (`skillup_assessment/views.py:310-320`).
extension CertificationCategoryParsing on CertificationCategory {
  static CertificationCategory fromJson(Map<String, dynamic> json) {
    return CertificationCategory(
      key: requireString(json, 'key'),
      label: requireString(json, 'label'),
      total: requireInt(json, 'total'),
      attempted: requireInt(json, 'attempted'),
      earned: requireInt(json, 'earned'),
      subjects: requireList(
        json,
        'subjects',
      ).map((e) => CertificationSubjectParsing.fromJson(asMap(e, 'subjects[]'))).toList(),
    );
  }
}
