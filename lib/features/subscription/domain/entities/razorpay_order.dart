/// The exact fields `create_razorpay_order` returns on success
/// (`career_app/views.py:510-520`, re-verified in
/// `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §1). [amountPaise] is the
/// **authoritative** total (base + 18% GST, in paise) — never recomputed
/// client-side, passed straight into Razorpay Checkout and used to derive
/// the GST breakdown shown to the user, same as `templates/pro.html:513-514`.
class RazorpayOrder {
  const RazorpayOrder({
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
    required this.planType,
    required this.planLabel,
    required this.userName,
    required this.userEmail,
  });

  final String orderId;
  final int amountPaise;
  final String currency;
  final String keyId;
  final String planType;
  final String planLabel;
  final String userName;
  final String userEmail;

  double get totalRupees => amountPaise / 100;

  /// Recovers the pre-GST base from the authoritative total, exactly like
  /// `templates/pro.html:513`'s `baseRs = order.amount / 1.18 / 100` — never
  /// the other way around (the base is never sent to the server as a
  /// trusted figure; it only ever derives a *display* number from what the
  /// server already quoted).
  double get baseRupees => totalRupees / 1.18;

  double get gstRupees => totalRupees - baseRupees;
}
