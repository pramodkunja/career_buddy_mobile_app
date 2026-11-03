import 'dart:async';

import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/payment_verification_result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/razorpay_order.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/subscription_status.dart';
import 'package:career_buddy_lms/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:career_buddy_lms/features/subscription/domain/services/razorpay_checkout_launcher.dart';
import 'package:career_buddy_lms/features/subscription/presentation/controllers/invoice_download_controller.dart';
import 'package:career_buddy_lms/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:career_buddy_lms/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../subscription_test_doubles.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'jane');

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({
    this.createOrderResult,
    SubscriptionStatus? status,
    Result<SubscriptionStatus>? statusResult,
    this.downloadInvoiceResult,
  }) : _statusResult = statusResult ??
            Success(
              status ??
                  const SubscriptionStatus(
                    planType: 'free',
                    isActive: false,
                    payments: [],
                  ),
            );

  Result<RazorpayOrder>? createOrderResult;
  String? lastPlanType;
  int getStatusCallCount = 0;
  final Result<SubscriptionStatus> _statusResult;
  Result<List<int>>? downloadInvoiceResult;

  @override
  Future<Result<RazorpayOrder>> createOrder(String planType) async {
    lastPlanType = planType;
    return createOrderResult ??
        const Success(
          RazorpayOrder(
            orderId: 'order_1',
            amountPaise: 58882,
            currency: 'INR',
            keyId: 'rzp_test',
            planType: 'normal',
            planLabel: 'Normal User Plan (1 Year)',
            userName: 'Jane',
            userEmail: 'jane@x.com',
          ),
        );
  }

  @override
  Future<Result<PaymentVerificationResult>> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async => const Success(PaymentActivated('normal'));

  @override
  Future<Result<SubscriptionStatus>> getStatus() async {
    getStatusCallCount++;
    return _statusResult;
  }

  @override
  Future<Result<List<int>>> downloadInvoice(int paymentId) async =>
      downloadInvoiceResult ?? const Failed(NetworkFailure());
}

/// Repository whose `getStatus` stalls until [releaseStatus] is called.
/// Used to hold the screen in its loading state long enough to assert.
class _HeldStatusRepository implements SubscriptionRepository {
  final _gate = Completer<SubscriptionStatus>();

  void releaseStatus(SubscriptionStatus status) => _gate.complete(status);

  @override
  Future<Result<SubscriptionStatus>> getStatus() async {
    final s = await _gate.future;
    return Success(s);
  }

  @override
  Future<Result<RazorpayOrder>> createOrder(String planType) async => throw UnimplementedError();

  @override
  Future<Result<PaymentVerificationResult>> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async => throw UnimplementedError();

  @override
  Future<Result<List<int>>> downloadInvoice(int paymentId) async => throw UnimplementedError();
}

/// Repository whose `createOrder` stalls until [releaseOrder] is called.
/// Used to hold the screen in `CheckoutCreatingOrder` long enough to assert.
class _HeldOrderRepository implements SubscriptionRepository {
  final _gate = Completer<Result<RazorpayOrder>>();

  void releaseOrder(Result<RazorpayOrder> result) => _gate.complete(result);

  @override
  Future<Result<RazorpayOrder>> createOrder(String planType) => _gate.future;

  @override
  Future<Result<SubscriptionStatus>> getStatus() async =>
      const Success(SubscriptionStatus(planType: 'free', isActive: false, payments: []));

  @override
  Future<Result<PaymentVerificationResult>> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async => throw UnimplementedError();

  @override
  Future<Result<List<int>>> downloadInvoice(int paymentId) async => throw UnimplementedError();
}

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.pro,
  routes: [GoRoute(path: RoutePaths.pro, builder: (context, state) => const SubscriptionScreen())],
);

Future<(ProviderContainer, FakeRazorpayCheckoutLauncher, _FakeSubscriptionRepository)> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final launcher = FakeRazorpayCheckoutLauncher();
  final repository = _FakeSubscriptionRepository();
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      subscriptionRepositoryProvider.overrideWithValue(repository),
      razorpayCheckoutLauncherProvider.overrideWithValue(launcher),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
  );
  await tester.pump();
  await tester.pump();
  return (container, launcher, repository);
}

