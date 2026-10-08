import 'dart:async';
import 'dart:io';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/employer/domain/entities/employer_candidate_search.dart';
import 'package:career_buddy_lms/features/employer/domain/repositories/employer_candidate_search_repository.dart';
import 'package:career_buddy_lms/features/employer/presentation/controllers/employer_candidates_csv_download_controller.dart';
import 'package:career_buddy_lms/features/employer/presentation/providers/employer_candidate_search_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file_platform_interface/open_file_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../support/fake_open_file_platform.dart';
import '../../../../support/fake_path_provider_platform.dart';

class _FakeRepository implements EmployerCandidateSearchRepository {
  _FakeRepository(this.csvResult);

  Result<List<int>> csvResult;
  String? lastQuery;
  String? lastLocation;
  String? lastExperience;

  @override
  Future<Result<List<EmployerCandidateSearchResult>>> search({
    String query = '',
    String location = '',
    String experience = '',
  }) async => const Success([]);

  @override
  Future<Result<List<int>>> downloadCsvBytes({
    String query = '',
    String location = '',
    String experience = '',
  }) async {
    lastQuery = query;
    lastLocation = location;
    lastExperience = experience;
    return csvResult;
  }
}

void main() {
  // Scoped to each test that needs them (not file-level setUp/tearDown):
  // `PathProviderPlatform.instance`/`OpenFilePlatform.platform` are process-
  // global statics, and "sends exactly the given query/location/experience"
  // below deliberately leaks an un-awaited `downloadAndOpen()` call past its
  // own test's end (see its own comment) — a file-level fake would still be
  // live (or worse, reassigned to a *later* test's fake, and that leaked
  // call's `container` is already disposed by then) when that call finally
  // resumes, which is exactly the "Cannot use Ref after disposed" failure
  // this structure avoids.
  Future<Directory> fakeFileSystemPlugins(FakeOpenFilePlatform fakeOpenFile) async {
    final tempDir = await Directory.systemTemp.createTemp('candidates_csv_test');
    final originalOpenFilePlatform = OpenFilePlatform.platform;
    final originalPathProviderPlatform = PathProviderPlatform.instance;
    OpenFilePlatform.platform = fakeOpenFile;
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    addTearDown(() async {
      OpenFilePlatform.platform = originalOpenFilePlatform;
      PathProviderPlatform.instance = originalPathProviderPlatform;
      await tempDir.delete(recursive: true);
    });
    return tempDir;
  }

  group('EmployerCandidatesCsvDownloadController', () {
    test('downloads the CSV bytes, writes them locally, and hands the exact path to OpenFile', () async {
      final fakeOpenFile = FakeOpenFilePlatform(result: OpenResult(type: ResultType.done, message: 'done'));
      final tempDir = await fakeFileSystemPlugins(fakeOpenFile);
      final repo = _FakeRepository(const Success([1, 2, 3]));
      final container = ProviderContainer(
        overrides: [employerCandidateSearchRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(employerCandidatesCsvDownloadControllerProvider.notifier)
          .downloadAndOpen(query: 'python', location: '', experience: '');

      expect(container.read(employerCandidatesCsvDownloadControllerProvider), isA<CandidatesCsvDownloadIdle>());
      expect(fakeOpenFile.lastFilePath, '${tempDir.path}/candidates.csv');
      expect(await File('${tempDir.path}/candidates.csv').readAsBytes(), [1, 2, 3]);
    });

    test(
      'a real device reporting ResultType.noAppToOpen (no CSV/spreadsheet '
      'app installed) surfaces a specific, honest message instead of the '
      'generic catch-all',
      () async {
        await fakeFileSystemPlugins(
          FakeOpenFilePlatform(result: OpenResult(type: ResultType.noAppToOpen, message: 'No APP found to open this file.')),
        );
        final repo = _FakeRepository(const Success([1, 2, 3]));
        final container = ProviderContainer(
          overrides: [employerCandidateSearchRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await container
            .read(employerCandidatesCsvDownloadControllerProvider.notifier)
            .downloadAndOpen(query: '', location: '', experience: '');

        final state = container.read(employerCandidatesCsvDownloadControllerProvider);
        expect(state, isA<CandidatesCsvDownloadFailed>());
        expect(
          (state as CandidatesCsvDownloadFailed).failure.message,
          'No app installed on this device can open this file. Install a compatible viewer and try again.',
        );
      },
    );

    test('sends exactly the given query/location/experience to the repository', () async {
      final repo = _FakeRepository(const Success([1, 2, 3]));
      final container = ProviderContainer(
        overrides: [employerCandidateSearchRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // The repository call happens before this hits any plugin (saving to
      // disk / launching), so it's reachable without a registered platform
      // channel even though the method doesn't fully complete here.
      unawaited(
        container
            .read(employerCandidatesCsvDownloadControllerProvider.notifier)
            .downloadAndOpen(query: 'python', location: 'Remote', experience: '3-5'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repo.lastQuery, 'python');
      expect(repo.lastLocation, 'Remote');
      expect(repo.lastExperience, '3-5');
    });

    test('a repository failure surfaces as CandidatesCsvDownloadFailed with the server\'s own message', () async {
      final repo = _FakeRepository(const Failed(ServerFailure()));
      final container = ProviderContainer(
        overrides: [employerCandidateSearchRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container
          .read(employerCandidatesCsvDownloadControllerProvider.notifier)
          .downloadAndOpen(query: 'python', location: '', experience: '');

      final state = container.read(employerCandidatesCsvDownloadControllerProvider);
      expect(state, isA<CandidatesCsvDownloadFailed>());
      expect((state as CandidatesCsvDownloadFailed).failure, isA<ServerFailure>());
    });

    test('starts in the idle state', () {
      final repo = _FakeRepository(const Success([]));
      final container = ProviderContainer(
        overrides: [employerCandidateSearchRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      expect(container.read(employerCandidatesCsvDownloadControllerProvider), isA<CandidatesCsvDownloadIdle>());
    });
  });
}
