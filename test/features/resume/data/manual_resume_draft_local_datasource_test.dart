import 'package:career_buddy_lms/core/storage/secure_storage_service.dart';
import 'package:career_buddy_lms/features/resume/data/manual_resume_draft_local_datasource.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same fake used by `MockTestAttemptHistoryLocalDataSource`'s own test —
/// avoids the platform channel `flutter_secure_storage` needs.
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
  late ManualResumeDraftLocalDataSource dataSource;

  setUp(() {
    storage = _InMemorySecureStorageService();
    dataSource = ManualResumeDraftLocalDataSource(storage);
  });

  test('getDraft returns null when nothing has been saved yet', () async {
    expect(await dataSource.getDraft('alice'), isNull);
  });

  test('saveDraft persists a draft that getDraft then returns', () async {
    final draft = ManualResumeDraft.blank().copyWith(role: 'data-analyst', currentStep: 2);
    await dataSource.saveDraft('alice', draft);

    final restored = await dataSource.getDraft('alice');
    expect(restored, isNotNull);
    expect(restored!.role, 'data-analyst');
    expect(restored.currentStep, 2);
  });

  test('saveDraft overwrites whatever that account already had', () async {
    await dataSource.saveDraft('alice', ManualResumeDraft.blank().copyWith(role: 'first-role'));
    await dataSource.saveDraft('alice', ManualResumeDraft.blank().copyWith(role: 'second-role'));

    final restored = await dataSource.getDraft('alice');
    expect(restored!.role, 'second-role');
  });

  test('clearDraft removes the saved draft', () async {
    await dataSource.saveDraft('alice', ManualResumeDraft.blank().copyWith(role: 'some-role'));
    await dataSource.clearDraft('alice');

    expect(await dataSource.getDraft('alice'), isNull);
  });

  test('clearDraft on an account with no draft is a harmless no-op', () async {
    await dataSource.clearDraft('nobody-ever-saved');
    expect(await dataSource.getDraft('nobody-ever-saved'), isNull);
  });

  group('account isolation', () {
    test("one account's draft is never visible under a different account's key", () async {
      await dataSource.saveDraft('alice', ManualResumeDraft.blank().copyWith(role: 'alice-role'));

      expect(await dataSource.getDraft('bob'), isNull);
    });

    test("clearing one account's draft never touches another account's draft", () async {
      await dataSource.saveDraft('alice', ManualResumeDraft.blank().copyWith(role: 'alice-role'));
      await dataSource.saveDraft('bob', ManualResumeDraft.blank().copyWith(role: 'bob-role'));

      await dataSource.clearDraft('alice');

      expect(await dataSource.getDraft('alice'), isNull);
      expect((await dataSource.getDraft('bob'))!.role, 'bob-role');
    });
  });

  group('defensive reads', () {
    test('corrupt local data is treated as "no draft" rather than crashing', () async {
      await storage.write('manual_resume_draft.v1.alice', 'not valid json');
      expect(await dataSource.getDraft('alice'), isNull);
    });

    test('a different/missing schema version is treated as "no draft"', () async {
      await storage.write('manual_resume_draft.v1.alice', '{"schemaVersion":99,"draft":{"role":"x"}}');
      expect(await dataSource.getDraft('alice'), isNull);
    });

    test('a non-object JSON value is treated as "no draft"', () async {
      await storage.write('manual_resume_draft.v1.alice', '"just a string"');
      expect(await dataSource.getDraft('alice'), isNull);
    });
  });
}
