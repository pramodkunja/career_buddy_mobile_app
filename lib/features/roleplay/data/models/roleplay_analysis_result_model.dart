import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/roleplay_analysis_result.dart';
import '../../domain/entities/roleplay_issue.dart';

/// Parses `analyze_roleplay`'s `data` object on a successful
/// (`"success": true`) response — see `RoleplayAnalysisResult`'s doc
/// comment for why the shape is `SpeakingAgent.run`'s raw output
/// (`activities/agents/speaking.py:103-113`): `{text, transcript, issues,
/// improved_passage, scores, duration_seconds, pause_count, feedback,
/// quick_tip}`, with no `score_25` anywhere in it.
extension RoleplayAnalysisResultParsing on RoleplayAnalysisResult {
  static RoleplayAnalysisResult fromJson(Map<String, dynamic> json) {
    final scoresJson = requireMap(json, 'scores');
    final scores = <String, num>{
      for (final entry in scoresJson.entries)
        if (entry.value is num) entry.key: entry.value as num,
    };
    return RoleplayAnalysisResult(
      // `transcript` mirrors `text` when present; `text` is the field
      // `SpeakingAgent.run` actually always populates.
      transcript: (json['transcript'] as String?) ?? requireString(json, 'text'),
      issues: requireList(json, 'issues').map((e) => _issueFromJson(asMap(e, 'issues[]'))).toList(),
      improvedPassage: requireString(json, 'improved_passage'),
      feedback: json['feedback'] is String ? json['feedback'] as String : null,
      quickTip: json['quick_tip'] is String ? json['quick_tip'] as String : null,
      scores: scores,
      durationSeconds: requireNum(json, 'duration_seconds').toDouble(),
      pauseCount: requireInt(json, 'pause_count'),
    );
  }

  static RoleplayIssue _issueFromJson(Map<String, dynamic> json) {
    return RoleplayIssue(
      phrase: requireString(json, 'phrase'),
      type: requireString(json, 'type'),
      message: requireString(json, 'message'),
      suggestion: requireString(json, 'suggestion'),
    );
  }
}
