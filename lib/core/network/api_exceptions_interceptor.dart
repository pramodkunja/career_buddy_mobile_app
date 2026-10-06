import 'package:dio/dio.dart';

import '../errors/exceptions.dart';

/// Converts every [DioException] into an [AppException] and attaches it as
/// `error`, so data sources never have to interpret Dio/HTTP details
/// directly — they just check `e.error`.
class ApiExceptionsInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: _toAppException(err),
      ),
    );
  }

  AppException _toAppException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkUnavailableException();
      case DioExceptionType.badResponse:
        return _fromStatusCode(err.response?.statusCode);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return const UnexpectedResponseException();
    }
  }

  AppException _fromStatusCode(int? statusCode) {
    switch (statusCode) {
      case 401:
        return const UnauthorizedException();
      case 403:
        return const ForbiddenException();
      case 404:
        return const NotFoundException();
      case 429:
        return const RateLimitException();
      default:
        if (statusCode != null && statusCode >= 500) {
          return ServerException(statusCode);
        }
        return const UnexpectedResponseException();
    }
  }
}
