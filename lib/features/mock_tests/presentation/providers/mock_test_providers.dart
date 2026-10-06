import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/mock_quiz_remote_datasource.dart';
import '../../data/datasources/mock_test_attempt_history_local_datasource.dart';
import '../../data/repositories/mock_quiz_repository_impl.dart';
import '../../domain/repositories/mock_quiz_repository.dart';

/// Wired to the OOP Mastery endpoint pair specifically — its own dedicated
/// `/activities/oop-quiz/...` pair, not one of the 24 generic subjects (see
/// [subjectQuizRepositoryProvider] below for W021).
final oopMockQuizRemoteDataSourceProvider = Provider<MockQuizRemoteDataSource>((ref) {
  return MockQuizRemoteDataSource(
    ref.watch(apiClientProvider),
    questionsPath: ApiEndpoints.oopQuizQuestions,
    submitPath: ApiEndpoints.oopQuizSubmit,
  );
});

final oopMockQuizRepositoryProvider = Provider<MockQuizRepository>((ref) {
  return MockQuizRepositoryImpl(ref.watch(oopMockQuizRemoteDataSourceProvider));
});

/// Storage key namespaced per quiz, mirroring the web's own per-subject
/// `LS_KEY` convention (`oopScores` for OOP Mastery, `dsaScores` for DSA,
/// etc. — confirmed identical pattern across every subject page for W021).
final oopMockTestAttemptHistoryProvider = Provider<MockTestAttemptHistoryLocalDataSource>((ref) {
  return MockTestAttemptHistoryLocalDataSource(ref.watch(secureStorageProvider), storageKey: 'mock_test_attempts_oop');
});

/// W021 — the generic subject quiz family, keyed by subject slug (one of
/// `_QUIZ_SUBJECTS` minus `'oop'`, `activities/views.py:2201-2206`).
/// Constructs the exact same [MockQuizRemoteDataSource]/[MockQuizRepositoryImpl]
/// classes W020 uses, just pointed at `/activities/quiz/<subject>/...`
/// instead — verified byte-for-byte identical server logic to the OOP
/// endpoints (`activities/views.py:2217-2264`), so no new data-layer class
/// was needed, only this additional provider wiring.
final subjectQuizRemoteDataSourceProvider = Provider.family<MockQuizRemoteDataSource, String>((ref, subject) {
  return MockQuizRemoteDataSource(
    ref.watch(apiClientProvider),
    questionsPath: ApiEndpoints.quizQuestions(subject),
    submitPath: ApiEndpoints.quizSubmit(subject),
  );
});

final subjectQuizRepositoryProvider = Provider.family<MockQuizRepository, String>((ref, subject) {
  return MockQuizRepositoryImpl(ref.watch(subjectQuizRemoteDataSourceProvider(subject)));
});

final subjectQuizAttemptHistoryProvider = Provider.family<MockTestAttemptHistoryLocalDataSource, String>((ref, subject) {
  return MockTestAttemptHistoryLocalDataSource(
    ref.watch(secureStorageProvider),
    storageKey: 'mock_test_attempts_$subject',
  );
});
