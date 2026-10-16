import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/storage/secure_storage_service.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/resume/data/manual_resume_draft_local_datasource.dart';
import 'package:career_buddy_lms/features/resume/data/manual_resume_draft_repository_impl.dart';
import 'package:career_buddy_lms/features/resume/domain/entities/manual_resume_draft.dart';
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
    late ManualResumeDraftRepositoryImpl repository;

    setUp(() {
      repository = ManualResumeDraftRepositoryImpl(ManualResumeDraftLocalDataSource(_InMemorySecureStorageService()));
    });

    test('loadDraft succeeds with null when nothing is saved', () async {
      final result = await repository.loadDraft('alice');
      expect(result, isA<Success<ManualResumeDraft?>>());
      expect((result as Success<ManualResumeDraft?>).value, isNull);
    });

    test('saveDraft then loadDraft round-trips through the repository', () async {
      final draft = ManualResumeDraft.blank().copyWith(role: 'qa-engineer');
      final saveResult = await repository.saveDraft('alice', draft);
      expect(saveResult, isA<Success<void>>());

      final loadResult = await repository.loadDraft('alice');
      expect((loadResult as Success<ManualResumeDraft?>).value!.role, 'qa-engineer');
    });

    test('clearDraft succeeds', () async {
      await repository.saveDraft('alice', ManualResumeDraft.blank().copyWith(role: 'x'));
      final result = await repository.clearDraft('alice');
      expect(result, isA<Success<void>>());
      expect((await repository.loadDraft('alice') as Success<ManualResumeDraft?>).value, isNull);
    });
  });

  group('storage failure', () {
    late ManualResumeDraftRepositoryImpl repository;

    setUp(() {
      repository = ManualResumeDraftRepositoryImpl(ManualResumeDraftLocalDataSource(_ThrowingSecureStorageService()));
    });

    test('loadDraft maps a genuine storage exception to Failed, not a crash', () async {
      final result = await repository.loadDraft('alice');
      expect(result, isA<Failed<ManualResumeDraft?>>());
      expect((result as Failed<ManualResumeDraft?>).failure, isA<UnexpectedFailure>());
    });

    test('saveDraft maps a genuine storage exception to Failed', () async {
      final result = await repository.saveDraft('alice', ManualResumeDraft.blank());
      expect(result, isA<Failed<void>>());
    });

    test('clearDraft maps a genuine storage exception to Failed', () async {
      final result = await repository.clearDraft('alice');
      expect(result, isA<Failed<void>>());
    });
  });
}
