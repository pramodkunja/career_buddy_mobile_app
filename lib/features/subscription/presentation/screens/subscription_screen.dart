import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../domain/entities/subscription_plan.dart';
import '../controllers/subscription_checkout_controller.dart';
import '../providers/subscription_providers.dart';
import '../widgets/plan_card.dart';

/// `pro_page` (`templates/pro.html`) — see
/// `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` for the verified contract this
/// consumes and, critically, what it does *not*: there is no backend
/// endpoint for "what plan am I on" (§2), so this screen never claims to
/// know — the banner below says so explicitly instead of guessing Free.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkoutState = ref.watch(subscriptionCheckoutControllerProvider);
    final notifier = ref.read(subscriptionCheckoutControllerProvider.notifier);

    ref.listen<CheckoutState>(subscriptionCheckoutControllerProvider, (previous, next) {
      switch (next) {
        case CheckoutActivated(:final planType):
          AppSnackbar.showSuccess(
            context,
            'Payment successful! Your ${planType == 'pro' ? 'Pro' : 'Normal'} plan is now active.',
          );
          notifier.reset();
        case CheckoutPending(:final message):
          AppSnackbar.showSuccess(context, message);
          notifier.reset();
        case CheckoutCancelled():
          notifier.reset();
        case CheckoutFailed(:final failure):
          AppSnackbar.showError(context, failure.message);
          notifier.reset();
        case CheckoutIdle():
        case CheckoutCreatingOrder():
        case CheckoutAwaitingPayment():
        case CheckoutVerifying():
          break;
      }
    });

    final isProcessing = switch (checkoutState) {
      CheckoutCreatingOrder() || CheckoutAwaitingPayment() || CheckoutVerifying() => true,
      _ => false,
    };
    final processingPlanType = switch (checkoutState) {
      CheckoutCreatingOrder(:final planType) => planType,
      CheckoutVerifying(:final planType) => planType,
      CheckoutAwaitingPayment(order: final order) => order.planType,
      _ => null,
    };

    return Scaffold(
      drawer: const AppNavDrawer(),
      appBar: AppBar(title: const Text('Upgrade Plan'), leading: drawerAwareBackLeading(context)),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          "We can't check your current plan from the app yet. "
                          'Visit the Career Buddy website to see your active plan and expiry date.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final plan in SubscriptionCatalog.all) ...[
                  PlanCard(
                    plan: plan,
                    isProcessing: isProcessing && processingPlanType == plan.planTypeParam,
                    onUpgrade: plan.planTypeParam == null || isProcessing
                        ? null
                        : () => notifier.startCheckout(plan.planTypeParam!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}
