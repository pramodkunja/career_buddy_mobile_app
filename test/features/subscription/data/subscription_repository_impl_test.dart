import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:career_buddy_lms/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/payment_verification_result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/razorpay_order.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/subscription_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubscriptionRepositoryImpl', () {
    test('createOrder wraps a datasource success in Success', () async {
      const order = RazorpayOrder(
        orderId: 'order_1',
        amountPaise: 58882,
        currency: 'INR',
        keyId: 'rzp_test',
        planType: 'normal',
        planLabel: 'Normal User Plan (1 Year)',
        userName: 'Jane',
        userEmail: 'jane@x.com',
      );
      final repo = SubscriptionRepositoryImpl(_FakeDataSource(createOrderResult: order));

      final result = await repo.createOrder('normal');

      expect(result, isA<Success<RazorpayOrder>>());
      expect((result as Success<RazorpayOrder>).value.orderId, 'order_1');
    });

    test('createOrder maps a thrown AppException to a Failed Result', () async {
      final repo = SubscriptionRepositoryImpl(
        _FakeDataSource(createOrderError: const ValidationException({}, 'Invalid plan.')),
      );

      final result = await repo.createOrder('bogus');

      expect(result, isA<Failed<RazorpayOrder>>());
      expect((result as Failed<RazorpayOrder>).failure.message, 'Invalid plan.');
    });

    test('verifyPayment wraps a datasource success in Success', () async {
      final repo = SubscriptionRepositoryImpl(
        _FakeDataSource(verifyResult: const PaymentActivated('pro')),
      );

      final result = await repo.verifyPayment(
        planType: 'normal',
        razorpayPaymentId: 'pay_1',
        razorpayOrderId: 'order_1',
        razorpaySignature: 'sig_1',
      );

      expect(result, isA<Success<PaymentVerificationResult>>());
      expect((result as Success<PaymentVerificationResult>).value, isA<PaymentActivated>());
    });

    test('verifyPayment maps a thrown AppException to a Failed Result', () async {
      final repo = SubscriptionRepositoryImpl(
        _FakeDataSource(verifyError: const ValidationException({}, 'This payment has already been used.')),
      );

      final result = await repo.verifyPayment(
        planType: 'normal',
        razorpayPaymentId: 'pay_1',
        razorpayOrderId: 'order_1',
        razorpaySignature: 'sig_1',
      );

      expect(result, isA<Failed<PaymentVerificationResult>>());
      expect(
        (result as Failed<PaymentVerificationResult>).failure.message,
        'This payment has already been used.',
      );
    });

    test('getStatus wraps a datasource success in Success', () async {
      const status = SubscriptionStatus(planType: 'free', isActive: false, payments: []);
      final repo = SubscriptionRepositoryImpl(_FakeDataSource(statusResult: status));

      final result = await repo.getStatus();

      expect(result, isA<Success<SubscriptionStatus>>());
      expect((result as Success<SubscriptionStatus>).value.planType, 'free');
    });

    test('getStatus maps a thrown AppException to a Failed Result', () async {
      final repo = SubscriptionRepositoryImpl(
        _FakeDataSource(statusError: const UnauthorizedException()),
      );

      final result = await repo.getStatus();

      expect(result, isA<Failed<SubscriptionStatus>>());
    });

    test('downloadInvoice wraps datasource bytes in Success', () async {
      final bytes = '<html>invoice</html>'.codeUnits;
      final repo = SubscriptionRepositoryImpl(_FakeDataSource(downloadResult: bytes));

      final result = await repo.downloadInvoice(42);

      expect(result, isA<Success<List<int>>>());
      expect(String.fromCharCodes((result as Success<List<int>>).value), '<html>invoice</html>');
    });

    test('downloadInvoice maps a thrown AppException to a Failed Result', () async {
      final repo = SubscriptionRepositoryImpl(
        _FakeDataSource(downloadError: const NotFoundException()),
      );

      final result = await repo.downloadInvoice(99);

      expect(result, isA<Failed<List<int>>>());
    });
  });
}

class _FakeDataSource implements SubscriptionRemoteDataSource {
  _FakeDataSource({
    this.createOrderResult,
    this.createOrderError,
    this.verifyResult,
    this.verifyError,
    this.statusResult,
    this.statusError,
    this.downloadResult,
    this.downloadError,
  });

  final RazorpayOrder? createOrderResult;
  final AppException? createOrderError;
  final PaymentVerificationResult? verifyResult;
  final AppException? verifyError;
  final SubscriptionStatus? statusResult;
  final AppException? statusError;
  final List<int>? downloadResult;
  final AppException? downloadError;

  @override
  Future<RazorpayOrder> createOrder(String planType) async {
    if (createOrderError != null) throw createOrderError!;
    return createOrderResult!;
  }

  @override
  Future<PaymentVerificationResult> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    if (verifyError != null) throw verifyError!;
    return verifyResult!;
  }

  @override
  Future<SubscriptionStatus> getStatus() async {
    if (statusError != null) throw statusError!;
    return statusResult!;
  }

  @override
  Future<List<int>> downloadInvoiceBytes(int pk) async {
    if (downloadError != null) throw downloadError!;
    return downloadResult!;
  }
}
