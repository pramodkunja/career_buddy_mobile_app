import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/listening_analysis_result.dart';
import '../../domain/entities/listening_issue.dart';

/// Parses `analyze_listening`'s `data` object (`activities/views.py:1770-1908`):
/// `{text, issues, improved_passage, scores, feedback, quick_tip, score_25,
/// content_match_percent}`. `score_25`/`content_match_percent` are read
/// from **this same `data` map**, not the response body's top level —
/// confirmed the view mutates `result['data']` in place, unlike
/// `analyze_writing`. `quick_tip` is deliberately not parsed — the web's
/// own JS never displays it (see `listening_feedback.dart`'s doc comment).
extension ListeningAnalysisResultParsing on ListeningAnalysisResult {
  static ListeningAnalysisResult fromJson(Map<String, dynamic> data) {
    final scoresJson = requireMap(data, 'scores');
    final scores = <String, num>{
      for (final entry in scoresJson.entries)
        if (entry.value is num) entry.key: entry.value as num,
    };
    return ListeningAnalysisResult(
      text: requireString(data, 'text'),
      issues: requireList(data, 'issues').map((e) => _issueFromJson(asMap(e, 'issues[]'))).toList(),
      improvedPassage: requireString(data, 'improved_passage'),
      feedback: requireString(data, 'feedback'),
      scores: scores,
      score25: requireInt(data, 'score_25'),
      contentMatchPercent: requireInt(data, 'content_match_percent'),
    );
  }

  static ListeningIssue _issueFromJson(Map<String, dynamic> json) {
    return ListeningIssue(
      phrase: requireString(json, 'phrase'),
      type: requireString(json, 'type'),
      message: requireString(json, 'message'),
      suggestion: requireString(json, 'suggestion'),
    );
  }
}
