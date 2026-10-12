import '../../../../core/utils/result.dart';
import '../entities/payment_verification_result.dart';
import '../entities/razorpay_order.dart';

/// `career_app.views.create_razorpay_order`/`verify_razorpay_payment` — see
/// `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §1 for the full verified
/// contract. There is deliberately no `getCurrentPlan()`/similar method on
/// this repository: no backend endpoint returns that (§2 of the same
/// report) — adding one here would mean faking its implementation, which
/// this phase's rules explicitly forbid.
abstract class SubscriptionRepository {
  /// [planType] must be `'normal'` or `'pro'` (`SubscriptionPlan.planTypeParam`).
  Future<Result<RazorpayOrder>> createOrder(String planType);

  /// Forwards Razorpay's own checkout callback fields straight to the
  /// server for signature verification — this app never verifies a
  /// signature itself (rule 4: a client callback alone is never proof of
  /// payment).
  Future<Result<PaymentVerificationResult>> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  });
}
