import '../errors/exceptions.dart';

/// Unwraps the `{"success": true, "data": {...}, "meta": {...}}` envelope
/// every `/api/` JSON endpoint in this app uses (see
/// `docs/BACKEND_CONTRACT_dashboard.md`/`BACKEND_CONTRACT_activities.md`).
/// A non-2xx status is already mapped to an [AppException] by
/// `ApiExceptionsInterceptor`; this only has to guard against a 200
/// response that isn't shaped as expected (e.g. an HTML body from a
/// redirect Dio auto-followed).
Map<String, dynamic> unwrapEnvelopeData(Object? responseBody) {
  if (responseBody is! Map<String, dynamic> || responseBody['data'] is! Map<String, dynamic>) {
    throw const UnexpectedResponseException();
  }
  return responseBody['data'] as Map<String, dynamic>;
}
