/// Mirrors `updateWordGuard()`'s exact rule (`writing.js:130-167`), which
/// the server independently re-enforces the same way
/// (`WritingAgent.run()`, `activities/agents/writing.py:26-33`,
/// `AgentInputError` below 500 or above 900) — unlike AI Speaking's
/// 25-word client-only gate, this one is genuinely server-authoritative
/// too, confirmed by reading both sides rather than assumed.
const int kWritingMinChars = 500;
const int kWritingMaxChars = 900;

/// Non-whitespace character count — `text.replace(/\s+/g, '').length` in
/// JS, ported verbatim (collapsing/counting every Unicode whitespace run,
/// not just ASCII spaces, matching `\s` in a JS regex).
int countNonSpaceChars(String text) => text.replaceAll(RegExp(r'\s+'), '').length;

bool isWritingLengthValid(String text) {
  final chars = countNonSpaceChars(text);
  return chars >= kWritingMinChars && chars <= kWritingMaxChars;
}
