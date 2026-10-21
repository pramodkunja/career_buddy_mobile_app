import 'package:career_buddy_lms/core/storage/secure_storage_service.dart';
import 'package:career_buddy_lms/features/resume/data/create_resume_guest_draft_local_datasource.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same fake used by `manual_resume_draft_local_datasource_test.dart` —
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
  late CreateResumeGuestDraftLocalDataSource dataSource;

  setUp(() {
    storage = _InMemorySecureStorageService();
    dataSource = CreateResumeGuestDraftLocalDataSource(storage);
  });

  test('getDraft returns null when nothing has been saved yet', () async {
    expect(await dataSource.getDraft(), isNull);
  });

  test('saveDraft persists a draft that getDraft then returns', () async {
    const form = CreateResumeFormState(
      personal: CreateResumePersonalInfo(name: 'Guest Candidate'),
      summary: 'A short professional summary.',
    );
    await dataSource.saveDraft(form);

    final restored = await dataSource.getDraft();
    expect(restored, isNotNull);
    expect(restored!.personal.name, 'Guest Candidate');
    expect(restored.summary, 'A short professional summary.');
  });

  test('getDraft never returns a draftId — a guest draft has no server id', () async {
    // draftId is not part of toRequestJson()'s output at all, so even a
    // form that once had one (e.g. restored from a server draft before
    // signing out) cannot leak one back out of local storage.
    const form = CreateResumeFormState(
      draftId: 7,
      personal: CreateResumePersonalInfo(name: 'Guest Candidate'),
    );
    await dataSource.saveDraft(form);

    expect((await dataSource.getDraft())!.draftId, isNull);
  });

  test('saveDraft overwrites whatever guest draft this device already had', () async {
    await dataSource.saveDraft(
      const CreateResumeFormState(personal: CreateResumePersonalInfo(name: 'First Draft')),
    );
    await dataSource.saveDraft(
      const CreateResumeFormState(personal: CreateResumePersonalInfo(name: 'Second Draft')),
    );

    final restored = await dataSource.getDraft();
    expect(restored!.personal.name, 'Second Draft');
  });

  test('clearDraft removes the saved draft', () async {
    await dataSource.saveDraft(
      const CreateResumeFormState(personal: CreateResumePersonalInfo(name: 'Someone')),
    );
    await dataSource.clearDraft();

    expect(await dataSource.getDraft(), isNull);
  });

  test('clearDraft with no saved draft is a harmless no-op', () async {
    await dataSource.clearDraft();
    expect(await dataSource.getDraft(), isNull);
  });

  group('defensive reads', () {
    test('corrupt local data is treated as "no draft" rather than crashing', () async {
      await storage.write('create_resume_guest_draft.v1', 'not valid json');
      expect(await dataSource.getDraft(), isNull);
    });

    test('a different/missing schema version is treated as "no draft"', () async {
      await storage.write(
        'create_resume_guest_draft.v1',
        '{"schemaVersion":99,"draft":{"personal":{"name":"x"}}}',
      );
      expect(await dataSource.getDraft(), isNull);
    });

    test('a non-object JSON value is treated as "no draft"', () async {
      await storage.write('create_resume_guest_draft.v1', '"just a string"');
      expect(await dataSource.getDraft(), isNull);
    });
  });
}
