/// One of the 4 independently-scored dimensions in a [GdReport]
/// (`fluency`/`grammar`/`relevance`/`confidence` — `analyze_user_performance`,
/// `GD_app/agents.py`). Each is scored out of 25 (the 4 sum to
/// [GdReport.overallScore] out of 100).
class GdReportDimension {
  const GdReportDimension({required this.score, required this.feedback});

  final int score;
  final String feedback;

  factory GdReportDimension.fromJson(Map<String, dynamic>? json) {
    final scoreValue = json?['score'];
    return GdReportDimension(
      score: scoreValue is num ? scoreValue.round() : 0,
      feedback: json?['feedback'] as String? ?? '',
    );
  }
}

/// The post-session performance report — the exact shape
/// `analyze_user_performance` returns (`GD_app/agents.py`) and the server
/// persists verbatim into `GDSession.performance_report`. Delivered live over
/// the WebSocket as the `type: 'report'` payload's `report` field
/// (`GDConsumer._end_session`), and re-readable later via
/// `GD_app:session_report` (`GD_app/report.html`, parsed by
/// `parseGdReportHtml`) — both sources are parsed into this same entity.
///
/// Two degenerate shapes the server can return instead of a full report
/// (`analyze_user_performance`'s early-return branches when the user never
/// spoke, or spoke fewer than 5 characters): `overall_score` is `0` and
/// every dimension's `feedback` is a short fixed string
/// ("No speech detected."/"Short response.") with `score: 0` — these still
/// parse cleanly into this same shape, no special-casing needed.
class GdReport {
  const GdReport({
    required this.overallScore,
    required this.fluency,
    required this.grammar,
    required this.relevance,
    required this.confidence,
    required this.strengths,
    required this.improvements,
    required this.summary,
  });

  final int overallScore;
  final GdReportDimension fluency;
  final GdReportDimension grammar;
  final GdReportDimension relevance;
  final GdReportDimension confidence;
  final List<String> strengths;
  final List<String> improvements;
  final String summary;

  factory GdReport.fromJson(Map<String, dynamic> json) {
    final overall = json['overall_score'];
    return GdReport(
      overallScore: overall is num ? overall.round() : 0,
      fluency: GdReportDimension.fromJson(json['fluency'] as Map<String, dynamic>?),
      grammar: GdReportDimension.fromJson(json['grammar'] as Map<String, dynamic>?),
      relevance: GdReportDimension.fromJson(json['relevance'] as Map<String, dynamic>?),
      confidence: GdReportDimension.fromJson(json['confidence'] as Map<String, dynamic>?),
      strengths: (json['strengths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      improvements: (json['improvements'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      summary: json['summary'] as String? ?? '',
    );
  }
}
