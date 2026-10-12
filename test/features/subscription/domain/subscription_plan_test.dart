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
  });
}
