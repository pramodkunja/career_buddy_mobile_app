import '../../../../core/utils/result.dart';
import '../entities/jam_session_result.dart';
import '../entities/jam_session_start.dart';
import '../entities/jam_topic.dart';

abstract class JamRepository {
  /// `jam:topics` — every active topic, grouped by difficulty on the web
  /// but returned here as one flat list (`JamTopic.difficulty` carries the
  /// grouping; presentation code buckets it the same way the web template
  /// does).
  Future<Result<List<JamTopic>>> getTopics();

  /// `jam:jam_session` (random, [topicId] is `null`) or
  /// `jam:jam_session_topic` (a specific topic).
  Future<Result<JamSessionStart>> startSession({int? topicId});

  /// `jam:save_audio` — uploads the recorded clip (or none, if the
  /// recording produced no file) plus [durationSeconds]/[language]/
  /// [transcript] for [sessionId].
  Future<Result<void>> saveAudio({
    required int sessionId,
    String? audioFilePath,
    required int durationSeconds,
    required String language,
    String transcript = '',
  });

  /// `jam:complete_session` — marks the session complete, triggers AI
  /// feedback generation server-side, and returns the parsed scored result.
  Future<Result<JamSessionResult>> completeSession(int sessionId);
}
