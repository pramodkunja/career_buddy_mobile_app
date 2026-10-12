import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/payment_verification_result.dart';
import '../../domain/entities/razorpay_order.dart';
import '../../domain/services/razorpay_checkout_launcher.dart';
import '../providers/subscription_providers.dart';

/// One checkout attempt, start to finish — mirrors the real web's own
/// sequence exactly (`templates/pro.html:421-530`'s `startPayment`):
/// create order -> open Checkout -> on success, verify -> show the
/// authoritative outcome. See
/// `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §1/§6 for why there is no
/// "refresh subscription status" step after [CheckoutActivated] — no
/// backend endpoint exists to refresh *from*.
sealed class CheckoutState {
  const CheckoutState();
}

final class CheckoutIdle extends CheckoutState {
  const CheckoutIdle();
}

final class CheckoutCreatingOrder extends CheckoutState {
  const CheckoutCreatingOrder(this.planType);
  final String planType;
}

/// The native Razorpay Checkout sheet is open; this app is waiting on its
/// callback (success/error/external-wallet) or the user dismissing it.
final class CheckoutAwaitingPayment extends CheckoutState {
  const CheckoutAwaitingPayment(this.order);
  final RazorpayOrder order;
}

final class CheckoutVerifying extends CheckoutState {
  const CheckoutVerifying(this.planType);
  final String planType;
}

final class CheckoutActivated extends CheckoutState {
  const CheckoutActivated(this.planType);
  final String planType;
}

final class CheckoutPending extends CheckoutState {
  const CheckoutPending(this.message);
  final String message;
}

/// The user closed the Checkout sheet without paying
/// (`Razorpay.EVENT_PAYMENT_ERROR` with `PAYMENT_CANCELLED`, confirmed
/// against the plugin's own documented error codes) — distinct from
/// [CheckoutFailed] so the screen can show a quiet "no charge was made"
/// message instead of an alarming error.
final class CheckoutCancelled extends CheckoutState {
  const CheckoutCancelled();
}

final class CheckoutFailed extends CheckoutState {
  const CheckoutFailed(this.failure);
  final Failure failure;
}

/// Razorpay's own documented error code for a user-dismissed Checkout
/// sheet (`PAYMENT_CANCELLED` in the plugin's README) — the plugin exposes
/// error codes as plain `int`s, not an enum, so this is re-declared here
/// rather than imported from `package:razorpay_flutter` (kept out of every
/// layer above the one `RazorpayCheckoutLauncherImpl` file).
const int _razorpayPaymentCancelledCode = 2;

class SubscriptionCheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    final launcher = ref.watch(razorpayCheckoutLauncherProvider);
    ref.onDispose(launcher.dispose);
    return const CheckoutIdle();
  }

  /// Guards against a fast double-tap on the Upgrade button starting a
  /// second checkout attempt before the first has had a chance to disable
  /// it (the UI's own `isProcessing`-driven disable only takes effect on
  /// the *next* rebuild, which is not guaranteed to happen before a second,
  /// near-simultaneous tap is dispatched) — without this, two `createOrder`
  /// calls could race, and `_openCheckout` could be invoked twice. Mirrors
  /// `AriaChatController.sendMessage`'s own `state.sending` guard for the
  /// identical class of problem.
  bool get _checkoutInProgress => switch (state) {
    CheckoutCreatingOrder() || CheckoutAwaitingPayment() || CheckoutVerifying() => true,
    CheckoutIdle() || CheckoutActivated() || CheckoutPending() || CheckoutCancelled() || CheckoutFailed() => false,
  };

  Future<void> startCheckout(String planType) async {
    if (_checkoutInProgress) return;
    state = CheckoutCreatingOrder(planType);
    final orderResult = await ref.read(subscriptionRepositoryProvider).createOrder(planType);
    switch (orderResult) {
      case Failed(failure: final failure):
        state = CheckoutFailed(failure);
        return;
      case Success(value: final order):
        state = CheckoutAwaitingPayment(order);
        _openCheckout(order);
    }
  }

  void _openCheckout(RazorpayOrder order) {
    ref
        .read(razorpayCheckoutLauncherProvider)
        .openCheckout(
          options: {
            'key': order.keyId,
            'amount': order.amountPaise,
            'currency': order.currency,
            'name': 'Career Buddy',
            'description': order.planLabel,
            'order_id': order.orderId,
            'prefill': {'name': order.userName, 'email': order.userEmail},
            'theme': {'color': '#2563eb'},
          },
          onSuccess: (success) => _verify(order.planType, success),
          onError: _handleCheckoutError,
          onExternalWallet: (_) {
            // No separate handling needed: Razorpay still completes the
            // payment through its own flow for a selected external wallet
            // and fires EVENT_PAYMENT_SUCCESS/ERROR same as any other
            // method — matches the web, which also has no special-case
            // branch for this event beyond its own no-op listener.
          },
        );
  }

  Future<void> _verify(String planType, CheckoutSuccess success) async {
    state = CheckoutVerifying(planType);
    final result = await ref
        .read(subscriptionRepositoryProvider)
        .verifyPayment(
          planType: planType,
          razorpayPaymentId: success.paymentId,
          razorpayOrderId: success.orderId,
          razorpaySignature: success.signature,
        );
    switch (result) {
      case Failed(failure: final failure):
        state = CheckoutFailed(failure);
      case Success(value: final verification):
        state = switch (verification) {
          PaymentActivated(:final planType) => CheckoutActivated(planType),
          PaymentPending(:final message) => CheckoutPending(message),
        };
    }
  }

  void _handleCheckoutError(CheckoutFailure error) {
    if (error.code == _razorpayPaymentCancelledCode) {
      state = const CheckoutCancelled();
      return;
    }
    state = CheckoutFailed(UnexpectedFailure(error.message ?? 'Payment could not be completed. Please try again.'));
  }

  void reset() => state = const CheckoutIdle();
}
