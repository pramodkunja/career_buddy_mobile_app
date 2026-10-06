/// User-facing failure types. Presentation code should switch on these to
/// render messages, never on raw exceptions or status codes.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure() : super('No internet connection. Check your network and try again.');
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure() : super('The request took too long. Please try again.');
}

final class ServerFailure extends Failure {
  const ServerFailure() : super('Something went wrong on our end. Please try again later.');
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('Your session has expired. Please sign in again.');
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = "You don't have permission to do that."]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(this.fieldErrors, [String message = 'Please check the highlighted fields.'])
    : super(message);
  final Map<String, List<String>> fieldErrors;
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure() : super("We couldn't find what you were looking for.");
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure() : super('Too many attempts. Please wait a moment and try again.');
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something unexpected happened. Please try again.']);
}

/// See `EmployerProfileIncompleteException`'s doc comment.
final class EmployerProfileIncompleteFailure extends Failure {
  const EmployerProfileIncompleteFailure(super.message);
}

/// See `CameraRequiredException`'s doc comment.
final class CameraRequiredFailure extends Failure {
  const CameraRequiredFailure(super.message);
}

/// See `MalpracticeTerminatedException`'s doc comment.
final class MalpracticeTerminatedFailure extends Failure {
  const MalpracticeTerminatedFailure(super.message);
}
