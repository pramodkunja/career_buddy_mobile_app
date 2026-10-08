import 'dart:io';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certification_subject.dart';
import 'package:career_buddy_lms/features/certifications/domain/entities/certifications_status.dart';
import 'package:career_buddy_lms/features/certifications/domain/repositories/certifications_repository.dart';
import 'package:career_buddy_lms/features/certifications/presentation/controllers/certificate_download_controller.dart';
import 'package:career_buddy_lms/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file_platform_interface/open_file_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../support/fake_open_file_platform.dart';
import '../../../../support/fake_path_provider_platform.dart';

class _FakeCertificationsRepository implements CertificationsRepository {
  _FakeCertificationsRepository(this.downloadResult);

  final Result<Uint8List> downloadResult;

  @override
  Future<Result<Uint8List>> downloadCertificateBytes(String subject) async => downloadResult;

  @override
  Future<Result<CertificationSubject>> generateCertificate({required String subject, required String name}) =>
      throw UnimplementedError();

  @override
  Future<Result<CertificationSubject>> regenerateCertificate({required String subject, required String name}) =>
      throw UnimplementedError();

  @override
  Future<Result<CertificationsStatus>> getStatus() => throw UnimplementedError();
}

void main() {
  late Directory tempDir;
  final originalOpenFilePlatform = OpenFilePlatform.platform;
  final originalPathProviderPlatform = PathProviderPlatform.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('certificate_download_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    OpenFilePlatform.platform = originalOpenFilePlatform;
    PathProviderPlatform.instance = originalPathProviderPlatform;
    await tempDir.delete(recursive: true);
  });

  group('CertificateDownloadController.downloadAndOpen', () {
    test('downloads the PDF bytes, writes them locally, and hands the exact path to OpenFile', () async {
      final fakeOpenFile = FakeOpenFilePlatform(result: OpenResult(type: ResultType.done, message: 'done'));
      OpenFilePlatform.platform = fakeOpenFile;
      final bytes = Uint8List.fromList('pdf bytes'.codeUnits);
      final container = ProviderContainer(
        overrides: [
          certificationsRepositoryProvider.overrideWithValue(_FakeCertificationsRepository(Success(bytes))),
        ],
      );
      addTearDown(container.dispose);

      await container.read(certificateDownloadControllerProvider('tech').notifier).downloadAndOpen();

      expect(container.read(certificateDownloadControllerProvider('tech')), isA<CertificateDownloadIdle>());
      expect(fakeOpenFile.lastFilePath, '${tempDir.path}/certificate_tech.pdf');
      expect(await File('${tempDir.path}/certificate_tech.pdf').readAsBytes(), bytes);
    });

    test(
      'a real device reporting ResultType.noAppToOpen (no PDF viewer '
      'installed) surfaces a specific, honest message instead of the '
      'generic catch-all',
      () async {
        OpenFilePlatform.platform = FakeOpenFilePlatform(
          result: OpenResult(type: ResultType.noAppToOpen, message: 'No APP found to open this file.'),
        );
        final container = ProviderContainer(
          overrides: [
            certificationsRepositoryProvider.overrideWithValue(
              _FakeCertificationsRepository(Success(Uint8List.fromList('pdf bytes'.codeUnits))),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(certificateDownloadControllerProvider('tech').notifier).downloadAndOpen();

        final state = container.read(certificateDownloadControllerProvider('tech'));
        expect(state, isA<CertificateDownloadFailed>());
        expect(
          (state as CertificateDownloadFailed).failure.message,
          'No app installed on this device can open this file. Install a compatible viewer and try again.',
        );
      },
    );

    test('a repository failure surfaces unchanged, never reaching OpenFile', () async {
      final fakeOpenFile = FakeOpenFilePlatform();
      OpenFilePlatform.platform = fakeOpenFile;
      final container = ProviderContainer(
        overrides: [
          certificationsRepositoryProvider.overrideWithValue(
            _FakeCertificationsRepository(const Failed(ServerFailure())),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(certificateDownloadControllerProvider('tech').notifier).downloadAndOpen();

      final state = container.read(certificateDownloadControllerProvider('tech'));
      expect(state, isA<CertificateDownloadFailed>());
      expect((state as CertificateDownloadFailed).failure, isA<ServerFailure>());
      expect(fakeOpenFile.lastFilePath, isNull);
    });
  });
}
