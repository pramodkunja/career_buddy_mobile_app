/// The real presentation-slide image count per topic
/// (`protected_media/subjectslides/<slug>/NN.png`, served by the
/// login-gated `subject_slide_image` view and preferred by
/// `_deck_slide_urls()` over the generated-SVG carousel whenever present —
/// confirmed present for all 9 topics today). Filenames are zero-padded
/// two-digit `01.png`..`NN.png`, verified directly against the real files
/// on disk (not guessed) — Flutter has no way to list a remote directory,
/// so the count is hardcoded here the same way the web's own
/// `_deck_slide_urls()` discovers it once, at request time, by globbing
/// the directory.
const Map<String, int> kGrammarSlideDeckCounts = {
  'noun': 14,
  'pronoun': 15,
  'verb': 15,
  'adjective': 15,
  'adverb': 15,
  'conjunction': 15,
  'tenses': 15,
  'sentence-structure': 14,
  'types-of-sentences': 15,
};
