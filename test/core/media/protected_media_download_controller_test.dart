import 'dart:io';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/media/protected_media_download_controller.dart';
import 'package:career_buddy_lms/core/media/protected_media_remote_datasource.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/network/api_exceptions_interceptor.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file_platform_interface/open_file_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/fake_http_client_adapter.dart';
import '../../support/fake_open_file_platform.dart';
import '../../support/fake_path_provider_platform.dart';

void main() {
  late Directory tempDir;
  final originalOpenFilePlatform = OpenFilePlatform.platform;
  final originalPathProviderPlatform = PathProviderPlatform.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('protected_media_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    OpenFilePlatform.platform = originalOpenFilePlatform;
    PathProviderPlatform.instance = originalPathProviderPlatform;
    await tempDir.delete(recursive: true);
  });

  ProviderContainer buildContainer({required int statusCode, String body = 'file bytes'}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..interceptors.add(ApiExceptionsInterceptor())
      ..httpClientAdapter = FakeHttpClientAdapter(statusCode: statusCode, body: body);
    final container = ProviderContainer(
      overrides: [
        protectedMediaRemoteDataSourceProvider.overrideWithValue(
          ProtectedMediaRemoteDataSource(ApiClient.forTesting(dio)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ProtectedMediaDownloadController.downloadAndOpen', () {
    test('downloads the file, writes it locally, and hands the exact path to OpenFile', () async {
      final fakeOpenFile = FakeOpenFilePlatform(result: OpenResult(type: ResultType.done, message: 'done'));
      OpenFilePlatform.platform = fakeOpenFile;
      final container = buildContainer(statusCode: 200);

      await container
          .read(protectedMediaDownloadControllerProvider('/media/resume.docx').notifier)
          .downloadAndOpen('resume.docx');

      expect(container.read(protectedMediaDownloadControllerProvider('/media/resume.docx')), isA<ProtectedMediaDownloadIdle>());
      expect(fakeOpenFile.lastFilePath, '${tempDir.path}/resume.docx');
      expect(await File('${tempDir.path}/resume.docx').readAsString(), 'file bytes');
    });

    test(
      'a real device reporting ResultType.noAppToOpen (confirmed live: a '
      'DOCX with no viewer app installed) surfaces a specific, honest '
      'message instead of the generic catch-all',
      () async {
        OpenFilePlatform.platform = FakeOpenFilePlatform(
          result: OpenResult(type: ResultType.noAppToOpen, message: 'No APP found to open this file.'),
        );
        final container = buildContainer(statusCode: 200);

        await container
            .read(protectedMediaDownloadControllerProvider('/media/resume.docx').notifier)
            .downloadAndOpen('resume.docx');

        final state = container.read(protectedMediaDownloadControllerProvider('/media/resume.docx'));
        expect(state, isA<ProtectedMediaDownloadFailed>());
        expect(
          (state as ProtectedMediaDownloadFailed).failure.message,
          'No app installed on this device can open this file. Install a compatible viewer and try again.',
        );
      },
    );

    test('a download failure (e.g. 401) surfaces as a mapped Failure, never reaching OpenFile', () async {
      final fakeOpenFile = FakeOpenFilePlatform();
      OpenFilePlatform.platform = fakeOpenFile;
      final container = buildContainer(statusCode: 401);

      await container
          .read(protectedMediaDownloadControllerProvider('/media/resume.docx').notifier)
          .downloadAndOpen('resume.docx');

      final state = container.read(protectedMediaDownloadControllerProvider('/media/resume.docx'));
      expect(state, isA<ProtectedMediaDownloadFailed>());
      expect((state as ProtectedMediaDownloadFailed).failure, isA<UnauthorizedFailure>());
      expect(fakeOpenFile.lastFilePath, isNull);
    });
  });
}
