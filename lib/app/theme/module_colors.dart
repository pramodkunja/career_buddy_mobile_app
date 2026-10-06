import 'package:flutter/material.dart';

/// Per-AI-module accent colors. Each of the 4 AI module pages
/// (`templates/activities/modules/{speaking,writing,listening,reading}.html`)
/// is its own self-styled "mini brand" with its own hero gradient and
/// accent color — confirmed NOT tied to the site-wide navy/gold theme by
/// reading each template's inline `<style>` block directly. Used for the
/// score display and other module-identifying accents on each AI screen.
abstract final class ModuleColors {
  /// `templates/activities/modules/speaking.html` — `#2563eb`.
  static const Color speaking = Color(0xFF2563EB);

  /// `templates/activities/modules/writing.html` — `#16a34a`.
  static const Color writing = Color(0xFF16A34A);

  /// `templates/activities/modules/listening.html` — `#0891b2`.
  static const Color listening = Color(0xFF0891B2);

  /// `templates/activities/modules/reading.html` — `#d97706`.
  static const Color reading = Color(0xFFD97706);
}
