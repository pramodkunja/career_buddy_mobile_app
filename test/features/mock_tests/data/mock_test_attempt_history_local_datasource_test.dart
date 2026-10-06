import 'package:career_buddy_lms/core/storage/secure_storage_service.dart';
import 'package:career_buddy_lms/features/mock_tests/data/datasources/mock_test_attempt_history_local_datasource.dart';
import 'package:career_buddy_lms/features/mock_tests/domain/entities/mock_test_attempt_record.dart';
import 'package:flutter_test/flutter_test.dart';

/// An in-memory stand-in for [SecureStorageService], avoiding the platform
/// channel `flutter_secure_storage` needs (no device/emulator in a plain
/// `flutter test` run). Same map-backed read/write/delete contract, so it's
/// interchangeable with the real service for this datasource's purposes.
class _InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}

void main() {
  late _InMemorySecureStorageService storage;
  late MockTestAttemptHistoryLocalDataSource dataSource;

  setUp(() {
    storage = _InMemorySecureStorageService();
    dataSource = MockTestAttemptHistoryLocalDataSource(storage, storageKey: 'mock_test_attempts_oop');
  });

  test('getAttempts returns an empty list when nothing has been recorded yet', () async {
    expect(await dataSource.getAttempts(), isEmpty);
  });

  test('recordAttempt persists an attempt that getAttempts then returns', () async {
    final attempt = MockTestAttemptRecord(score: 40, total: 50, completedAt: DateTime(2026, 9, 20, 10));
    await dataSource.recordAttempt(attempt);

    final attempts = await dataSource.getAttempts();
    expect(attempts, hasLength(1));
    expect(attempts.single.score, 40);
    expect(attempts.single.total, 50);
    expect(attempts.single.percentage, 80);
  });

  test("newest attempt is prepended, matching the web scoreboard's newest-first order", () async {
    await dataSource.recordAttempt(MockTestAttemptRecord(score: 10, total: 50, completedAt: DateTime(2026, 9, 1)));
    await dataSource.recordAttempt(MockTestAttemptRecord(score: 45, total: 50, completedAt: DateTime(2026, 9, 20)));

    final attempts = await dataSource.getAttempts();
    expect(attempts.first.score, 45);
    expect(attempts.last.score, 10);
  });

  test("caps stored attempts at 50, matching the web's `.slice(0,50)`", () async {
    for (var i = 0; i < 55; i++) {
      await dataSource.recordAttempt(MockTestAttemptRecord(score: i, total: 50, completedAt: DateTime(2026, 1, 1)));
    }
    final attempts = await dataSource.getAttempts();
    expect(attempts, hasLength(50));
    expect(attempts.first.score, 54); // most recent write kept
  });

  test('corrupt local data is treated as empty rather than crashing', () async {
    await storage.write('mock_test_attempts_oop', 'not valid json');
    expect(await dataSource.getAttempts(), isEmpty);
  });

  test('an entry with a wrong field type is skipped, not thrown', () async {
    await storage.write('mock_test_attempts_oop', '[{"score":"not-a-number","total":50,"completedAt":"2026-09-20T00:00:00.000"}]');
    expect(await dataSource.getAttempts(), isEmpty);
  });
}
