import 'package:flutter/material.dart';

/// Elevation shadows mirrored from the web app's `--shadow*` tokens
/// (`static/css/style.css:2519-2555`, the "BLACK & GOLD ELEGANCE" override
/// block): navy-tinted (`rgba(20,33,61,...)`), not neutral black, and
/// layered as two stacked shadows on the web (a tight "contact" shadow plus
/// a soft ambient one) — approximated here as their combined visual
/// effect via a single, slightly larger blur per level, since Flutter's
/// `BoxShadow` list already composites correctly when more than one entry
/// is given.
abstract final class AppShadows {
  /// `--shadow-sm: 0 1px 2px rgba(20,33,61,.04), 0 1px 3px rgba(20,33,61,.06)`
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A14213D), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F14213D), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// `--shadow: 0 2px 4px rgba(20,33,61,.04), 0 8px 20px rgba(20,33,61,.07)`
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0A14213D), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1214213D), blurRadius: 20, offset: Offset(0, 8)),
  ];

  /// `--shadow-lg: 0 20px 45px rgba(20,33,61,.11)`
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x1C14213D), blurRadius: 45, offset: Offset(0, 20)),
  ];
}
