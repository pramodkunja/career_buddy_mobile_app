/// A generated certificate record — `_certificate_json`
/// (`skillup_assessment/views.py:272-283`)'s exact JSON shape, built from
/// the real `Certificate` model row. `null` at the [CertificationSubject]
/// level whenever no certificate has been generated yet for that subject.
class CertificateInfo {
  const CertificateInfo({
    required this.certificateName,
    required this.score,
    required this.total,
    required this.certificateNumber,
    required this.generatedAt,
    required this.downloadUrl,
    required this.editUrl,
  });

  /// The name printed on the PDF — user-editable via regenerate, distinct
  /// from the account's own display name.
  final String certificateName;

  /// The score/total the certificate was generated with (may differ from a
  /// later, unrelated retake — see `certificate_download`'s doc comment:
  /// once generated, a certificate is a persisted record that doesn't get
  /// revoked by a subsequent lower-scoring attempt).
  final int score;
  final int total;

  final String certificateNumber;
  final DateTime? generatedAt;

  /// Relative backend paths (`reverse("skillup_certificate_download"/
  /// "skillup_certificate_edit", args=[subject])`) — `downloadUrl` matches
  /// `ApiEndpoints.certificateDownload(subject)` exactly; `editUrl` points
  /// at the web's own HTML edit form (`certificate_edit_name`), not the
  /// JSON `api_certificate_regenerate` endpoint this app calls instead, so
  /// it's kept only for parity with the real payload, not used to navigate.
  final String downloadUrl;
  final String editUrl;
}
