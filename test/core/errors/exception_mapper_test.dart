import 'package:career_buddy_lms/core/errors/exception_mapper.dart';
import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExceptionMapper.map', () {
    test('maps each AppException subtype to its matching Failure', () {
      expect(ExceptionMapper.map(const NetworkUnavailableException()), isA<NetworkFailure>());
      expect(ExceptionMapper.map(const RequestTimeoutException()), isA<TimeoutFailure>());
      expect(ExceptionMapper.map(const UnauthorizedException()), isA<UnauthorizedFailure>());
      expect(ExceptionMapper.map(const ForbiddenException()), isA<ForbiddenFailure>());
      expect(ExceptionMapper.map(const NotFoundException()), isA<NotFoundFailure>());
      expect(ExceptionMapper.map(const RateLimitException()), isA<RateLimitFailure>());
      expect(ExceptionMapper.map(const ServerException(500)), isA<ServerFailure>());
      expect(ExceptionMapper.map(const UnexpectedResponseException()), isA<UnexpectedFailure>());
    });

    test('preserves the field errors and message on a ValidationException', () {
      const errors = {'form': ['Invalid credentials.']};
      final failure = ExceptionMapper.map(const ValidationException(errors, 'Invalid credentials.'));

      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fieldErrors, errors);
      expect(failure.message, 'Invalid credentials.');
    });

    test('maps an unrecognized error to UnexpectedFailure', () {
      expect(ExceptionMapper.map(Exception('boom')), isA<UnexpectedFailure>());
    });

    test(
      'REGRESSION (Phase 14): a RateLimitException\'s own server-provided message is no longer '
      'discarded in favor of a hardcoded one (e.g. the auth OTP endpoints\' real 429 body text)',
      () {
        final failure = ExceptionMapper.map(
          const RateLimitException('Too many verification requests. Please try again later.'),
        );

        expect(failure, isA<RateLimitFailure>());
        expect(failure.message, 'Too many verification requests. Please try again later.');
      },
    );

    test('a bare RateLimitException() (no custom message) still shows the same generic wording as before', () {
      final failure = ExceptionMapper.map(const RateLimitException());

      expect(failure.message, 'Too many attempts. Please wait a moment and try again.');
    });
  });
}
