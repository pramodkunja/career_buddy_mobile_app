import 'exceptions.dart';
import 'failures.dart';

/// Converts a caught exception (an [AppException] or anything else a data
/// source might throw) into a [Failure] safe to show to the user.
abstract final class ExceptionMapper {
  static Failure map(Object error) {
    if (error is AppException) {
      return switch (error) {
        NetworkUnavailableException() => const NetworkFailure(),
        RequestTimeoutException() => const TimeoutFailure(),
        UnauthorizedException() => const UnauthorizedFailure(),
        ForbiddenException(message: final msg) => ForbiddenFailure(msg),
        NotFoundException() => const NotFoundFailure(),
        RateLimitException() => const RateLimitFailure(),
        ValidationException(fieldErrors: final errors, message: final msg) => ValidationFailure(errors, msg),
        ServerException() => const ServerFailure(),
        UnexpectedResponseException() => const UnexpectedFailure(),
        EmployerProfileIncompleteException(message: final msg) => EmployerProfileIncompleteFailure(msg),
        CameraRequiredException(message: final msg) => CameraRequiredFailure(msg),
        MalpracticeTerminatedException(message: final msg) => MalpracticeTerminatedFailure(msg),
      };
    }
    return const UnexpectedFailure();
  }
}
