import 'amcat_question.dart';

/// One of the 5 fixed AMCAT sections, exactly as `amcat_questions` returns
/// them (`activities/views.py:2291-2303`, `_AMCAT_PLAN`): Quantitative
/// Ability, English Ability, Logical Reasoning, AMCAT Personality
/// Inventory, Domain Module (Computer Programming) — each individually
/// timed, with its own random question sample.
///
/// The server also sends a `"type"` field, always the literal `"mcq"` for
/// every section including Personality (`_AMCAT_PLAN` hardcodes
/// `"type": "mcq"` for all 5 entries — verified directly, not assumed).
/// The web's own JS has a dead `else` branch rendering a Likert scale for
/// any non-`"mcq"` type, but that branch is never reachable given the
/// current backend response, so it is deliberately NOT reproduced here —
/// every AMCAT section renders as standard 4-option MCQ, matching what the
/// live page actually shows.
class AmcatSection {
  const AmcatSection({required this.key, required this.name, required this.timeSeconds, required this.questions});

  final String key;
  final String name;
  final int timeSeconds;
  final List<AmcatQuestion> questions;
}
