import 'dart:typed_data';

import '../../../../core/utils/result.dart';
import '../entities/certification_subject.dart';
import '../entities/certifications_status.dart';

/// `skillup_assessment`'s 4 real, `@login_required` endpoints (see
/// `ApiEndpoints`'s Certifications doc comment for the exact verified
/// paths).
abstract class CertificationsRepository {
  /// `GET api_certifications_status`.
  Future<Result<CertificationsStatus>> getStatus();

  /// `POST api_certificate_generate` — first-time generation for a subject
  /// already `eligible`. Returns the freshly re-fetched [CertificationSubject]
  /// (the real response wraps the whole updated subject as
  /// `{"subject": {...}}`, not a bare certificate — see
  /// `CertificationsRemoteDataSource` doc comment), so a caller can read the
  /// new `certificate`/`state` straight off the result without a second
  /// round trip, though [CertificationsSection] still refreshes the whole
  /// status afterwards to stay strictly server-driven.
  Future<Result<CertificationSubject>> generateCertificate({required String subject, required String name});

  /// `POST api_certificate_regenerate` — edits the printed name on an
  /// already-generated certificate. Same response shape as
  /// [generateCertificate].
  Future<Result<CertificationSubject>> regenerateCertificate({required String subject, required String name});

  /// `GET certificate_download` — the generated PDF's raw bytes, fetched
  /// through the app's own authenticated Dio client (the endpoint is
  /// `@login_required` and returns a binary `FileResponse`, so it can't be
  /// opened directly in an external, unauthenticated browser the way
  /// Resume History's "View File" does — see `CertificationsRemoteDataSource`
  /// doc comment).
  Future<Result<Uint8List>> downloadCertificateBytes(String subject);
}
