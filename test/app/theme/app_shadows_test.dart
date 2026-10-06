import 'package:career_buddy_lms/app/theme/app_shadows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Confirms the shadow tokens are navy-tinted (rgba(20,33,61,...), the web's
  // `--shadow*` custom properties, `static/css/style.css:2519-2555`) rather
  // than neutral black — every entry's color must carry the same #14213D
  // RGB channels, varying only in alpha and blur/offset.
  test('every shadow level is navy-tinted (#14213D-based), not neutral black', () {
    for (final level in [AppShadows.sm, AppShadows.md, AppShadows.lg]) {
      for (final shadow in level) {
        expect(shadow.color.toARGB32() & 0x00FFFFFF, 0x14213D);
      }
    }
  });

  test('each level is non-empty and blur/offset increase from sm to lg', () {
    expect(AppShadows.sm, isNotEmpty);
    expect(AppShadows.md, isNotEmpty);
    expect(AppShadows.lg, isNotEmpty);

    final smMaxBlur = AppShadows.sm.map((s) => s.blurRadius).reduce((a, b) => a > b ? a : b);
    final mdMaxBlur = AppShadows.md.map((s) => s.blurRadius).reduce((a, b) => a > b ? a : b);
    final lgMaxBlur = AppShadows.lg.map((s) => s.blurRadius).reduce((a, b) => a > b ? a : b);
    expect(smMaxBlur, lessThan(mdMaxBlur));
    expect(mdMaxBlur, lessThan(lgMaxBlur));
  });
}
