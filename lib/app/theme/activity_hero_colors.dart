import 'package:flutter/material.dart';

/// Resolves an `Activity.color_class` slug (e.g. `"primary"`, `"success"`,
/// `"teal"`) to the two-stop gradient it actually renders as on the web —
/// the `bg-<slug>` utility classes used by `.exercise-hero`
/// (`templates/activities/exercise.html:14`,
/// `class="exercise-hero bg-{{ activity.color_class }}"`).
///
/// Every value here is the FINAL cascade winner, not the first
/// declaration — `.bg-primary` alone is declared twice
/// (`static/css/style.css:109` then `:2579`); the second, later rule wins
/// (`!important` on both, so source order decides), resolving to navy, not
/// the first rule's blue. All other slugs below have exactly one
/// declaration each (verified by grep — no second override exists for
/// them), so the single value found is already final.
///
/// Returns `null` for an unrecognized/missing slug — the caller falls
/// back to a documented default rather than guessing.
(Color, Color)? resolveActivityHeroGradient(String? colorClass) {
  return switch (colorClass) {
    'primary' => (const Color(0xFF14213D), const Color(0xFF0B1526)), // style.css:2579 (final override)
    'success' => (const Color(0xFF10B981), const Color(0xFF059669)),
    'danger' => (const Color(0xFFEF4444), const Color(0xFFDC2626)),
    'warning' => (const Color(0xFFF59E0B), const Color(0xFFD97706)),
    'info' => (const Color(0xFF06B6D4), const Color(0xFF0891B2)),
    'purple' => (const Color(0xFF8B5CF6), const Color(0xFF7C3AED)),
    'pink' => (const Color(0xFFEC4899), const Color(0xFFDB2777)),
    'teal' => (const Color(0xFF14B8A6), const Color(0xFF0D9488)),
    'orange' => (const Color(0xFFF97316), const Color(0xFFEA580C)),
    'indigo' => (const Color(0xFF6366F1), const Color(0xFF4F46E5)),
    'rose' => (const Color(0xFFF43F5E), const Color(0xFFE11D48)),
    'emerald' => (const Color(0xFF34D399), const Color(0xFF10B981)),
    _ => null,
  };
}

/// The fallback gradient when [resolveActivityHeroGradient] returns `null`
/// (an unrecognized slug, or — as with MCQ's dedicated JSON API — no slug
/// available at all). Deliberately the same navy as `color_class`'s own
/// model default (`Activity.color_class`'s Django field default is
/// `'primary'`, `activities/models.py:43`, which itself resolves to this
/// exact navy per the final `.bg-primary` cascade above) — so this
/// fallback is the *statistically likely* real color for an
/// unspecified-color activity, not an arbitrary guess, even though it is
/// not guaranteed correct for every activity.
const kDefaultActivityHeroGradient = (Color(0xFF14213D), Color(0xFF0B1526));
