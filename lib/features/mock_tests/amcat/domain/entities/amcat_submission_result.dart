/// One section's server-computed tally, from `amcat_submit`'s `"sections"`
/// map (`activities/views.py:2308-2343`, `sec_score`).
class AmcatSectionScore {
  const AmcatSectionScore({required this.name, required this.correct, required this.total});

  final String name;
  final int correct;
  final int total;
}

/// One question's grading outcome, from `amcat_submit`'s `"results"` map.
/// Unlike `MockTestQuestionResult`, this deliberately has no `explanation`
/// field — the AMCAT results page never reads or displays `r.explanation`
/// at all (confirmed directly: `amcat_mock_test.html`'s review-table row
/// builder only ever reads `r.correct`/`r.answer`), even though the server
/// response includes it. Reproducing the web's actual displayed behavior,
/// not the API's full capability, is the goal here.
class AmcatQuestionResult {
  const AmcatQuestionResult({required this.isCorrect, this.correctAnswerIndex});

  final bool isCorrect;

  /// Only present when the question was attempted (same attempted-only
  /// reveal rule as OOP/Subject Quiz — `activities/views.py:2329-2337`).
  final int? correctAnswerIndex;
}

/// The server-authoritative response to `amcat_submit`
/// (`activities/views.py:2342-2343`).
class AmcatSubmissionResult {
  const AmcatSubmissionResult({required this.score, required this.total, required this.sectionScores, required this.questionResults});

  final int score;
  final int total;

  /// Section key -> that section's tally.
  final Map<String, AmcatSectionScore> sectionScores;

  /// Question id -> its grading outcome.
  final Map<int, AmcatQuestionResult> questionResults;

  /// There is no separate server-provided "overall percentage" field, so
  /// this is computed from [score]/[total] directly — matching
  /// `cocubes_mock_test.html`'s own explicit preference (`showResults()`:
  /// `const gt = data.total != null ? data.total : overallTotal; const gc =
  /// data.score != null ? data.score : overallCorrect;`, i.e. it prefers
  /// the server's top-level fields over summing `sections`, specifically
  /// because a free-text "code" section — never actually served today, see
  /// `AmcatState`'s doc comment — would inflate a per-section sum without
  /// affecting the true top-level `total` (`activities/views.py:2407-2414`:
  /// `sec_score[sec]["total"] += 1` runs before the code-type `continue`,
  /// but the global `total += 1` does not). AMCAT's `amcat_submit` has no
  /// such carve-out, so both computations agree there today regardless —
  /// this is the one shared, always-correct choice for both.
  double get overallPercentage {
    if (total == 0) return 0;
    return (score / total) * 100;
  }
}
