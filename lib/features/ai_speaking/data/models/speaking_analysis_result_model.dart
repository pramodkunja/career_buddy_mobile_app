import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/speaking_analysis_result.dart';
import '../../domain/entities/speaking_issue.dart';

/// Parses `analyze_speaking`'s `data` object on a successful
/// (`"success": true`) response (`activities/views.py:1653-1685`):
/// `{text, transcript, issues, improved_passage, scores, duration_seconds,
/// pause_count, feedback, quick_tip, score_25}`. `quick_tip` is
/// deliberately not parsed — the web's own JS never displays it, always
/// showing a client-computed tip instead (see
/// `SpeakingQuickTip`/`AiSpeakingController`'s doc comment).
extension SpeakingAnalysisResultParsing on SpeakingAnalysisResult {
  static SpeakingAnalysisResult fromJson(Map<String, dynamic> json) {
    final scoresJson = requireMap(json, 'scores');
    final scores = <String, num>{
      for (final entry in scoresJson.entries)
        if (entry.value is num) entry.key: entry.value as num,
    };
    return SpeakingAnalysisResult(
      // `transcript` mirrors `text` when present (the view sets
      // `data['transcript'] = data.get('text', '')`); `text` is the field
      // actually always populated by `SpeakingAgent.run`.
      transcript: (json['transcript'] as String?) ?? requireString(json, 'text'),
      issues: requireList(json, 'issues').map((e) => _issueFromJson(asMap(e, 'issues[]'))).toList(),
      improvedPassage: requireString(json, 'improved_passage'),
      feedback: json['feedback'] is String ? json['feedback'] as String : null,
      scores: scores,
      score25: requireInt(json, 'score_25'),
      durationSeconds: requireNum(json, 'duration_seconds').toDouble(),
      pauseCount: requireInt(json, 'pause_count'),
    );
  }

  static SpeakingIssue _issueFromJson(Map<String, dynamic> json) {
    return SpeakingIssue(
      phrase: requireString(json, 'phrase'),
      type: requireString(json, 'type'),
      message: requireString(json, 'message'),
      suggestion: requireString(json, 'suggestion'),
    );
  }
}
