import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/writing_analysis_result.dart';
import '../../domain/entities/writing_issue.dart';

/// Parses `analyze_writing`'s full response body (`activities/views.py:1690-1767`),
/// **not** just its `data` object — `score_25` is a top-level sibling of
/// `data`, confirmed by reading the view directly (`result['score_25'] =
/// score_25`, with no matching write into `result['data']`, unlike
/// `analyze_speaking`).
extension WritingAnalysisResultParsing on WritingAnalysisResult {
  static WritingAnalysisResult fromJson(Map<String, dynamic> body) {
    final data = requireMap(body, 'data');
    final scoresJson = requireMap(data, 'scores');
    final scores = <String, num>{
      for (final entry in scoresJson.entries)
        if (entry.value is num) entry.key: entry.value as num,
    };
    return WritingAnalysisResult(
      text: requireString(data, 'text'),
      issues: requireList(data, 'issues').map((e) => _issueFromJson(asMap(e, 'issues[]'))).toList(),
      improvedPassage: requireString(data, 'improved_passage'),
      feedback: requireString(data, 'feedback'),
      quickTip: requireString(data, 'quick_tip'),
      scores: scores,
      score25: requireInt(body, 'score_25'),
    );
  }

  static WritingIssue _issueFromJson(Map<String, dynamic> json) {
    return WritingIssue(
      phrase: requireString(json, 'phrase'),
      type: requireString(json, 'type'),
      message: requireString(json, 'message'),
      suggestion: requireString(json, 'suggestion'),
    );
  }
}
