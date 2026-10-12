import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/payment_verification_result.dart';
import '../../domain/entities/razorpay_order.dart';

/// `create_razorpay_order`/`verify_razorpay_payment` — see
/// `docs/PHASE_3_SUBSCRIPTION_DISCOVERY.md` §1. Both read
/// `request.POST.get(...)` server-side, so requests here are sent
/// **form-urlencoded**, not as a JSON body — the one detail that would
/// otherwise silently 400 every call with "Invalid plan." (an empty
/// `request.POST` server-side), same risk already called out in that
/// report.
class SubscriptionRemoteDataSource {
  SubscriptionRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<RazorpayOrder> createOrder(String planType) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final response = await _apiClient.dio.post(
        ApiEndpoints.createRazorpayOrder,
        data: 'plan_type=${Uri.encodeComponent(planType)}',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['success'] != true) {
        throw const UnexpectedResponseException();
      }
      return RazorpayOrder(
        orderId: data['order_id'] as String,
        amountPaise: data['amount'] as int,
        currency: data['currency'] as String,
        keyId: data['key_id'] as String,
        planType: data['plan_type'] as String,
        planLabel: data['plan_label'] as String,
        userName: data['user_name'] as String? ?? '',
        userEmail: data['user_email'] as String? ?? '',
      );
    } on DioException catch (e) {
      throw _mapOrderCreationError(e);
    } on TypeError {
      // A 200 whose body doesn't have the expected shape (e.g. a missing
      // required field) — same reasoning as every other datasource's
      // `UnexpectedResponseException` fallback for a malformed success body.
      throw const UnexpectedResponseException();
    }
  }

  Future<PaymentVerificationResult> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final csrfToken = await _apiClient.readCookie('csrftoken');
      final body = {
        'plan_type': planType,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_signature': razorpaySignature,
      };
      final response = await _apiClient.dio.post(
        ApiEndpoints.verifyRazorpayPayment,
        data: body.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&'),
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'X-CSRFToken': csrfToken ?? ''},
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const UnexpectedResponseException();

      // `verify_razorpay_payment` reports "payment captured but not yet
      // confirmed" as a 200 with `pending: true`, not an error status — Dio
      // never throws for this, so it has to be read off the body here,
      // same as the real web's own `handler` callback does
      // (`templates/pro.html:479-486`).
      if (data['success'] == true) {
        return PaymentActivated(data['plan_type'] as String? ?? planType);
      }
      if (data['pending'] == true) {
        return PaymentPending(data['error'] as String? ?? 'Your payment is being confirmed.');
      }
      // A genuine rejection (bad signature, replay, ownership/amount
      // mismatch, already on a higher plan) — these are always real 400s
      // server-side (confirmed in the discovery report), so this branch is
      // only reached if a future server change ever returns `success:
      // false` with neither `pending` nor an accompanying error status.
      throw ValidationException(const {}, data['error'] as String? ?? 'Payment verification failed.');
    } on DioException catch (e) {
      throw _mapVerificationError(e);
    } on TypeError {
      throw const UnexpectedResponseException();
    }
  }

  /// Reads the server's own `error` field for a 400 (invalid plan, downgrade
  /// blocked) so the real, actionable message reaches the user — every
  /// other status falls back to whatever `ApiExceptionsInterceptor` already
  /// mapped (429/500/502 all have reasonable generic equivalents; only the
  /// 400 cases carry business context worth preserving verbatim).
  AppException _mapOrderCreationError(DioException e) {
    if (e.response?.statusCode == 400) {
      final message = _extractErrorMessage(e.response?.data);
      if (message != null) return ValidationException(const {}, message);
    }
    return e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
  }

  /// Same reasoning as [_mapOrderCreationError] — 400 covers "missing
  /// payment details", "payment verification failed", "this payment has
  /// already been used", and the race-condition "already on a higher plan"
  /// case, all worth surfacing verbatim.
  AppException _mapVerificationError(DioException e) {
    if (e.response?.statusCode == 400) {
      final message = _extractErrorMessage(e.response?.data);
      if (message != null) return ValidationException(const {}, message);
    }
    return e.error is AppException ? e.error as AppException : const UnexpectedResponseException();
  }

  String? _extractErrorMessage(Object? body) {
    if (body is Map<String, dynamic> && body['error'] is String) {
      return body['error'] as String;
    }
    return null;
  }
}