void main() {
  group('SubscriptionScreen', () {
    testWidgets('renders all three plan cards with their real, verified prices and a status card', (tester) async {
      await _pump(tester);

      expect(find.text('Free Plan'), findsOneWidget);
      expect(find.text('Normal User'), findsOneWidget);
      expect(find.text('Pro User'), findsOneWidget);
      expect(find.textContaining('₹499'), findsWidgets);
      expect(find.textContaining('₹999'), findsWidgets);
      // Status card shows the fetched plan state (Free in the fake).
      expect(find.textContaining('Free plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('status card does not use misleading ownership phrases', (tester) async {
      await _pump(tester);

      // The status card uses "Free plan — no active subscription." wording,
      // never "Your current plan" / "You are on" which imply the app is
      // guessing without a real API — Phase 81 provides a real API so we
      // show the actual plan, just with neutral, factual phrasing.
      expect(find.textContaining('Your current plan'), findsNothing);
      expect(find.textContaining('You are on'), findsNothing);
    });

    testWidgets('tapping Upgrade to Normal starts checkout for the normal plan and opens Razorpay with real order fields', (
      tester,
    ) async {
      final (_, launcher, repository) = await _pump(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Upgrade to Normal User — ₹499/yr'));
      await tester.pump();
      await tester.pump();

      expect(repository.lastPlanType, 'normal');
      expect(launcher.openCount, 1);
      expect(launcher.lastOptions!['order_id'], 'order_1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed order creation shows an error snackbar and leaves the screen usable', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final launcher = FakeRazorpayCheckoutLauncher();
      final repository = _FakeSubscriptionRepository(
        createOrderResult: const Failed(ValidationFailure({}, 'Invalid plan.')),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repository),
          razorpayCheckoutLauncherProvider.overrideWithValue(launcher),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Upgrade to Normal User — ₹499/yr'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Invalid plan.'), findsOneWidget);
      expect(launcher.openCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('SubscriptionScreen Phase 81 — status card and invoices', () {
    testWidgets('active paid plan shows plan label and expiry in the status card', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeSubscriptionRepository(
        status: SubscriptionStatus(
          planType: 'pro',
          isActive: true,
          expiryDate: DateTime(2027, 11, 2),
          daysLeft: 365,
          payments: const [],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Pro plan'), findsOneWidget);
      expect(find.textContaining('Active'), findsOneWidget);
      expect(find.textContaining('365 days left'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invoices section is hidden when there are no payments', (tester) async {
      await _pump(tester); // fake returns free plan + no payments
      expect(find.text('GST Invoices'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invoices section appears and shows download button when payments are present', (tester) async {
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeSubscriptionRepository(
        status: SubscriptionStatus(
          planType: 'pro',
          isActive: true,
          expiryDate: DateTime(2027, 11, 2),
          daysLeft: 365,
          payments: [
            InvoiceRecord(
              id: 42,
              invoiceNumber: 'CB/2026-27/00042',
              planType: 'pro',
              amountRupees: 1177.0,
              createdAt: DateTime(2026, 11, 2),
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('GST Invoices'), findsOneWidget);
      expect(find.text('CB/2026-27/00042'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('status card shows data after getStatus resolves and no exception is thrown', (tester) async {
      // Loading state is not assertable in widget tests because pumpWidget
      // flushes all microtasks (and the fake getStatus() resolves immediately
      // in a microtask) — so the AsyncLoading frame is never visible after
      // the first pump. The loading-→-data transition is verified in the unit
      // tests in subscription_status_controller_test.dart instead.
      await _pump(tester);
      expect(find.textContaining('Free plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SubscriptionScreen Phase 82 — UX hardening', () {
    // ── 82.1 Current plan badge ──────────────────────────────────────────

    testWidgets('Free Plan card shows "Current plan" badge for a free user', (tester) async {
      await _pump(tester); // default repo returns free, isActive=false

      expect(find.textContaining('Current plan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pro User card shows "Current plan" badge for an active pro user', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeSubscriptionRepository(
        status: SubscriptionStatus(
          planType: 'pro',
          isActive: true,
          expiryDate: DateTime(2027, 11, 2),
          daysLeft: 365,
          payments: const [],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      // Exactly one badge shown; it is on the Pro card (not "Recommended").
      expect(find.textContaining('Current plan'), findsOneWidget);
      expect(find.text('Recommended'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Normal User card shows "Current plan" badge for an active normal user', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeSubscriptionRepository(
        status: SubscriptionStatus(
          planType: 'normal',
          isActive: true,
          expiryDate: DateTime(2027, 6, 1),
          daysLeft: 200,
          payments: const [],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Current plan'), findsOneWidget);
      // Pro card still shows "Recommended" since it is not the current plan.
      expect(find.text('Recommended'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no "Current plan" badge is shown while subscription status is still loading', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final heldRepo = _HeldStatusRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(heldRepo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      // One pump only — getStatus is still in flight so state is AsyncLoading.

      expect(find.textContaining('Current plan'), findsNothing);
      expect(find.text('Recommended'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Release to prevent dangling futures.
      heldRepo.releaseStatus(const SubscriptionStatus(planType: 'free', isActive: false, payments: []));
    });

    // ── 82.1 Urgency styling ─────────────────────────────────────────────

    testWidgets('status card shows urgency text when fewer than 30 days remain', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeSubscriptionRepository(
        status: SubscriptionStatus(
          planType: 'pro',
          isActive: true,
          expiryDate: DateTime(2026, 11, 17),
          daysLeft: 15,
          payments: const [],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('15 days left'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ── 82.1 Loading and error states ────────────────────────────────────

    testWidgets('status card shows loading indicator while status fetch is in flight', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final heldRepo = _HeldStatusRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(heldRepo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      // Exactly one pump — getStatus has not yet completed.

      expect(find.text('Checking subscription status…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      heldRepo.releaseStatus(const SubscriptionStatus(planType: 'free', isActive: false, payments: []));
    });

    testWidgets('status card shows error message and Retry button when fetch fails', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeSubscriptionRepository(
        statusResult: const Failed(NetworkFailure()),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Could not load subscription status.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ── 82.2 Checkout progress banner ────────────────────────────────────

    testWidgets('checkout progress banner appears while order creation is in progress', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final heldOrderRepo = _HeldOrderRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(heldOrderRepo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Creating your order'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Upgrade to Normal User — ₹499/yr'));
      await tester.pump(); // state = CheckoutCreatingOrder → banner appears

      expect(find.textContaining('Creating your order'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Clean up.
      heldOrderRepo.releaseOrder(const Failed(ValidationFailure({}, 'test cleanup')));
      await tester.pump();
      await tester.pump();
    });

    // ── 82.2 Status refresh after activation ─────────────────────────────

    testWidgets('subscription status is refreshed after a successful checkout activation', (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final launcher = FakeRazorpayCheckoutLauncher();
      final repository = _FakeSubscriptionRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repository),
          razorpayCheckoutLauncherProvider.overrideWithValue(launcher),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      expect(repository.getStatusCallCount, 1);

      // Start checkout.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Upgrade to Normal User — ₹499/yr'));
      await tester.pump();
      await tester.pump();

      // Simulate a successful payment callback.
      launcher.simulateSuccess(const CheckoutSuccess(paymentId: 'pay_1', orderId: 'order_1', signature: 'sig_1'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        repository.getStatusCallCount,
        greaterThan(1),
        reason: 'status controller must be retried after CheckoutActivated',
      );
      expect(tester.takeException(), isNull);
    });

    // ── 82.3 Invoice UX ──────────────────────────────────────────────────

    testWidgets('invoice row shows refresh icon after a failed download', (tester) async {
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeSubscriptionRepository(
        downloadInvoiceResult: const Failed(NetworkFailure()),
        status: SubscriptionStatus(
          planType: 'pro',
          isActive: true,
          expiryDate: DateTime(2027, 11, 2),
          daysLeft: 365,
          payments: [
            InvoiceRecord(
              id: 42,
              invoiceNumber: 'CB/2026-27/00042',
              planType: 'pro',
              amountRupees: 1177.0,
              createdAt: DateTime(2026, 11, 2),
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      // Initially shows the download icon.
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);

      // Trigger the download directly via the controller rather than via tap:
      // the invoice row is deep in the scrollable content and the chatbot FAB
      // overlaps its position at this viewport height — both are valid reasons
      // to prefer a direct controller call. The widget still reacts to the
      // state change and must render the refresh icon.
      await container
          .read(invoiceDownloadControllerProvider(42).notifier)
          .downloadAndOpen('CB/2026-27/00042');
      await tester.pump();

      // After failure: refresh icon shown instead of download icon.
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invoice row falls back to #id label when invoice number is empty', (tester) async {
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeSubscriptionRepository(
        status: SubscriptionStatus(
          planType: 'pro',
          isActive: true,
          expiryDate: DateTime(2027, 11, 2),
          daysLeft: 365,
          payments: [
            InvoiceRecord(
              id: 77,
              invoiceNumber: '', // missing invoice number
              planType: 'pro',
              amountRupees: 1177.0,
              createdAt: DateTime(2026, 11, 2),
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          subscriptionRepositoryProvider.overrideWithValue(repo),
          razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('#77'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ── 82.5 Responsive / overflow ───────────────────────────────────────

    for (final width in [320.0, 360.0, 390.0, 414.0]) {
      testWidgets('no horizontal overflow at ${width.toInt()}dp — free plan', (tester) async {
        tester.view.physicalSize = Size(width, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final launcher = FakeRazorpayCheckoutLauncher();
        final repository = _FakeSubscriptionRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            subscriptionRepositoryProvider.overrideWithValue(repository),
            razorpayCheckoutLauncherProvider.overrideWithValue(launcher),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('no horizontal overflow at ${width.toInt()}dp — active pro plan with invoice', (tester) async {
        tester.view.physicalSize = Size(width, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final repo = _FakeSubscriptionRepository(
          status: SubscriptionStatus(
            planType: 'pro',
            isActive: true,
            expiryDate: DateTime(2026, 11, 17),
            daysLeft: 15, // urgent — exercises warning-colour path
            payments: [
              InvoiceRecord(
                id: 1,
                invoiceNumber: 'CB/2026-27/00001',
                planType: 'pro',
                amountRupees: 1177.0,
                createdAt: DateTime(2026, 11, 2),
              ),
            ],
          ),
        );
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            subscriptionRepositoryProvider.overrideWithValue(repo),
            razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
        );
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('no horizontal overflow at ${width.toInt()}dp — status loading state', (tester) async {
        tester.view.physicalSize = Size(width, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final heldRepo = _HeldStatusRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
            subscriptionRepositoryProvider.overrideWithValue(heldRepo),
            razorpayCheckoutLauncherProvider.overrideWithValue(FakeRazorpayCheckoutLauncher()),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: _router())),
        );
        // One pump only — loading state.
        expect(tester.takeException(), isNull);

        heldRepo.releaseStatus(const SubscriptionStatus(planType: 'free', isActive: false, payments: []));
      });
    }
  });
}
