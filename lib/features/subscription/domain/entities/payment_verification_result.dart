/// `verify_razorpay_payment`'s two non-rejection outcomes
/// (`career_app/views.py:523-708`, re-verified in
/// `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §1). A real rejection
/// (bad signature, replay, ownership mismatch, amount mismatch, already on
/// a higher plan — all distinct server-side causes that collapse to the
/// same client-facing shape) is deliberately **not** a third variant here —
/// the real web itself never distinguishes them in its own UI either
/// (`templates/pro.html`'s `handler` callback shows `result.error` the same
/// way for any of them), so those surface as an ordinary repository
/// `Failed`, same as a network-level failure.
sealed class PaymentVerificationResult {
  const PaymentVerificationResult();
}

/// `{"success": true, "plan_type": ...}` — the plan is live.
final class PaymentActivated extends PaymentVerificationResult {
  const PaymentActivated(this.planType);
  final String planType;
}

/// `{"success": false, "pending": true, "error": ...}` (HTTP 200) — the
/// payment was captured but could not be confirmed immediately (Razorpay
/// unreachable, or the order isn't marked `paid` yet). The webhook
/// (`razorpay_webhook`, server-to-server, no mobile equivalent needed)
/// finishes activation on its own; this is not a failure to show as one.
final class PaymentPending extends PaymentVerificationResult {
  const PaymentPending(this.message);
  final String message;
}
