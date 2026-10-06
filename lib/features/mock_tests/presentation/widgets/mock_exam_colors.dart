import 'package:flutter/material.dart';

/// Design tokens for the Mock Test exam engine, verified directly from the
/// web's actual exam-engine source: `005 oop-mastery.html`'s injected
/// `<style>` block (the OOP Mastery + Subject Quiz engine — both use the
/// exact same CSS, confirmed by grepping `API_Q=` across every
/// `TechCenter/*.html` subject page) and `amcat_mock_test.html`'s
/// `#amcat-oop-skin` override style block (the AMCAT + CoCubes engine,
/// explicitly re-skinned by the web itself, in its own code comment, to
/// "Match the OOP-engine exam aesthetic (navy/gold)"). Both engines are
/// confirmed to render an effectively identical navy/gold palette —
/// distinct from both the site's navy/gold *theme* (`app/theme/`) and the
/// Activities-MCQ blue-centric palette (`mcq_option_button.dart`).
abstract final class MockExamColors {
  static const Color navy = Color(0xFF14213D);
  static const Color navyDark = Color(0xFF0B1526);
  static const Color gold = Color(0xFFFCA311);

  /// `.exam-opt`/`.opt` default border (`#e2e8f0`).
  static const Color border = Color(0xFFE2E8F0);

  /// `.exam-opt.sel`/`.opt.selected` background (`#eef1f8`).
  static const Color selectedBg = Color(0xFFEEF1F8);

  /// `.exam-opt .k`/`.opt-badge` default background (`#f1f3ff`).
  static const Color badgeBg = Color(0xFFF1F3FF);

  /// Body text color (`--ink:#161c27`).
  static const Color ink = Color(0xFF161C27);

  /// `--muted:#718096` / eyebrow labels' base tone.
  static const Color muted = Color(0xFF718096);

  /// `--success:#38a169` (AMCAT/CoCubes `:root`) — the exam engine's own
  /// green, distinct from the app's `AppColors.success` (#10B981) and
  /// MCQ's (#10B981/#065F46).
  static const Color success = Color(0xFF38A169);
  static const Color successBg = Color(0xFFE9F7EF);

  /// `--danger:#e53e3e` (AMCAT/CoCubes `:root`) — distinct from the app's
  /// `AppColors.danger` (#EF4444) and MCQ's (#EF4444/#991B1B).
  static const Color danger = Color(0xFFE53E3E);
  static const Color dangerBg = Color(0xFFFDECEC);

  /// `.pal.marked`/gold-tinted "skip" tag background (`#fdeecb` in AMCAT's
  /// `--gold-soft`, `#FCA311` flat on OOP's `.pal.marked`) — kept as the
  /// flat gold since that's what OOP/Subject Quiz's actual marked-for-review
  /// state uses.
  static const Color markedBg = gold;
  static const Color markedText = navy;

  /// Eyebrow/question-number label color (`.qnum`/`.exam-qnum`,
  /// `#b9720a` in both engines).
  static const Color eyebrow = Color(0xFFB9720A);

  /// `.tag.skip` (AMCAT/CoCubes result review only — not touched by the
  /// `#amcat-oop-skin` override): `--gold-soft:#fdeecb` / `--gold-ink:
  /// #7a5c00`. Deliberately distinct from [markedBg]/[markedText] (OOP's
  /// flat `.pal.marked` gold) — a different role in a different engine.
  static const Color skipBg = Color(0xFFFDEECB);
  static const Color skipText = Color(0xFF7A5C00);
}
