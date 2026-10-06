import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/certification_state.dart';
import '../../domain/entities/certification_subject.dart';
import 'certificate_info_model.dart';
import 'certification_result_model.dart';

/// Parses `_subject_state_json()`'s JSON shape
/// (`skillup_assessment/views.py:286-298`): `certificate` is the only
/// optional/nullable field here (null until a certificate is generated);
/// every other field is always present.
extension CertificationSubjectParsing on CertificationSubject {
  static CertificationSubject fromJson(Map<String, dynamic> json) {
    final certificateJson = json['certificate'];
    return CertificationSubject(
      subject: requireString(json, 'subject'),
      label: requireString(json, 'label'),
      category: requireString(json, 'category'),
      state: CertificationState.fromApi(requireString(json, 'state')),
      passThreshold: requireInt(json, 'pass_threshold'),
      result: CertificationResultParsing.fromJson(requireMap(json, 'result')),
      certificate: certificateJson == null
          ? null
          : CertificateInfoParsing.fromJson(asMap(certificateJson, 'certificate')),
      prefillName: requireString(json, 'prefill_name'),
      nameUrl: requireString(json, 'name_url'),
    );
  }
}
