import 'package:career_buddy_lms/core/demo/demo_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(DemoProgressStore.instance.reset);

  test('lastAttemptFor returns null before any attempt is recorded', () {
    expect(DemoProgressStore.instance.lastAttemptFor(1), isNull);
  });

  test('recordAttempt stores a matching ExerciseAttempt with attemptNumber 1 on the first call', () {
    DemoProgressStore.instance.recordAttempt(9201, score: 18, maxScore: 25);

    final attempt = DemoProgressStore.instance.lastAttemptFor(9201);
    expect(attempt, isNotNull);
    expect(attempt!.score, 18);
    expect(attempt.maxScore, 25);
    expect(attempt.percentage, 72);
    expect(attempt.attemptNumber, 1);
  });

  test('recordAttempt increments attemptNumber on subsequent calls for the same exercise', () {
    DemoProgressStore.instance.recordAttempt(9201, score: 10, maxScore: 25);
    DemoProgressStore.instance.recordAttempt(9201, score: 20, maxScore: 25);

    final attempt = DemoProgressStore.instance.lastAttemptFor(9201);
    expect(attempt!.attemptNumber, 2);
    expect(attempt.score, 20);
  });

  test('recordAttempt tracks attempts per exercise id independently', () {
    DemoProgressStore.instance.recordAttempt(9201, score: 15, maxScore: 25);
    DemoProgressStore.instance.recordAttempt(9202, score: 22, maxScore: 25);

    expect(DemoProgressStore.instance.lastAttemptFor(9201)!.score, 15);
    expect(DemoProgressStore.instance.lastAttemptFor(9202)!.score, 22);
  });

  test('sub-activity started/complete tracking', () {
    expect(DemoProgressStore.instance.isSubActivityStarted(9101), isFalse);
    expect(DemoProgressStore.instance.isSubActivityComplete(9101), isFalse);

    DemoProgressStore.instance.markSubActivityStarted(9101);
    expect(DemoProgressStore.instance.isSubActivityStarted(9101), isTrue);
    expect(DemoProgressStore.instance.isSubActivityComplete(9101), isFalse);

    DemoProgressStore.instance.markSubActivityComplete(9101);
    expect(DemoProgressStore.instance.isSubActivityStarted(9101), isTrue);
    expect(DemoProgressStore.instance.isSubActivityComplete(9101), isTrue);
  });

  test('reset() clears all accumulated progress', () {
    DemoProgressStore.instance.recordAttempt(9201, score: 18, maxScore: 25);
    DemoProgressStore.instance.markSubActivityComplete(9101);

    DemoProgressStore.instance.reset();

    expect(DemoProgressStore.instance.lastAttemptFor(9201), isNull);
    expect(DemoProgressStore.instance.isSubActivityStarted(9101), isFalse);
    expect(DemoProgressStore.instance.isSubActivityComplete(9101), isFalse);
  });
}
