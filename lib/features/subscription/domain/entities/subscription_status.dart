/// One captured payment from `GET /pro/status/`, carrying enough data to
/// render an invoice row and provide the `pk` needed for the invoice download
/// URL `/pro/invoice/<pk>/`.
class InvoiceRecord {
  const InvoiceRecord({
    required this.id,
    required this.invoiceNumber,
    required this.planType,
    required this.amountRupees,
    required this.createdAt,
  });

  final int id;
  final String invoiceNumber;
  final String planType;
  final double amountRupees;
  final DateTime createdAt;

  factory InvoiceRecord.fromJson(Map<String, dynamic> json) => InvoiceRecord(
    id: json['id'] as int,
    invoiceNumber: json['invoice_number'] as String? ?? '',
    planType: json['plan_type'] as String,
    amountRupees: ((json['amount_paise'] as int) / 100.0),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Response shape of `GET /pro/status/` (`subscription_status_api`).
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.planType,
    required this.isActive,
    this.expiryDate,
    this.daysLeft,
    required this.payments,
  });

  final String planType;
  final bool isActive;
  final DateTime? expiryDate;
  final int? daysLeft;
  final List<InvoiceRecord> payments;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatus(
        planType: json['plan_type'] as String,
        isActive: json['is_active'] as bool,
        expiryDate: json['expiry_date'] != null
            ? DateTime.parse(json['expiry_date'] as String)
            : null,
        daysLeft: json['days_left'] as int?,
        payments: (json['payments'] as List<dynamic>)
            .map((p) => InvoiceRecord.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
