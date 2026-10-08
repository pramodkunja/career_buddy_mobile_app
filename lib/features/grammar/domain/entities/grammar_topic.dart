/// One card on the Grammar index (`templates/subject/home.html:303-319`,
/// `subject_views.py`'s `SUBJECT_TOPIC_CARDS`/`_topic_cards()`/
/// `TOPIC_EMOJI`).
class GrammarTopicSummary {
  const GrammarTopicSummary({
    required this.slug,
    required this.title,
    required this.description,
    required this.badge,
    required this.emoji,
    required this.accentColorHex,
  });

  final String slug;
  final String title;
  final String description;
  final String badge;
  final String emoji;

  /// The real cascade-winning color for this card, resolved from its
  /// `card_class` (`.card-blue` etc., `home.html:162-172`) — NOT
  /// `accent_color` from the raw data, which is confirmed unused by both
  /// Grammar templates (see `GrammarCardColors`'s doc comment).
  final String accentColorHex;
}

/// One row of `topic.summary_rows` — `[type, definition, example]`, no
/// header of its own in the data; the header labels ("Type"/"Definition"/
/// "Example") are template-literal (`detail.html:593-597`), reproduced as
/// literal Dart strings for the same reason, not carried per-row.
class GrammarSummaryRow {
  const GrammarSummaryRow({required this.type, required this.definition, required this.example});

  final String type;
  final String definition;
  final String example;
}

/// One authored lesson slide (`topic.slides`/`topic.slide_cards`) — shown
/// as a real `<ul>` text card under "Lesson slides" (`detail.html:561-579`),
/// paired with Django's own on-the-fly generated SVG illustration
/// (`_build_illustration_svg`, keyed off this same title/lines/accent
/// color — `ApiEndpoints.subjectIllustration`, rendered by
/// `GrammarDetailScreen`'s `_SlideIllustration`). Confirmed live:
/// unconditional on every one of the 9 topics, unlike the big "Visual
/// Guide" carousel's own illustration fallback (dead today — see
/// `GrammarDetailScreen`'s doc comment for that *real* photographed slide
/// deck, reproduced as an actual image carousel).
class GrammarSlide {
  const GrammarSlide({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

class GrammarCategoryItem {
  const GrammarCategoryItem({required this.label, required this.text});
  final String label;
  final String text;
}

class GrammarRuleBox {
  const GrammarRuleBox({required this.title, required this.text});
  final String title;
  final String text;
}

class GrammarExercise {
  const GrammarExercise({required this.question, required this.answer});
  final String question;

  /// Always rendered directly under the question — confirmed by reading
  /// `detail.html` directly: there is no "Show Answer" reveal/toggle
  /// anywhere in the real page, so none is added here either.
  final String answer;
}

/// One entry of `topic.sections` (`detail.html:613-676`) — a heading/lead
/// plus exactly one of 5 optional content shapes, matching whichever
/// `{% if %}` branch the real template takes for that section.
class GrammarSection {
  const GrammarSection({
    required this.heading,
    this.lead,
    this.tableHeaders,
    this.tableRows,
    this.categoryItems,
    this.ruleBoxes,
    this.exampleItems,
    this.exercises,
  });

  final String heading;
  final String? lead;
  final List<String>? tableHeaders;
  final List<List<String>>? tableRows;
  final List<GrammarCategoryItem>? categoryItems;
  final List<GrammarRuleBox>? ruleBoxes;
  final List<String>? exampleItems;
  final List<GrammarExercise>? exercises;
}

/// The full lesson (`templates/subject/detail.html`,
/// `subject_views.py`'s `SUBJECT_TOPICS[slug]`/`_topic_context()`).
class GrammarTopicDetail {
  const GrammarTopicDetail({
    required this.slug,
    required this.title,
    required this.definition,
    required this.roleItems,
    required this.summaryRows,
    required this.slides,
    required this.audioText,
    required this.sections,
  });

  final String slug;
  final String title;
  final String definition;
  final List<String> roleItems;
  final List<GrammarSummaryRow> summaryRows;
  final List<GrammarSlide> slides;

  /// `topic.audio_text` — spoken aloud for "Audio Recap"
  /// (`detail.html:986-995`'s `speechSynthesis` fallback path; see
  /// `GrammarAudioPlayerSheet`'s doc comment for why this app reproduces
  /// only that path, not the neural-TTS-server preference in front of it).
  final String audioText;
  final List<GrammarSection> sections;
}
