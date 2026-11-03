import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/payment_verification_result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/razorpay_order.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/subscription_status.dart';
import 'package:career_buddy_lms/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:career_buddy_lms/features/subscription/presentation/controllers/subscription_status_controller.dart';
import 'package:career_buddy_lms/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _freeStatus = SubscriptionStatus(planType: 'free', isActive: false, payments: []);

final _proStatus = SubscriptionStatus(
  planType: 'pro',
  isActive: true,
  expiryDate: DateTime(2027, 11, 2),
  daysLeft: 365,
  payments: const [],
);

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({required this.statusResult});

  Result<SubscriptionStatus> statusResult;
  int getStatusCallCount = 0;

  @override
  Future<Result<SubscriptionStatus>> getStatus() async {
    getStatusCallCount++;
    return statusResult;
  }

  @override
  Future<Result<List<int>>> downloadInvoice(int paymentId) async =>
      throw UnimplementedError();

  @override
  Future<Result<RazorpayOrder>> createOrder(String planType) async =>
      throw UnimplementedError();

  @override
  Future<Result<PaymentVerificationResult>> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async => throw UnimplementedError();
}

ProviderContainer _buildContainer(_FakeSubscriptionRepository repo) {
  final container = ProviderContainer(
    overrides: [subscriptionRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('SubscriptionStatusController', () {
    test('starts loading then resolves to data on success', () async {
      final repo = _FakeSubscriptionRepository(statusResult: Success(_freeStatus));
      final container = _buildContainer(repo);

      expect(container.read(subscriptionStatusControllerProvider), isA<AsyncLoading>());
      final data = await container.read(subscriptionStatusControllerProvider.future);
      expect(data.planType, 'free');
      expect(container.read(subscriptionStatusControllerProvider), isA<AsyncData<SubscriptionStatus>>());
    });

    test('resolves to AsyncError carrying the Failure on network failure', () async {
      final repo = _FakeSubscriptionRepository(
        statusResult: const Failed(NotFoundFailure()),
      );
      final container = _buildContainer(repo);

      try {
        await container.read(subscriptionStatusControllerProvider.future);
      } catch (_) {}
      expect(container.read(subscriptionStatusControllerProvider), isA<AsyncError>());
    });

    test('retry re-fetches and resolves to new data', () async {
      final repo = _FakeSubscriptionRepository(statusResult: Success(_freeStatus));
      final container = _buildContainer(repo);
      await container.read(subscriptionStatusControllerProvider.future);
      expect(repo.getStatusCallCount, 1);

      repo.statusResult = Success(_proStatus);
      await container.read(subscriptionStatusControllerProvider.notifier).retry();
      expect(repo.getStatusCallCount, 2);
      final data = container.read(subscriptionStatusControllerProvider).value!;
      expect(data.planType, 'pro');
      expect(data.isActive, true);
    });

    test('payments list is correctly propagated', () async {
      final status = SubscriptionStatus(
        planType: 'normal',
        isActive: true,
        expiryDate: DateTime(2027, 5, 1),
        daysLeft: 180,
        payments: [
          InvoiceRecord(
            id: 7,
            invoiceNumber: 'CB/2026-27/00007',
            planType: 'normal',
            amountRupees: 588.82,
            createdAt: DateTime(2026, 11, 2),
          ),
        ],
      );
      final repo = _FakeSubscriptionRepository(statusResult: Success(status));
      final container = _buildContainer(repo);
      final data = await container.read(subscriptionStatusControllerProvider.future);
      expect(data.payments, hasLength(1));
      expect(data.payments.single.id, 7);
      expect(data.payments.single.invoiceNumber, 'CB/2026-27/00007');
    });

    test('getStatus is called exactly once during initial build', () async {
      final repo = _FakeSubscriptionRepository(statusResult: Success(_freeStatus));
      final container = _buildContainer(repo);

      await container.read(subscriptionStatusControllerProvider.future);

      expect(repo.getStatusCallCount, 1);
    });

    test('adding a second listener does not trigger a re-fetch', () async {
      final repo = _FakeSubscriptionRepository(statusResult: Success(_freeStatus));
      final container = _buildContainer(repo);

      await container.read(subscriptionStatusControllerProvider.future);
      expect(repo.getStatusCallCount, 1);

      // Simulate a second consumer watching the same provider (e.g. re-enter
      // the screen without leaving the Riverpod scope).
      container.read(subscriptionStatusControllerProvider);
      await Future<void>.delayed(Duration.zero);

      expect(repo.getStatusCallCount, 1, reason: 'cached result must not trigger a re-fetch');
    });

    test('retry after success re-fetches and returns updated data', () async {
      final repo = _FakeSubscriptionRepository(statusResult: Success(_freeStatus));
      final container = _buildContainer(repo);
      await container.read(subscriptionStatusControllerProvider.future);

      repo.statusResult = Success(_proStatus);
      await container.read(subscriptionStatusControllerProvider.notifier).retry();

      final data = container.read(subscriptionStatusControllerProvider).value!;
      expect(data.planType, 'pro');
      expect(data.isActive, true);
      expect(repo.getStatusCallCount, 2);
    });

    test('retry after error re-fetches and can recover to data', () async {
      final repo = _FakeSubscriptionRepository(
        statusResult: const Failed(NotFoundFailure()),
      );
      final container = _buildContainer(repo);
      try {
        await container.read(subscriptionStatusControllerProvider.future);
      } catch (_) {}
      expect(container.read(subscriptionStatusControllerProvider), isA<AsyncError>());

      repo.statusResult = Success(_freeStatus);
      await container.read(subscriptionStatusControllerProvider.notifier).retry();

      expect(container.read(subscriptionStatusControllerProvider), isA<AsyncData<SubscriptionStatus>>());
      expect(container.read(subscriptionStatusControllerProvider).value!.planType, 'free');
    });
  });

  group('SubscriptionStatus.fromJson', () {
    test('parses free plan correctly', () {
      final json = {
        'plan_type': 'free',
        'is_active': false,
        'expiry_date': null,
        'days_left': null,
        'payments': <dynamic>[],
      };
      final status = SubscriptionStatus.fromJson(json);
      expect(status.planType, 'free');
      expect(status.isActive, false);
      expect(status.expiryDate, isNull);
      expect(status.daysLeft, isNull);
      expect(status.payments, isEmpty);
    });

    test('parses active pro plan with one payment correctly', () {
      final json = {
        'plan_type': 'pro',
        'is_active': true,
        'expiry_date': '2027-11-02T10:30:00+05:30',
        'days_left': 365,
        'payments': [
          {
            'id': 42,
            'invoice_number': 'CB/2026-27/00042',
            'plan_type': 'pro',
            'amount_paise': 117700,
            'created_at': '2026-11-02T10:30:00+05:30',
          },
        ],
      };
      final status = SubscriptionStatus.fromJson(json);
      expect(status.planType, 'pro');
      expect(status.isActive, true);
      expect(status.expiryDate, isNotNull);
      expect(status.daysLeft, 365);
      expect(status.payments, hasLength(1));
      expect(status.payments.single.id, 42);
      expect(status.payments.single.invoiceNumber, 'CB/2026-27/00042');
      expect(status.payments.single.amountRupees, 1177.0);
    });
  });
}
