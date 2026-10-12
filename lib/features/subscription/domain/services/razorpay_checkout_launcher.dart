/// Razorpay's own callback fields (`PaymentSuccessResponse`), re-declared
/// here so the domain/presentation layers never import
/// `package:razorpay_flutter` directly — the same reasoning as this
/// codebase's other native-plugin wrappers (`AudioRecorderService`,
/// `AriaVoicePlaybackService`): an injectable seam for tests, since the
/// real plugin is a native platform channel with nothing to fake through
/// `flutter test` otherwise.
class CheckoutSuccess {
  const CheckoutSuccess({required this.paymentId, required this.orderId, required this.signature});
  final String paymentId;
  final String orderId;
  final String signature;
}

class CheckoutFailure {
  const CheckoutFailure({this.code, this.message});
  final int? code;
  final String? message;
}

/// Wraps `package:razorpay_flutter`'s `Razorpay` class — the official SDK
/// (published by Team Razorpay) driving the same native Android/iOS
/// Checkout the web's own `new Razorpay(options).open()` call drives. See
/// `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §5 for why this package was
/// chosen and what it is/isn't given (never an amount/plan to compute —
/// only to display and relay).
abstract class RazorpayCheckoutLauncher {
  /// [options] mirrors the real web's own Razorpay `options` object exactly
  /// (`key`, `amount`, `currency`, `name`, `description`, `order_id`,
  /// `prefill`, `theme`) — `templates/pro.html:450-460`.
  void openCheckout({
    required Map<String, dynamic> options,
    required void Function(CheckoutSuccess) onSuccess,
    required void Function(CheckoutFailure) onError,
    required void Function(String walletName) onExternalWallet,
  });

  /// Clears Razorpay's own event listeners — call once per checkout
  /// attempt (a fresh launcher/listener set per attempt avoids a stale
  /// handler from a previous, abandoned checkout firing for a new one).
  void dispose();
}
