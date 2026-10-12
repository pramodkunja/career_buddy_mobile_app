import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/payment_verification_result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/razorpay_order.dart';
import 'package:career_buddy_lms/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:career_buddy_lms/features/subscription/domain/services/razorpay_checkout_launcher.dart';
import 'package:career_buddy_lms/features/subscription/presentation/controllers/subscription_checkout_controller.dart';
import 'package:career_buddy_lms/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../subscription_test_doubles.dart';

const _order = RazorpayOrder(
  orderId: 'order_1',
  amountPaise: 58882,
  currency: 'INR',
  keyId: 'rzp_test',
  planType: 'normal',
  planLabel: 'Normal User Plan (1 Year)',
  userName: 'Jane',
  userEmail: 'jane@x.com',
);

class _FakeSubscriptionRepository implements SubscriptionRepository {
  Result<RazorpayOrder>? createOrderResult;
  Result<PaymentVerificationResult>? verifyResult;
  String? lastCreateOrderPlanType;
  int createOrderCallCount = 0;

  /// Lets a test hold `createOrder` in flight (simulating a real, slow
  /// network call) so it can fire a second `startCheckout` *while the first
  /// is still pending* — the only way to actually reproduce a double-tap
  /// race rather than just asserting on the (trivially sequential) default.
  Completer<void>? createOrderGate;

  @override
  Future<Result<RazorpayOrder>> createOrder(String planType) async {
    createOrderCallCount++;
    lastCreateOrderPlanType = planType;
    if (createOrderGate != null) await createOrderGate!.future;
    return createOrderResult ?? Success(_order);
  }

  @override
  Future<Result<PaymentVerificationResult>> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    return verifyResult ?? Success(const PaymentActivated('normal'));
  }
}

