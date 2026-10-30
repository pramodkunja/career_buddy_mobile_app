import 'package:career_buddy_lms/features/subscription/domain/entities/subscription_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionCatalog', () {
    test('all three plans are present, in Free -> Normal -> Pro order', () {
      expect(SubscriptionCatalog.all.map((p) => p.tier), [PlanTier.free, PlanTier.normal, PlanTier.pro]);
    });

    test('Free has no checkout plan_type param (never purchasable)', () {
      expect(SubscriptionCatalog.free.planTypeParam, isNull);
    });

    test('Normal and Pro send the exact plan_type the backend expects', () {
      expect(SubscriptionCatalog.normal.planTypeParam, 'normal');
      expect(SubscriptionCatalog.pro.planTypeParam, 'pro');
    });

    test('verified base prices (pre-GST) match templates/pro.html', () {
      expect(SubscriptionCatalog.free.basePriceRupees, 0);
      expect(SubscriptionCatalog.normal.basePriceRupees, 499);
      expect(SubscriptionCatalog.pro.basePriceRupees, 999);
    });

    // Phase 67 (UI-E-001/002/004/007/008) — these exact strings were
    // directly re-verified against `templates/pro.html:140-335` this phase;
    // several had drifted (see the catalog's own doc comment for detail).
    group('feature-list accuracy (Phase 67 corrections)', () {
      test('Free plan states the real 4-parse limit, not "Unlimited"', () {
        expect(SubscriptionCatalog.free.features, contains('4 Resume Parsing & ATS Score Analyses'));
        expect(SubscriptionCatalog.free.features.any((f) => f.contains('Unlimited')), isFalse);
      });

      test('Normal and Pro both state the real 90-or-above job-recommendation threshold', () {
        expect(
          SubscriptionCatalog.normal.features,
          contains('5 Matched Job Recommendations (unlocked by scoring 90 or above in the mock interview)'),
        );
        expect(
          SubscriptionCatalog.pro.features,
          contains('Unlimited Matched Job Recommendations (unlocked by scoring 90 or above in the mock interview)'),
        );
        expect(SubscriptionCatalog.normal.features.any((f) => f.contains('70 or above in the mock interview')), isFalse);
        expect(SubscriptionCatalog.pro.features.any((f) => f.contains('70 or above in the mock interview')), isFalse);
      });

      test('Normal plan\'s Skill Up certificate threshold (a distinct, genuinely-70 condition) is untouched', () {
        expect(
          SubscriptionCatalog.normal.features,
          contains(
            'Full Skill Up access (English, Aptitude, Tech Center & Non-IT Center) with certificates for scoring 70 or above',
          ),
        );
      });

      test('Normal plan has no fabricated "Grammar & Vocabulary Practice Exercises" bullet', () {
        expect(
          SubscriptionCatalog.normal.features.any((f) => f.contains('Grammar & Vocabulary Practice Exercises')),
          isFalse,
        );
      });

      test('Normal plan\'s AI Mock Interview bullet matches the real unlock condition, not "Technical"-only wording', () {
        expect(
          SubscriptionCatalog.normal.features,
          contains('AI Mock Interviews (open when your resume scores 90% or above in ATS)'),
        );
      });
    });
  });
}
