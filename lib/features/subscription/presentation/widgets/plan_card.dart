import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/subscription_plan.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    required this.plan,
    required this.onUpgrade,
    this.isProcessing = false,
    this.isCurrentPlan = false,
    super.key,
  });

  final SubscriptionPlan plan;
  final VoidCallback? onUpgrade;
  final bool isProcessing;

  /// Whether this plan is the user's currently active plan. When true, a
  /// "Current plan" badge replaces the "Recommended" badge on Pro.
  final bool isCurrentPlan;

  @override
  Widget build(BuildContext context) {
    final isPro = plan.tier == PlanTier.pro;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isPro ? AppColors.primary : null),
                ),
              ),
              if (isCurrentPlan)
                _PlanBadge(label: 'Current plan', color: AppColors.success)
              else if (isPro)
                _PlanBadge(label: 'Recommended', color: AppColors.primary),
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

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
