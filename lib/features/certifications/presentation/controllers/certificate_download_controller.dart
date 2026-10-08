import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../providers/certifications_providers.dart';

/// Transient state of "View/Download Certificate" for ONE subject.
sealed class CertificateDownloadState {
  const CertificateDownloadState();
}

final class CertificateDownloadIdle extends CertificateDownloadState {
  const CertificateDownloadIdle();
}

final class CertificateDownloading extends CertificateDownloadState {
  const CertificateDownloading();
}

final class CertificateDownloadFailed extends CertificateDownloadState {
  const CertificateDownloadFailed(this.failure);
  final Failure failure;
}

/// Fetches the generated certificate PDF through the app's own
/// authenticated Dio client (`certificate_download` is `@login_required`
/// and serves a binary `FileResponse` — an external, unauthenticated
/// browser can't open it directly, unlike Resume History's "View File",
/// see that screen's doc comment for the contrasting, known-limitation
/// case), saves it to a local file, then hands it to `open_file` to open
/// in the device's PDF viewer — the same "download authenticated bytes to
/// a local file first" technique as
/// `GrammarMediaDataSource.fetchVideoToTempFile`, just via the repository
/// layer (with a testable `Result`) rather than `Dio.download` directly.
class CertificateDownloadController extends Notifier<CertificateDownloadState> {
  CertificateDownloadController(this.subject);

  final String subject;

  @override
  CertificateDownloadState build() => const CertificateDownloadIdle();

  Future<void> downloadAndOpen() async {
    if (state is CertificateDownloading) return;
    state = const CertificateDownloading();

    final result = await ref.read(certificationsRepositoryProvider).downloadCertificateBytes(subject);
    switch (result) {
      case Success(value: final bytes):
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/certificate_$subject.pdf');
          await file.writeAsBytes(bytes, flush: true);
          state = const CertificateDownloadIdle();
          final openResult = await OpenFile.open(file.path);
          if (openResult.type != ResultType.done) {
            // A real, reachable case confirmed on a physical device: the PDF
            // downloaded fine but this device has no PDF viewer installed —
            // an honest, specific message beats the generic catch-all below.
            state = CertificateDownloadFailed(UnexpectedFailure(_openFileFailureMessage(openResult.type)));
            return;
          }
        } on Object {
          // Local file-save failure (disk) — not a network/server error, so
          // it's mapped through the same `UnexpectedResponseException` ->
          // `UnexpectedFailure` path everything else in this app uses for
          // "something went wrong that isn't a specific, known case".
          state = CertificateDownloadFailed(ExceptionMapper.map(const UnexpectedResponseException()));
        }
      case Failed(failure: final failure):
        state = CertificateDownloadFailed(failure);
    }
  }
}

String _openFileFailureMessage(ResultType type) => switch (type) {
  ResultType.noAppToOpen => 'No app installed on this device can open this file. Install a compatible viewer and try again.',
  ResultType.fileNotFound => 'The downloaded file could not be found.',
  ResultType.permissionDenied => 'Permission denied while trying to open this file.',
  _ => 'Something unexpected happened. Please try again.',
};
