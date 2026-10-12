import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../domain/services/razorpay_checkout_launcher.dart';

class RazorpayCheckoutLauncherImpl implements RazorpayCheckoutLauncher {
  Razorpay? _razorpay;

  @override
  void openCheckout({
    required Map<String, dynamic> options,
    required void Function(CheckoutSuccess) onSuccess,
    required void Function(CheckoutFailure) onError,
    required void Function(String walletName) onExternalWallet,
  }) {
    _razorpay?.clear();
    final razorpay = Razorpay();
    _razorpay = razorpay;

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      onSuccess(
        CheckoutSuccess(
          paymentId: response.paymentId ?? '',
          orderId: response.orderId ?? '',
          signature: response.signature ?? '',
        ),
      );
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      onError(CheckoutFailure(code: response.code, message: response.message));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse response) {
      onExternalWallet(response.walletName ?? '');
    });

    razorpay.open(options);
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
