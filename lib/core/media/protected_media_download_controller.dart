import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../errors/exception_mapper.dart';
import '../errors/exceptions.dart';
import '../errors/failures.dart';
import '../providers/core_providers.dart';

/// Transient state of "View/Download" for ONE protected file, keyed by its
/// own resolved URL (see the `.family` provider below) so Resume History,
/// Employer Application Detail, and Candidate Search each track their own
/// in-flight downloads independently from one shared controller.
sealed class ProtectedMediaDownloadState {
  const ProtectedMediaDownloadState();
}

final class ProtectedMediaDownloadIdle extends ProtectedMediaDownloadState {
  const ProtectedMediaDownloadIdle();
}

final class ProtectedMediaDownloading extends ProtectedMediaDownloadState {
  const ProtectedMediaDownloading();
}

final class ProtectedMediaDownloadFailed extends ProtectedMediaDownloadState {
  const ProtectedMediaDownloadFailed(this.failure);
  final Failure failure;
}

/// Fetches a protected file through the app's own authenticated Dio client,
/// saves it to a temporary local file, then hands it to `open_file` to
/// open in the device's own viewer for that file type — the same technique
/// `CertificateDownloadController` uses for certificates, generalized for
/// any protected media URL. A temp file (not the persistent documents
/// directory certificates use) since this is a "view", not an explicit
/// "keep a copy" action — same reasoning as `GrammarMediaDataSource
/// .fetchVideoToTempFile`.
class ProtectedMediaDownloadController extends Notifier<ProtectedMediaDownloadState> {
  ProtectedMediaDownloadController(this.resolvedUrl);

  final String resolvedUrl;

  @override
  ProtectedMediaDownloadState build() => const ProtectedMediaDownloadIdle();

  Future<void> downloadAndOpen(String filename) async {
    if (state is ProtectedMediaDownloading) return;
    state = const ProtectedMediaDownloading();

    try {
      final bytes = await ref.read(protectedMediaRemoteDataSourceProvider).downloadBytes(resolvedUrl);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      state = const ProtectedMediaDownloadIdle();
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        // A real, reachable case confirmed on a physical device (not
        // network/server-side, so not routed through `ExceptionMapper`):
        // the file downloaded fine but this device has no app registered to
        // view this file type (e.g. no DOCX viewer installed) — an honest,
        // specific message beats the generic catch-all below.
        state = ProtectedMediaDownloadFailed(UnexpectedFailure(_openFileFailureMessage(result.type)));
        return;
      }
    } on AppException catch (e) {
      state = ProtectedMediaDownloadFailed(ExceptionMapper.map(e));
    } on Object {
      // Local file-save/open failure (disk, or no viewer app installed for
      // this file type) — not a network/server error, mapped through the
      // same generic path `CertificateDownloadController` uses for the
      // identical case.
      state = ProtectedMediaDownloadFailed(ExceptionMapper.map(const UnexpectedResponseException()));
    }
  }
}

final protectedMediaDownloadControllerProvider =
    NotifierProvider.family<ProtectedMediaDownloadController, ProtectedMediaDownloadState, String>(
      ProtectedMediaDownloadController.new,
    );

String _openFileFailureMessage(ResultType type) => switch (type) {
  ResultType.noAppToOpen => 'No app installed on this device can open this file. Install a compatible viewer and try again.',
  ResultType.fileNotFound => 'The downloaded file could not be found.',
  ResultType.permissionDenied => 'Permission denied while trying to open this file.',
  _ => 'Something unexpected happened. Please try again.',
};