void main() {
  late FakeRazorpayCheckoutLauncher launcher;
  late _FakeSubscriptionRepository repository;
  late ProviderContainer container;

  setUp(() {
    launcher = FakeRazorpayCheckoutLauncher();
    repository = _FakeSubscriptionRepository();
    container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
        razorpayCheckoutLauncherProvider.overrideWithValue(launcher),
      ],
    );
    addTearDown(container.dispose);
  });

  group('SubscriptionCheckoutController', () {
    test('starts in CheckoutIdle', () {
      expect(container.read(subscriptionCheckoutControllerProvider), isA<CheckoutIdle>());
    });

    test(
      'a second startCheckout call while the first is still creating an order is ignored '
      '(the duplicate-tap case: a fast double-tap on Upgrade before the button has a chance to '
      'disable must not create two orders or open Checkout twice)',
      () async {
        repository.createOrderGate = Completer<void>();
        final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);

        final first = notifier.startCheckout('normal');
        final second = notifier.startCheckout('normal'); // fired before `first` awaits createOrder
        repository.createOrderGate!.complete();
        await first;
        await second;

        expect(repository.createOrderCallCount, 1, reason: 'createOrder must only be called once');
        expect(launcher.openCount, 1, reason: 'Checkout must only open once');
      },
    );

    test('startCheckout moves through CreatingOrder then AwaitingPayment, and opens Checkout with the real order fields', () async {
      final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);

      await notifier.startCheckout('normal');

      expect(container.read(subscriptionCheckoutControllerProvider), isA<CheckoutAwaitingPayment>());
      expect(repository.lastCreateOrderPlanType, 'normal');
      expect(launcher.openCount, 1);
      expect(launcher.lastOptions!['key'], 'rzp_test');
      expect(launcher.lastOptions!['amount'], 58882);
      expect(launcher.lastOptions!['order_id'], 'order_1');
      expect(launcher.lastOptions!['prefill'], {'name': 'Jane', 'email': 'jane@x.com'});
    });

    test('a failed order creation surfaces as CheckoutFailed and never opens Checkout', () async {
      repository.createOrderResult = const Failed(ValidationFailure({}, 'Invalid plan.'));
      final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);

      await notifier.startCheckout('normal');

      final state = container.read(subscriptionCheckoutControllerProvider);
      expect(state, isA<CheckoutFailed>());
      expect((state as CheckoutFailed).failure.message, 'Invalid plan.');
      expect(launcher.openCount, 0);
    });

    test('a successful Razorpay callback moves to Verifying then Activated on success:true', () async {
      repository.verifyResult = Success(const PaymentActivated('pro'));
      final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);
      await notifier.startCheckout('pro');

      launcher.simulateSuccess(const CheckoutSuccess(paymentId: 'pay_1', orderId: 'order_1', signature: 'sig_1'));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(subscriptionCheckoutControllerProvider);
      expect(state, isA<CheckoutActivated>());
      expect((state as CheckoutActivated).planType, 'pro');
    });

    test('a pending verification result surfaces as CheckoutPending, not an error', () async {
      repository.verifyResult = Success(const PaymentPending('Your payment is still being confirmed by the bank.'));
      final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);
      await notifier.startCheckout('normal');

      launcher.simulateSuccess(const CheckoutSuccess(paymentId: 'pay_1', orderId: 'order_1', signature: 'sig_1'));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(subscriptionCheckoutControllerProvider);
      expect(state, isA<CheckoutPending>());
      expect((state as CheckoutPending).message, 'Your payment is still being confirmed by the bank.');
    });

    test('a rejected verification (e.g. duplicate payment) surfaces as CheckoutFailed with the real server message', () async {
      repository.verifyResult = const Failed(ValidationFailure({}, 'This payment has already been used.'));
      final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);
      await notifier.startCheckout('normal');

      launcher.simulateSuccess(const CheckoutSuccess(paymentId: 'pay_1', orderId: 'order_1', signature: 'sig_1'));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(subscriptionCheckoutControllerProvider);
      expect(state, isA<CheckoutFailed>());
      expect((state as CheckoutFailed).failure.message, 'This payment has already been used.');
    });

    test('a user-dismissed Checkout sheet (PAYMENT_CANCELLED code) surfaces as CheckoutCancelled, never as an error', () async {
      final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);
      await notifier.startCheckout('normal');

      launcher.simulateError(const CheckoutFailure(code: kFakeRazorpayPaymentCancelledCode, message: 'Payment Cancelled'));

      expect(container.read(subscriptionCheckoutControllerProvider), isA<CheckoutCancelled>());
    });

    test('a genuine Checkout error (network/TLS/unknown) surfaces as CheckoutFailed with the plugin message', () async {
      final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);
      await notifier.startCheckout('normal');

      launcher.simulateError(const CheckoutFailure(code: 1, message: 'Network error'));

      final state = container.read(subscriptionCheckoutControllerProvider);
      expect(state, isA<CheckoutFailed>());
      expect((state as CheckoutFailed).failure.message, 'Network error');
    });

    test(
      'a duplicated Razorpay success callback (same payment delivered twice) calls verify again rather than '
      'silently dropping it — the server, not this client, is the replay guard '
      '(`RazorpayPayment`\'s unique constraint, confirmed in the discovery report)',
      () async {
        var verifyCallCount = 0;
        final countingRepo = _CountingVerifyRepository(repository, () => verifyCallCount++);
        container = ProviderContainer(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(countingRepo),
            razorpayCheckoutLauncherProvider.overrideWithValue(launcher),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);
        await notifier.startCheckout('normal');

        const success = CheckoutSuccess(paymentId: 'pay_1', orderId: 'order_1', signature: 'sig_1');
        launcher.simulateSuccess(success);
        await Future<void>.delayed(Duration.zero);
        launcher.simulateSuccess(success);
        await Future<void>.delayed(Duration.zero);

        expect(verifyCallCount, 2);
        // Second response wins in this client's state — matches "last
        // result shown" being a reasonable, honest outcome when the
        // (hypothetical) plugin itself misbehaves; the real protection
        // against this ever mattering is server-side idempotency, not
        // client-side suppression.
        expect(container.read(subscriptionCheckoutControllerProvider), isA<CheckoutActivated>());
      },
    );

    test('reset() returns to CheckoutIdle from any terminal state', () async {
      final notifier = container.read(subscriptionCheckoutControllerProvider.notifier);
      await notifier.startCheckout('normal');
      launcher.simulateError(const CheckoutFailure(code: kFakeRazorpayPaymentCancelledCode, message: 'Payment Cancelled'));
      expect(container.read(subscriptionCheckoutControllerProvider), isA<CheckoutCancelled>());

      notifier.reset();

      expect(container.read(subscriptionCheckoutControllerProvider), isA<CheckoutIdle>());
    });

    test('disposing the container clears the checkout launcher', () {
      container.read(subscriptionCheckoutControllerProvider);
      container.dispose();
      expect(launcher.disposed, isTrue);
    });
  });
}

class _CountingVerifyRepository implements SubscriptionRepository {
  _CountingVerifyRepository(this._inner, this._onVerifyCalled);
  final SubscriptionRepository _inner;
  final void Function() _onVerifyCalled;

  @override
  Future<Result<RazorpayOrder>> createOrder(String planType) => _inner.createOrder(planType);

  @override
  Future<Result<PaymentVerificationResult>> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    _onVerifyCalled();
    return _inner.verifyPayment(
      planType: planType,
      razorpayPaymentId: razorpayPaymentId,
      razorpayOrderId: razorpayOrderId,
      razorpaySignature: razorpaySignature,
    );
  }
}
