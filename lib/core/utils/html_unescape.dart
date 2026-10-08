/// Inverse of Python's `html.escape()` — what Django's template
/// autoescaping (and therefore every server-rendered page this app scrapes,
/// since none of them use `|safe`) actually runs user/AI-generated text
/// through. Confirmed directly: `html.escape("it's")` produces the HEX
/// entity `"it&#x27;s"`, not the decimal `"it&#39;s"` — every one of this
/// app's hand-rolled parsers originally only handled the decimal form
/// (`&#39;`), so a literal `&#x27;` survived unescaped into the UI
/// wherever AI-generated or other user text round-tripped through a
/// Django template (first found live in GD session reports and Resume ATS
/// analysis text, but the same gap existed in over a dozen parsers across
/// the app — all now delegate here instead of duplicating it).
///
/// Safe to apply unconditionally to the plain-text fields these parsers
/// extract: every one of them is already captured by a regex that stops at
/// the first `<` (so real HTML markup, if any ever appeared, would already
/// have been truncated out before reaching this function, never passed
/// through whole) — this only ever unescapes entities within already-plain
/// text, never rewrites real tags.
String unescapeHtmlEntities(String value) => value
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#x27;', "'")
    .replaceAll('&#39;', "'");
