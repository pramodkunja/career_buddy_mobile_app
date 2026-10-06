import 'package:flutter/material.dart';

/// Per-exercise-type icon box colors/icon, verified directly from
/// `static/css/style.css:1826-1852` (`.exercise-mcq`/`.exercise-fill_blank`/
/// etc., each a distinct gradient) and `.exercise-type-icon` (48×48,
/// `border-radius:8px`, white icon). Only the 7 `exercise_type` values the
/// Django model actually defines are covered — confirmed from
/// `activities/models.py`'s `Exercise.EXERCISE_TYPE_CHOICES` (mcq,
/// fill_blank, matching, ordering, bingo, writing, timer); anything else
/// falls back to a neutral slate box rather than inventing a color.
class ExerciseTypeStyle {
  const ExerciseTypeStyle({required this.gradient, required this.icon});

  final List<Color> gradient;
  final IconData icon;

  static const _fallback = ExerciseTypeStyle(gradient: [Color(0xFF64748B), Color(0xFF475569)], icon: Icons.extension_outlined);

  static const Map<String, ExerciseTypeStyle> _byType = {
    'mcq': ExerciseTypeStyle(gradient: [Color(0xFF2563EB), Color(0xFF1D4ED8)], icon: Icons.check_box_outlined),
    'fill_blank': ExerciseTypeStyle(gradient: [Color(0xFF10B981), Color(0xFF059669)], icon: Icons.edit_note),
    'matching': ExerciseTypeStyle(gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED)], icon: Icons.compare_arrows),
    'ordering': ExerciseTypeStyle(gradient: [Color(0xFFF59E0B), Color(0xFFD97706)], icon: Icons.sort),
    'bingo': ExerciseTypeStyle(gradient: [Color(0xFFEC4899), Color(0xFFDB2777)], icon: Icons.grid_on),
    'writing': ExerciseTypeStyle(gradient: [Color(0xFF06B6D4), Color(0xFF0891B2)], icon: Icons.create_outlined),
    'timer': ExerciseTypeStyle(gradient: [Color(0xFFEF4444), Color(0xFFDC2626)], icon: Icons.timer_outlined),
  };

  static ExerciseTypeStyle forType(String exerciseType) => _byType[exerciseType] ?? _fallback;
}
