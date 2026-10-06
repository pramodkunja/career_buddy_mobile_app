import 'dart:convert';

/// Extracts and JSON-decodes the contents of
/// `<script type="application/json" id="$elementId">...</script>` from a
/// raw HTML document — the same well-defined blob `lv.readConfig(id)`
/// reads client-side (`linguavoice-common.js:26-34`) on every AI-module
/// page (`speaking-config`, `writing-config`, `listening-config`). Reading
/// a stable, deliberately-embedded JSON document by its element id is far
/// more robust than scraping arbitrary DOM structure — but it is still
/// coupled to the template rendering this exact tag, which is documented
/// as a known fragility in `docs/W016_AI_LISTENING.md`.
///
/// Returns `null` if the tag isn't found or its contents aren't valid
/// JSON (e.g. the request was redirected to a different page, such as the
/// "locked activity" redirect, which has no such tag at all).
Map<String, dynamic>? extractEmbeddedJsonConfig(String html, String elementId) {
  final pattern = RegExp('<script[^>]*id=["\']${RegExp.escape(elementId)}["\'][^>]*>(.*?)</script>', dotAll: true);
  final match = pattern.firstMatch(html);
  if (match == null) return null;
  final raw = match.group(1)?.trim();
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
