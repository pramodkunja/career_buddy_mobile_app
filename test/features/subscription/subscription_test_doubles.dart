import 'package:career_buddy_lms/features/subscription/domain/services/razorpay_checkout_launcher.dart';

/// Stands in for the real native Razorpay plugin — lets controller tests
/// drive every outcome (success/error/cancellation/external wallet)
/// deterministically, without a platform channel. See
/// `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §5 and
/// `RazorpayCheckoutLauncher`'s own doc comment for why this seam exists.
class FakeRazorpayCheckoutLauncher implements RazorpayCheckoutLauncher {
  Map<String, dynamic>? lastOptions;
  bool disposed = false;
  int openCount = 0;

  void Function(CheckoutSuccess)? _onSuccess;
  void Function(CheckoutFailure)? _onError;
  void Function(String)? _onExternalWallet;

  @override
  void openCheckout({
    required Map<String, dynamic> options,
    required void Function(CheckoutSuccess) onSuccess,
    required void Function(CheckoutFailure) onError,
    required void Function(String walletName) onExternalWallet,
  }) {
    openCount++;
    lastOptions = options;
    _onSuccess = onSuccess;
    _onError = onError;
    _onExternalWallet = onExternalWallet;
  }

  /// Test-only trigger: simulates Razorpay firing its success callback.
  void simulateSuccess(CheckoutSuccess success) => _onSuccess?.call(success);

  /// Test-only trigger: simulates Razorpay firing its error callback (used
  /// for both a real failure and a user-cancelled checkout — the plugin
  /// reports cancellation as this same event with its own reserved code).
  void simulateError(CheckoutFailure failure) => _onError?.call(failure);

  void simulateExternalWallet(String walletName) => _onExternalWallet?.call(walletName);

  @override
  void dispose() => disposed = true;
}

/// Razorpay's own documented error code for a user-dismissed Checkout
/// sheet — mirrors the private constant in `SubscriptionCheckoutController`
/// (kept in sync manually, same as that controller's own doc comment notes
/// about the plugin exposing codes as plain `int`s, not a shared enum).
const int kFakeRazorpayPaymentCancelledCode = 2;
