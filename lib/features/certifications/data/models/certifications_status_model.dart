import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/certifications_status.dart';
import 'certification_category_model.dart';

/// Parses `api_certifications_status`'s top-level JSON shape
/// (`skillup_assessment/views.py:301-327`).
extension CertificationsStatusParsing on CertificationsStatus {
  static CertificationsStatus fromJson(Map<String, dynamic> json) {
    return CertificationsStatus(
      categories: requireList(
        json,
        'categories',
      ).map((e) => CertificationCategoryParsing.fromJson(asMap(e, 'categories[]'))).toList(),
      totalCount: requireInt(json, 'total_count'),
      attemptedCount: requireInt(json, 'attempted_count'),
      earnedCount: requireInt(json, 'earned_count'),
    );
  }
}
