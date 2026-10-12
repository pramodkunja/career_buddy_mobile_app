import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/payment_verification_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_http_client_adapter.dart';

SubscriptionRemoteDataSource _buildDatasource({required int statusCode, required String body, void Function(RequestOptions)? onRequest}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..interceptors.add(ApiExceptionsInterceptor())
    ..httpClientAdapter = FakeHttpClientAdapter(
      statusCode: statusCode,
      body: body,
      // Dio's SyncTransformer only JSON-decodes a response whose own
      // content-type header says so (`isJsonMimeType`) — without this,
      // every body below comes back as a raw String, not a parsed Map.
      headers: {'content-type': ['application/json']},
      onRequest: onRequest,
    );
  return SubscriptionRemoteDataSource(ApiClient.forTesting(dio));
}

void main() {
  group('SubscriptionRemoteDataSource.createOrder', () {
    test('sends plan_type form-urlencoded (not JSON) with X-CSRFToken', () async {
      RequestOptions? captured;
      final datasource = _buildDatasource(
        statusCode: 200,
        body:
            '{"success": true, "order_id": "order_abc", "amount": 58882, '
            '"currency": "INR", "key_id": "rzp_test_1", "plan_type": "normal", '
            '"plan_label": "Normal User Plan (1 Year)", "user_name": "Jane", "user_email": "jane@x.com"}',
        onRequest: (o) => captured = o,
      );

      await datasource.createOrder('normal');

      expect(captured!.contentType, contains('application/x-www-form-urlencoded'));
      expect(captured!.data, 'plan_type=normal');
      expect(captured!.headers['X-CSRFToken'], isNotNull);
    });

    test('parses a successful order response into RazorpayOrder', () async {
      final datasource = _buildDatasource(
        statusCode: 200,
        body:
            '{"success": true, "order_id": "order_abc", "amount": 58882, '
            '"currency": "INR", "key_id": "rzp_test_1", "plan_type": "normal", '
            '"plan_label": "Normal User Plan (1 Year)", "user_name": "Jane", "user_email": "jane@x.com"}',
      );

      final order = await datasource.createOrder('normal');

      expect(order.orderId, 'order_abc');
      expect(order.amountPaise, 58882);
      expect(order.currency, 'INR');
      expect(order.keyId, 'rzp_test_1');
      expect(order.planType, 'normal');
      expect(order.planLabel, 'Normal User Plan (1 Year)');
      expect(order.userName, 'Jane');
      expect(order.userEmail, 'jane@x.com');
    });

    test('a 400 with a server error message preserves that exact message', () async {
      final datasource = _buildDatasource(
        statusCode: 400,
        body: '{"success": false, "error": "You are on the Pro Plan. Switching to a lower plan is not allowed while your subscription is active."}',
      );

      await expectLater(
        datasource.createOrder('normal'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'You are on the Pro Plan. Switching to a lower plan is not allowed while your subscription is active.',
          ),
        ),
      );
    });

    test('a 429 (rate limited) surfaces as RateLimitException', () async {
      final datasource = _buildDatasource(statusCode: 429, body: '{"success": false, "error": "Too many payment attempts."}');

      await expectLater(datasource.createOrder('normal'), throwsA(isA<RateLimitException>()));
    });

    test('a 500 (payment not configured) surfaces as ServerException', () async {
      final datasource = _buildDatasource(statusCode: 500, body: '{"success": false, "error": "Payment is not configured."}');

      await expectLater(datasource.createOrder('normal'), throwsA(isA<ServerException>()));
    });

    test('a 502 (Razorpay API failure) surfaces as ServerException', () async {
      final datasource = _buildDatasource(statusCode: 502, body: '{"success": false, "error": "Could not start payment. Please try again."}');

      await expectLater(datasource.createOrder('normal'), throwsA(isA<ServerException>()));
    });

    test('a malformed 200 body throws UnexpectedResponseException', () async {
      final datasource = _buildDatasource(statusCode: 200, body: '{"success": true}');

      await expectLater(datasource.createOrder('normal'), throwsA(isA<UnexpectedResponseException>()));
    });
  });

  group('SubscriptionRemoteDataSource.verifyPayment', () {
    test('sends every field form-urlencoded', () async {
      RequestOptions? captured;
      final datasource = _buildDatasource(
        statusCode: 200,
        body: '{"success": true, "plan_type": "normal"}',
        onRequest: (o) => captured = o,
      );

      await datasource.verifyPayment(
        planType: 'normal',
        razorpayPaymentId: 'pay_1',
        razorpayOrderId: 'order_1',
        razorpaySignature: 'sig_1',
      );

      expect(captured!.contentType, contains('application/x-www-form-urlencoded'));
      expect(captured!.data, 'plan_type=normal&razorpay_payment_id=pay_1&razorpay_order_id=order_1&razorpay_signature=sig_1');
    });

    test('success:true parses as PaymentActivated with the server-confirmed plan', () async {
      final datasource = _buildDatasource(statusCode: 200, body: '{"success": true, "plan_type": "pro"}');

      final result = await datasource.verifyPayment(
        planType: 'normal',
        razorpayPaymentId: 'pay_1',
        razorpayOrderId: 'order_1',
        razorpaySignature: 'sig_1',
      );

      expect(result, isA<PaymentActivated>());
      expect((result as PaymentActivated).planType, 'pro');
    });

    test('pending:true (HTTP 200) parses as PaymentPending, not a thrown error', () async {
      final datasource = _buildDatasource(
        statusCode: 200,
        body: '{"success": false, "pending": true, "error": "Your payment is still being confirmed by the bank."}',
      );

      final result = await datasource.verifyPayment(
        planType: 'normal',
        razorpayPaymentId: 'pay_1',
        razorpayOrderId: 'order_1',
        razorpaySignature: 'sig_1',
      );

      expect(result, isA<PaymentPending>());
      expect((result as PaymentPending).message, 'Your payment is still being confirmed by the bank.');
    });

    test('a 400 rejection (bad signature / replay / mismatch) preserves the exact server message', () async {
      final datasource = _buildDatasource(
        statusCode: 400,
        body: '{"success": false, "error": "This payment has already been used."}',
      );

      await expectLater(
        datasource.verifyPayment(
          planType: 'normal',
          razorpayPaymentId: 'pay_1',
          razorpayOrderId: 'order_1',
          razorpaySignature: 'sig_1',
        ),
        throwsA(isA<ValidationException>().having((e) => e.message, 'message', 'This payment has already been used.')),
      );
    });
  });
}
