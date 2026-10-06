import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/certification_result.dart';

/// Parses `get_mock_test_result()`'s JSON shape
/// (`skillup_assessment/mock_test_integration.py:22-47`): `score`/`total`
/// are genuinely nullable (never attempted), `completed` is always present.
extension CertificationResultParsing on CertificationResult {
  static CertificationResult fromJson(Map<String, dynamic> json) {
    return CertificationResult(
      score: json['score'] as int?,
      total: json['total'] as int?,
      completed: requireBool(json, 'completed'),
    );
  }
}
