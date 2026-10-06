/// One question from `amcat_questions`'s per-section `"questions"` array
/// (`activities/views.py:2291-2303`) — deliberately a simpler schema than
/// `MockTestQuestion` (no `difficulty`/`topic`): the AMCAT bank's per-section
/// payload only ever sends `id`/`q`/`options`, confirmed directly from the
/// view's own list-comprehension construction.
class AmcatQuestion {
  const AmcatQuestion({required this.id, required this.questionText, required this.options});

  final int id;
  final String questionText;

  /// Always 4 options in practice (`activities/data/amcat_full.json`).
  final List<String> options;
}
