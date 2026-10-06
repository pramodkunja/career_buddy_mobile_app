/// `.card-*` accent colors (`templates/subject/home.html:162-172`) — each
/// index card's color comes from its `card_class`, not the raw
/// `accent_color` field in the Python data (confirmed unused by either
/// Grammar template by reading both directly). 9 of the file's 10 defined
/// classes are actually assigned to a topic; `card-indigo` (`#4f46e5`)
/// exists in the CSS but is never used by any of the 9
/// `SUBJECT_TOPIC_CARDS` entries.
const Map<String, String> kGrammarCardClassColors = {
  'card-blue': '#0ea5e9',
  'card-pink': '#ec4899',
  'card-mint': '#10b981',
  'card-peach': '#f97316',
  'card-cream': '#d97706',
  'card-lilac': '#8b5cf6',
  'card-cyan': '#06b6d4',
  'card-rose': '#f43f5e',
  'card-violet': '#7c3aed',
  'card-indigo': '#4f46e5',
};
