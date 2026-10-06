import 'package:career_buddy_lms/features/activities/presentation/widgets/exercise_type_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Locks in the exact gradient hex pairs from `static/css/style.css`'s
  // `.exercise-{type}` rules (each exercise type's own distinct color),
  // for every `exercise_type` value the Django model actually defines
  // (`activities/models.py`'s `EXERCISE_TYPE_CHOICES`).
  test('every real exercise_type has its own verified gradient', () {
    const expected = {
      'mcq': [0xFF2563EB, 0xFF1D4ED8],
      'fill_blank': [0xFF10B981, 0xFF059669],
      'matching': [0xFF8B5CF6, 0xFF7C3AED],
      'ordering': [0xFFF59E0B, 0xFFD97706],
      'bingo': [0xFFEC4899, 0xFFDB2777],
      'writing': [0xFF06B6D4, 0xFF0891B2],
      'timer': [0xFFEF4444, 0xFFDC2626],
    };

    for (final entry in expected.entries) {
      final style = ExerciseTypeStyle.forType(entry.key);
      expect(style.gradient.map((c) => c.toARGB32()).toList(), entry.value, reason: entry.key);
    }
  });

  test('an unrecognized exercise_type falls back to a neutral slate gradient, not an invented color', () {
    final style = ExerciseTypeStyle.forType('speaking');
    expect(style.gradient, [const Color(0xFF64748B), const Color(0xFF475569)]);
  });
}
