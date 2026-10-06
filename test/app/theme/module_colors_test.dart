import 'package:career_buddy_lms/app/theme/module_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Locks in the exact hex values read directly from each AI module
  // template's own inline <style> block (`templates/activities/modules/
  // {speaking,writing,listening,reading}.html`) — guards against a future
  // edit silently drifting from the verified web source.
  test('matches the exact per-module accent hex values read from the web templates', () {
    expect(ModuleColors.speaking, const Color(0xFF2563EB));
    expect(ModuleColors.writing, const Color(0xFF16A34A));
    expect(ModuleColors.listening, const Color(0xFF0891B2));
    expect(ModuleColors.reading, const Color(0xFFD97706));
  });

  test('every module has a distinct color', () {
    final colors = {ModuleColors.speaking, ModuleColors.writing, ModuleColors.listening, ModuleColors.reading};
    expect(colors, hasLength(4));
  });
}
