class PaymentRecord {
  const PaymentRecord({
    required this.date,
    required this.isPlanActive,
    required this.amountRupees,
    required this.transactionId,
  });

  final DateTime date;
  final bool isPlanActive;
  final num amountRupees;
  final String transactionId;
}
