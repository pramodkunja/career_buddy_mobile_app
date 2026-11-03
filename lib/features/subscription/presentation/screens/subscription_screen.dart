import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_nav_drawer.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/buddy_chatbot_overlay.dart';
import '../../../../shared/widgets/drawer_aware_back_leading.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/subscription_status.dart';
import '../controllers/invoice_download_controller.dart';
import '../controllers/subscription_checkout_controller.dart';
import '../controllers/subscription_status_controller.dart';
import '../providers/subscription_providers.dart';
import '../widgets/plan_card.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkoutState = ref.watch(subscriptionCheckoutControllerProvider);
    final notifier = ref.read(subscriptionCheckoutControllerProvider.notifier);
    final statusValue = ref.watch(subscriptionStatusControllerProvider);

    ref.listen<CheckoutState>(subscriptionCheckoutControllerProvider, (previous, next) {
      switch (next) {
        case CheckoutActivated(:final planType):
          AppSnackbar.showSuccess(
            context,
            'Payment successful! Your ${planType == 'pro' ? 'Pro' : 'Normal'} plan is now active.',
          );
          notifier.reset();
          // Re-fetch plan status so the status card and plan badges reflect
          // the newly activated plan immediately.
          ref.read(subscriptionStatusControllerProvider.notifier).retry();
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

    final currentStatus = statusValue.value;

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
                _SubscriptionStatusCard(statusValue: statusValue),
                const SizedBox(height: AppSpacing.md),
                if (isProcessing) ...[
                  _CheckoutProgressBanner(state: checkoutState),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (final plan in SubscriptionCatalog.all) ...[
                  PlanCard(
                    plan: plan,
                    isCurrentPlan: _isCurrentPlanFor(plan, currentStatus),
                    isProcessing: isProcessing && processingPlanType == plan.planTypeParam,
                    onUpgrade: plan.planTypeParam == null || isProcessing
                        ? null
                        : () => notifier.startCheckout(plan.planTypeParam!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _InvoicesSection(statusValue: statusValue),
              ],
            ),
          ),
          const BuddyChatbotOverlay(),
        ],
      ),
    );
  }
}

/// Returns true when [plan] is the user's currently active plan.
/// Free plan is active whenever [status.isActive] is false (backend
/// calls `enforce_expiry()` before responding, so expired paid plans
/// always revert to `plan_type: 'free'`).
bool _isCurrentPlanFor(SubscriptionPlan plan, SubscriptionStatus? status) {
  if (status == null) return false;
  if (!status.isActive) return plan.tier == PlanTier.free;
  return plan.planTypeParam == status.planType;
}

/// Shown between the status card and the plan cards while a checkout
/// operation is in flight, so the user always knows what the app is
/// doing even though the individual Upgrade buttons are disabled.
class _CheckoutProgressBanner extends StatelessWidget {
  const _CheckoutProgressBanner({required this.state});

  final CheckoutState state;

  @override
  Widget build(BuildContext context) {
    final message = switch (state) {
      CheckoutCreatingOrder() => 'Creating your order…',
      CheckoutAwaitingPayment() => 'Waiting for payment…',
      CheckoutVerifying() => 'Verifying your payment…',
      _ => 'Processing…',
    };
    return AppCard(
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _SubscriptionStatusCard extends StatelessWidget {
  const _SubscriptionStatusCard({required this.statusValue});

  final AsyncValue<SubscriptionStatus> statusValue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: switch (statusValue) {
        AsyncLoading() => const _StatusLoading(),
        AsyncError(:final error) => _StatusError(error: error),
        AsyncData(:final value) => _StatusData(status: value),
      },
    );
  }
}

class _StatusLoading extends StatelessWidget {
  const _StatusLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text('Checking subscription status…', style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}

class _StatusError extends ConsumerWidget {
  const _StatusError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: Text('Could not load subscription status.')),
        TextButton(
          onPressed: () => ref.read(subscriptionStatusControllerProvider.notifier).retry(),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _StatusData extends StatelessWidget {
  const _StatusData({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.isActive) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free plan',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'No active subscription. Upgrade to unlock all features.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final planLabel = status.planType == 'pro' ? 'Pro' : 'Normal User';
    // Warn when expiry is within 30 days so the user knows to renew soon.
    final isUrgent = status.daysLeft != null && status.daysLeft! < 30;
    final statusColor = isUrgent ? AppColors.warning : AppColors.success;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, color: statusColor, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$planLabel plan · Active',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: statusColor),
              ),
              if (status.expiryDate != null)
                Text(
                  'Expires ${formatMonthDayYear(status.expiryDate!.toLocal())}'
                  '${status.daysLeft != null ? ' · ${status.daysLeft} days left' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoicesSection extends StatelessWidget {
  const _InvoicesSection({required this.statusValue});

  final AsyncValue<SubscriptionStatus> statusValue;

  @override
  Widget build(BuildContext context) {
    final status = statusValue.value;
    if (status == null || status.payments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('GST Invoices', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final invoice in status.payments) ...[
          _InvoiceRow(invoice: invoice),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _InvoiceRow extends ConsumerWidget {
  const _InvoiceRow({required this.invoice});

  final InvoiceRecord invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(invoiceDownloadControllerProvider(invoice.id));
    final displayName = invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : '#${invoice.id}';
    final isFailed = downloadState is InvoiceDownloadFailed;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '₹${invoice.amountRupees.toStringAsFixed(0)}  ·  '
                  '${formatMonthDayYear(invoice.createdAt.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (isFailed)
                  Text(
                    downloadState.failure.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (downloadState is InvoiceDownloading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
              tooltip: isFailed ? 'Retry download' : 'Download invoice',
              icon: Icon(isFailed ? Icons.refresh : Icons.download_outlined),
              onPressed: () => ref
                  .read(invoiceDownloadControllerProvider(invoice.id).notifier)
                  .downloadAndOpen(invoice.invoiceNumber),
            ),
        ],
      ),
    );
  }
}
