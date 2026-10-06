import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/entities/grammar_card_colors.dart';
import '../domain/entities/grammar_topic.dart';

/// Loads the 9 Grammar topics from the bundled `assets/data/
/// grammar_data.json` — a byte-for-byte, `ast.literal_eval`-extracted copy
/// of `subject_views.py`'s own `SUBJECT_TOPIC_CARDS`/`SUBJECT_TOPICS`/
/// `TOPIC_EMOJI` constants (see `docs/UI_PARITY_MASTER_AUDIT.md` §7 Batch 7
/// for how it was produced). This is genuinely static content — the same
/// 9 topics for every user, no per-user/session data — so bundling it as
/// an asset (rather than an API call this app has no way to make, since
/// none exists) is the correct "static web content reproduced in Flutter"
/// case, not a fabrication.
class GrammarDataSource {
  List<GrammarTopicSummary>? _cardsCache;
  Map<String, GrammarTopicDetail>? _topicsCache;

  Future<void> _ensureLoaded() async {
    if (_cardsCache != null && _topicsCache != null) return;
    final raw = await rootBundle.loadString('assets/data/grammar_data.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final cardsJson = json['SUBJECT_TOPIC_CARDS'] as List<dynamic>;
    _cardsCache = [
      for (final c in cardsJson.cast<Map<String, dynamic>>())
        GrammarTopicSummary(
          slug: c['slug'] as String,
          title: c['title'] as String,
          description: c['description'] as String,
          badge: c['badge'] as String,
          emoji: _emojiFor(json, c['slug'] as String),
          accentColorHex: kGrammarCardClassColors[c['card_class']] ?? '#185ADB',
        ),
    ];

    final topicsJson = (json['SUBJECT_TOPICS'] as Map<String, dynamic>);
    _topicsCache = {
      for (final entry in topicsJson.entries)
        entry.key: _parseTopic(entry.value as Map<String, dynamic>),
    };
  }

  String _emojiFor(Map<String, dynamic> json, String slug) {
    final emojis = json['TOPIC_EMOJI'] as Map<String, dynamic>;
    return (emojis[slug] as String?) ?? '📘';
  }

  GrammarTopicDetail _parseTopic(Map<String, dynamic> t) {
    return GrammarTopicDetail(
      slug: t['slug'] as String,
      title: t['title'] as String,
      definition: t['definition'] as String,
      roleItems: (t['role_items'] as List<dynamic>).cast<String>(),
      summaryRows: [
        for (final row in (t['summary_rows'] as List<dynamic>))
          GrammarSummaryRow(
            type: (row as List<dynamic>)[0] as String,
            definition: row[1] as String,
            example: row[2] as String,
          ),
      ],
      slides: [
        for (final s in (t['slides'] as List<dynamic>).cast<Map<String, dynamic>>())
          GrammarSlide(title: s['title'] as String, lines: (s['lines'] as List<dynamic>).cast<String>()),
      ],
      audioText: t['audio_text'] as String,
      sections: [
        for (final s in (t['sections'] as List<dynamic>).cast<Map<String, dynamic>>()) _parseSection(s),
      ],
    );
  }

  GrammarSection _parseSection(Map<String, dynamic> s) {
    return GrammarSection(
      heading: s['heading'] as String,
      lead: s['lead'] as String?,
      tableHeaders: (s['table_headers'] as List<dynamic>?)?.cast<String>(),
      tableRows: (s['table_rows'] as List<dynamic>?)
          ?.map((row) => (row as List<dynamic>).cast<String>())
          .toList(),
      categoryItems: (s['category_items'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>()
          .map((c) => GrammarCategoryItem(label: c['label'] as String, text: c['text'] as String))
          .toList(),
      ruleBoxes: (s['rule_boxes'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>()
          .map((r) => GrammarRuleBox(title: r['title'] as String, text: r['text'] as String))
          .toList(),
      exampleItems: (s['example_items'] as List<dynamic>?)?.cast<String>(),
      exercises: (s['exercises'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>()
          .map((e) => GrammarExercise(question: e['question'] as String, answer: e['answer'] as String))
          .toList(),
    );
  }

  Future<List<GrammarTopicSummary>> getTopicCards() async {
    await _ensureLoaded();
    return _cardsCache!;
  }

  Future<GrammarTopicDetail> getTopicDetail(String slug) async {
    await _ensureLoaded();
    final topic = _topicsCache![slug];
    if (topic == null) {
      throw StateError('Unknown Grammar topic: $slug');
    }
    return topic;
  }
}
