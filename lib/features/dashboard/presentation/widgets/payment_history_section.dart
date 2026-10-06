import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/payment_record.dart';

/// Mirrors the web dashboard's "Payment History" table —
/// `dashboard.html:203-244` — as cards rather than a table, since a wide
/// table doesn't fit a phone screen. Same conditional-card behavior: the
/// web only shows this at all when `payment_history` is non-empty
/// (`{% if payment_history %}`), so this widget renders nothing rather
/// than an empty-state message for an empty list.
class PaymentHistorySection extends StatelessWidget {
  const PaymentHistorySection({required this.payments, super.key});

  final List<PaymentRecord> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < payments.length; i++) ...[
                if (i > 0) const Divider(height: AppSpacing.lg),
                _PaymentRow(payment: payments[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final PaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    // Matches the web table's `Amount`/`Date`/`Method` columns exactly
    // (`dashboard.html:224-234`): `|floatformat:2` and `|date:"M d, Y"`, and
    // "Razorpay" is a hardcoded label on the web too, not API data.
    final dateLabel = formatMonthDayYear(payment.date);
    final amountLabel = '₹${payment.amountRupees.toStringAsFixed(2)}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel, style: Theme.of(context).textTheme.bodyMedium),
              Text('Razorpay • ${payment.transactionId}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(amountLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: AppSpacing.sm),
        _StatusBadge(isActive: payment.isPlanActive),
      ],
    );
  }
}

/// `<span class="badge bg-success">Active</span>` /
/// `badge bg-danger">Non-Active` (`dashboard.html:227-230`) — a plain
/// Bootstrap badge: solid fill, white text. Neither `.bg-success` nor
/// `.bg-danger` is touched by the site's gold/navy rebrand (confirmed —
/// only `.badge.bg-primary`/`.bg-info` are), so these stay their original
/// green/red, not a tinted overlay and not gray for the "Non-Active" case.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        isActive ? 'Active' : 'Non-Active',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
