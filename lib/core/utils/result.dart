import '../errors/failures.dart';

/// A repository-layer outcome: either a value or a [Failure]. Keeps error
/// handling explicit at call sites instead of relying on try/catch spread
/// through the presentation layer.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failed<T> extends Result<T> {
  const Failed(this.failure);
  final Failure failure;
}
