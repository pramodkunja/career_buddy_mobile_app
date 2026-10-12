import 'package:career_buddy_lms/app/router/route_paths.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/auth/presentation/providers/auth_providers.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/payment_verification_result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/razorpay_order.dart';
import 'package:career_buddy_lms/features/subscription/domain/repositories/subscription_repository.dart';
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
  Future<Result<AuthUser>> register(dynamic data) async => throw UnimplementedError();
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({this.createOrderResult});

  Result<RazorpayOrder>? createOrderResult;
  String? lastPlanType;

  @override
  Future<Result<RazorpayOrder>> createOrder(String planType) async {
    lastPlanType = planType;
    return createOrderResult ??
        Success(
          const RazorpayOrder(
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
  }) async => Success(const PaymentActivated('normal'));
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
    testWidgets('renders all three plans with their real, verified prices and an unavailable-status banner', (tester) async {
      await _pump(tester);

      expect(find.text('Free Plan'), findsOneWidget);
      expect(find.text('Normal User'), findsOneWidget);
      expect(find.text('Pro User'), findsOneWidget);
      expect(find.textContaining('₹499'), findsWidgets);
      expect(find.textContaining('₹999'), findsWidgets);
      expect(find.textContaining("can't check your current plan"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not claim a Free plan or any current-plan status anywhere', (tester) async {
      await _pump(tester);

      // The one "Free Plan" text is the plan card's own label, never framed
      // as "your current plan" — no backend contract exists for that (see
      // docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md §2), so this screen must
      // never render anything implying it knows the viewer's actual plan.
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
}
