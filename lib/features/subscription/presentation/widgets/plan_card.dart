import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/subscription_plan.dart';

/// One plan's card — `templates/pro.html:140-360`'s three `.plan-card`
/// blocks, reproduced with this app's own [AppCard]/[AppButton] instead of
/// bespoke styling. [isCurrentPlanKnown] is always `false` today (no status
/// endpoint — see `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §2), kept as a
/// parameter rather than hardcoded so a future status-aware build only has
/// to change the caller, not this widget.
class PlanCard extends StatelessWidget {
  const PlanCard({required this.plan, required this.onUpgrade, this.isProcessing = false, super.key});

  final SubscriptionPlan plan;
  final VoidCallback? onUpgrade;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final isPro = plan.tier == PlanTier.pro;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.label,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isPro ? AppColors.primary : null),
              ),
              if (isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Recommended',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(plan.tagline, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.basePriceRupees == 0 ? '₹0' : '₹${plan.basePriceRupees}',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: isPro ? AppColors.primary : null),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    plan.basePriceRupees == 0 ? '/ Free' : '/ year (+ 18% GST)',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          ...plan.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(feature, style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (plan.planTypeParam != null)
            AppButton(
              label: 'Upgrade to ${plan.label} — ₹${plan.basePriceRupees}/yr',
              onPressed: onUpgrade,
              isLoading: isProcessing,
              backgroundColor: isPro ? AppColors.primary : null,
            ),
        ],
      ),
    );
  }
}
