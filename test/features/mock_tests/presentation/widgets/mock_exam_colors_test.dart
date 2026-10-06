import 'package:career_buddy_lms/features/mock_tests/presentation/widgets/mock_exam_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Locks in the exact hex values read directly from the web exam
  // engine's own source (`005 oop-mastery.html`'s injected <style>, and
  // `amcat_mock_test.html`'s `#amcat-oop-skin` override) — guards against
  // a future edit silently drifting from the verified web source, and
  // against accidentally reusing the site theme's or MCQ's colors instead.
  test('matches the exact exam-engine hex values read from the web source', () {
    expect(MockExamColors.navy, const Color(0xFF14213D));
    expect(MockExamColors.navyDark, const Color(0xFF0B1526));
    expect(MockExamColors.gold, const Color(0xFFFCA311));
    expect(MockExamColors.border, const Color(0xFFE2E8F0));
    expect(MockExamColors.selectedBg, const Color(0xFFEEF1F8));
    expect(MockExamColors.badgeBg, const Color(0xFFF1F3FF));
    expect(MockExamColors.success, const Color(0xFF38A169));
    expect(MockExamColors.successBg, const Color(0xFFE9F7EF));
    expect(MockExamColors.danger, const Color(0xFFE53E3E));
    expect(MockExamColors.dangerBg, const Color(0xFFFDECEC));
    expect(MockExamColors.eyebrow, const Color(0xFFB9720A));
    expect(MockExamColors.skipBg, const Color(0xFFFDEECB));
    expect(MockExamColors.skipText, const Color(0xFF7A5C00));
  });

  test('the exam engine\'s success/danger are distinct from both the app theme\'s and MCQ\'s', () {
    // AppColors.success = 0xFF10B981, AppColors.danger = 0xFFEF4444 —
    // confirmed deliberately different exam-engine-specific tones.
    expect(MockExamColors.success, isNot(const Color(0xFF10B981)));
    expect(MockExamColors.danger, isNot(const Color(0xFFEF4444)));
  });
}
