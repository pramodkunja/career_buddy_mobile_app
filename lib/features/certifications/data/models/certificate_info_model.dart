import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/certificate_info.dart';

/// Parses `_certificate_json()`'s JSON shape
/// (`skillup_assessment/views.py:272-283`).
extension CertificateInfoParsing on CertificateInfo {
  static CertificateInfo fromJson(Map<String, dynamic> json) {
    return CertificateInfo(
      certificateName: requireString(json, 'certificate_name'),
      score: requireInt(json, 'score'),
      total: requireInt(json, 'total'),
      certificateNumber: requireString(json, 'certificate_number'),
      generatedAt: optionalDateTime(json, 'generated_at'),
      downloadUrl: requireString(json, 'download_url'),
      editUrl: requireString(json, 'edit_url'),
    );
  }
}
