import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/storage/secure_storage_service.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/data/create_resume_guest_draft_local_datasource.dart';
import 'package:career_buddy_lms/features/resume/data/create_resume_guest_draft_repository_impl.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/create_resume_state.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Simulates a genuine platform/keystore failure — distinct from "no draft
/// saved yet", which the datasource already represents as a plain `null`
/// return rather than an exception.
class _ThrowingSecureStorageService implements SecureStorageService {
  @override
  Future<String?> read(String key) async => throw Exception('keystore unavailable');

  @override
  Future<void> write(String key, String value) async => throw Exception('keystore unavailable');

  @override
  Future<void> delete(String key) async => throw Exception('keystore unavailable');

  @override
  Future<void> deleteAll() async => throw Exception('keystore unavailable');
}

void main() {
  group('happy path', () {
    late CreateResumeGuestDraftRepositoryImpl repository;

    setUp(() {
      repository = CreateResumeGuestDraftRepositoryImpl(
        CreateResumeGuestDraftLocalDataSource(_InMemorySecureStorageService()),
      );
    });

    test('loadDraft succeeds with null when nothing is saved', () async {
      final result = await repository.loadDraft();
      expect(result, isA<Success<CreateResumeFormState?>>());
      expect((result as Success<CreateResumeFormState?>).value, isNull);
    });

    test('saveDraft then loadDraft round-trips through the repository', () async {
      const form = CreateResumeFormState(
        personal: CreateResumePersonalInfo(name: 'Guest Candidate'),
      );
      final saveResult = await repository.saveDraft(form);
      expect(saveResult, isA<Success<void>>());

      final loadResult = await repository.loadDraft();
      expect(
        (loadResult as Success<CreateResumeFormState?>).value!.personal.name,
        'Guest Candidate',
      );
    });

    test('clearDraft succeeds', () async {
      await repository.saveDraft(
        const CreateResumeFormState(personal: CreateResumePersonalInfo(name: 'x')),
      );
      final result = await repository.clearDraft();
      expect(result, isA<Success<void>>());
      expect(
        (await repository.loadDraft() as Success<CreateResumeFormState?>).value,
        isNull,
      );
    });
  });

  group('storage failure', () {
    late CreateResumeGuestDraftRepositoryImpl repository;

    setUp(() {
      repository = CreateResumeGuestDraftRepositoryImpl(
        CreateResumeGuestDraftLocalDataSource(_ThrowingSecureStorageService()),
      );
    });

    test('loadDraft maps a genuine storage exception to Failed, not a crash', () async {
      final result = await repository.loadDraft();
      expect(result, isA<Failed<CreateResumeFormState?>>());
      expect((result as Failed<CreateResumeFormState?>).failure, isA<UnexpectedFailure>());
    });

    test('saveDraft maps a genuine storage exception to Failed, never a false success', () async {
      final result = await repository.saveDraft(const CreateResumeFormState());
      expect(result, isA<Failed<void>>());
    });

    test('clearDraft maps a genuine storage exception to Failed', () async {
      final result = await repository.clearDraft();
      expect(result, isA<Failed<void>>());
    });
  });
}
