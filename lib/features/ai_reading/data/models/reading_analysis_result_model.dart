import '../../../../core/utils/json_parsing.dart';
import '../../domain/entities/reading_analysis_result.dart';
import '../../domain/entities/reading_issue.dart';

/// Parses `analyze_reading`'s `data` object (`activities/views.py:1916-1969`):
/// `{text, issues, improved_passage, scores, feedback, quick_tip, score_25,
/// user_transcript}`. `score_25` is duplicated at the top level too, but
/// parsing it from `data` alone is sufficient and matches
/// `SpeakingAnalysisResultParsing`'s convention. `user_transcript` is
/// deliberately not parsed — confirmed unused by the web's own JS (see
/// `ReadingAnalysisResult`'s doc comment).
extension ReadingAnalysisResultParsing on ReadingAnalysisResult {
  static ReadingAnalysisResult fromJson(Map<String, dynamic> data) {
    final scoresJson = requireMap(data, 'scores');
    final scores = <String, num>{
      for (final entry in scoresJson.entries)
        if (entry.value is num) entry.key: entry.value as num,
    };
    return ReadingAnalysisResult(
      text: requireString(data, 'text'),
      issues: requireList(data, 'issues').map((e) => _issueFromJson(asMap(e, 'issues[]'))).toList(),
      improvedPassage: requireString(data, 'improved_passage'),
      feedback: requireString(data, 'feedback'),
      quickTip: requireString(data, 'quick_tip'),
      scores: scores,
      score25: requireInt(data, 'score_25'),
    );
  }

  static ReadingIssue _issueFromJson(Map<String, dynamic> json) {
    return ReadingIssue(
      phrase: requireString(json, 'phrase'),
      type: requireString(json, 'type'),
      message: requireString(json, 'message'),
      suggestion: requireString(json, 'suggestion'),
    );
  }
}
