import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
/// case), saves it to a local file, then hands it to `url_launcher` to open
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
          await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
        } on Object {
          // Local file-save/open failure (disk, or no PDF viewer available
          // on the device) — not a network/server error, so it's mapped
          // through the same `UnexpectedResponseException` ->
          // `UnexpectedFailure` path everything else in this app uses for
          // "something went wrong that isn't a specific, known case".
          state = CertificateDownloadFailed(ExceptionMapper.map(const UnexpectedResponseException()));
        }
      case Failed(failure: final failure):
        state = CertificateDownloadFailed(failure);
    }
  }
}
