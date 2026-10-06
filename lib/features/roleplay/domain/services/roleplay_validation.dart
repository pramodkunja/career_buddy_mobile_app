/// Client-side mirror of `_roleplay_prompt_missing_second_character`
/// (`activities/views.py:2009-2025`) and its JS duplicate
/// (`roleplay.html:512-523`, `roleplayPromptMissingSecondCharacter`). Only
/// the Roleplay sub-feature (not Storytelling/Situations) requires a second
/// named character — a roleplay scene needs two people in it ("Student and
/// Teacher", "Customer and Shopkeeper"), not a single subject/character
/// like "Environment" or "Manager".
///
/// This is a heuristic, not real NLP: a short prompt (<=3 words) must name
/// a second party via a connector word (`and`/`vs`/`versus`/`with`/`&`/`,`);
/// a longer prompt is assumed to already describe an interaction (e.g. the
/// shipped example "Customer asking for a refund" implies a second party
/// without ever using the word "and"). An empty prompt returns `false` —
/// it falls back to the topic's `default_prompt` server-side, which is
/// always valid.
final RegExp _twoPartyConnector = RegExp(r'\b(and|vs\.?|versus|with)\b|&|,', caseSensitive: false);

bool roleplayPromptMissingSecondCharacter(String prompt) {
  final text = prompt.trim();
  if (text.isEmpty) return false;
  if (text.split(RegExp(r'\s+')).length > 3) return false;
  return !_twoPartyConnector.hasMatch(text);
}
