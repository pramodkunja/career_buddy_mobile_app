import '../../../../core/utils/result.dart';
import '../entities/payment_verification_result.dart';
import '../entities/razorpay_order.dart';
import '../entities/subscription_status.dart';

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

  /// Phase 81 — fetches current plan state + captured-payment list from
  /// `GET /pro/status/` (`subscription_status_api`).
  Future<Result<SubscriptionStatus>> getStatus();

  /// Phase 81 — downloads the GST invoice HTML bytes for one
  /// `RazorpayPayment` by its pk from `GET /pro/invoice/<pk>/`.
  Future<Result<List<int>>> downloadInvoice(int paymentId);
}
