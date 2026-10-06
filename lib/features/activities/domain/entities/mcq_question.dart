/// A single MCQ question — read from the same `exercise_detail` HTML page
/// (`templates/activities/exercise.html`'s `questions_json`,
/// `activities/views.py:1389-1403`) Matching/Bingo/Fill-Blank/Generic-
/// Writing already read for their own question content (there is no mobile
/// JSON API for this; the earlier dedicated `mcq_exercise_api`/
/// `submit_mcq_exercise_api` pair was confirmed not deployed to
/// production). That page embeds [correctAnswer]/[explanation] in the
/// initial page load (the client self-grades and reports its own score —
/// the same trust model every other HTML-scraped exercise type already
/// uses), so — unlike this class's previous, JSON-API-era shape — these
/// are known up front, not only after submission.
class McqQuestion {
  const McqQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.explanation,
  });

  final int id;
  final String questionText;

  /// Option letter ('a'-'d') to its display text. Only the letters the
  /// backend actually populated are present — a question may have fewer
  /// than 4 options.
  final Map<String, String> options;
  final String correctAnswer;
  final String? explanation;
}
