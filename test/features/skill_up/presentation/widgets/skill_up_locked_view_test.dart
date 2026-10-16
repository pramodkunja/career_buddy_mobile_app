import 'package:career_buddy_lms/features/skill_up/presentation/widgets/skill_up_locked_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 38 — the native locked-content state [SkillUpLessonScreen] shows
/// when `core/skillup_access.py`'s `SkillUpAccessMiddleware` returns HTTP
/// 403 for a restricted lesson. [SkillUpLessonScreen] itself can't be
/// pumped in a plain `flutter test` run (it needs a live `WebViewController`
/// platform implementation, which isn't registered outside a real device/
/// emulator), so this widget — the only genuinely native, non-WebView part
/// of that screen's locked path — is tested directly in isolation instead.
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SkillUpLockedView', () {
    testWidgets(
      'shows the same locked-content copy as the real backend\'s own LOCKED_PAGE',
      (tester) async {
        await tester.pumpWidget(_wrap(SkillUpLockedView(onViewPlans: () {})));

        expect(find.text('This Skill Up content is locked'), findsOneWidget);
        expect(
          find.text(
            'Your Free plan includes English & Vocabulary, Grammar and one activity. Upgrade to unlock '
            'Aptitude, the Tech Center, the Non-IT Center and certifications.',
          ),
          findsOneWidget,
        );
        expect(find.text('View Plans'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping View Plans invokes the upgrade callback exactly once',
      (tester) async {
        var tapCount = 0;
        await tester.pumpWidget(
          _wrap(SkillUpLockedView(onViewPlans: () => tapCount++)),
        );

        await tester.tap(find.text('View Plans'));
        await tester.pump();

        expect(tapCount, 1);
      },
    );

    testWidgets(
      'renders without horizontal overflow at the narrowest target width (320px)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(SkillUpLockedView(onViewPlans: () {})));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
