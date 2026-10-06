import '../../../../core/utils/result.dart';
import '../entities/gd_report.dart';
import '../entities/gd_session_summary.dart';
import '../entities/gd_started_session.dart';

abstract interface class GdRepository {
  /// `GD_app:create_session`.
  Future<Result<GdStartedSession>> createSession(String topic);

  /// `GD_app:api_sessions`.
  Future<Result<List<GdSessionSummary>>> getSessions();

  /// `GD_app:session_report`. `null` means the session has no report yet
  /// (the server's own `{% if report %} ... {% else %}` branch —
  /// e.g. a session that was never ended).
  Future<Result<GdReport?>> getSessionReport(int sessionId);
}
