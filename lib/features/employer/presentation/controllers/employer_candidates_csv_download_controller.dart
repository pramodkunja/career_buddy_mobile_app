import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../providers/employer_candidate_search_providers.dart';

/// Transient state of the Candidate Search "Download CSV" action — one
/// shared instance, unlike `ProtectedMediaDownloadController` (no per-file
/// identity needed; there's only ever one CSV export in flight for this
/// screen at a time).
sealed class CandidatesCsvDownloadState {
  const CandidatesCsvDownloadState();
}

final class CandidatesCsvDownloadIdle extends CandidatesCsvDownloadState {
  const CandidatesCsvDownloadIdle();
}

final class CandidatesCsvDownloading extends CandidatesCsvDownloadState {
  const CandidatesCsvDownloading();
}

final class CandidatesCsvDownloadFailed extends CandidatesCsvDownloadState {
  const CandidatesCsvDownloadFailed(this.failure);
  final Failure failure;
}

/// `jobs_app.views.download_candidates_csv` — fetches the generated CSV
/// through this app's own authenticated Dio client, saves it locally, then
/// hands it to `open_file` to open in whatever app the device has
/// registered for `.csv` files — same "download authenticated bytes to a
/// local file first" technique as `CertificateDownloadController`/
/// `ProtectedMediaDownloadController`.
class EmployerCandidatesCsvDownloadController extends Notifier<CandidatesCsvDownloadState> {
  @override
  CandidatesCsvDownloadState build() => const CandidatesCsvDownloadIdle();

  Future<void> downloadAndOpen({required String query, required String location, required String experience}) async {
    if (state is CandidatesCsvDownloading) return;
    state = const CandidatesCsvDownloading();

    final result = await ref
        .read(employerCandidateSearchRepositoryProvider)
        .downloadCsvBytes(query: query, location: location, experience: experience);
    switch (result) {
      case Success(value: final bytes):
        try {
          final dir = await getTemporaryDirectory();
          // The real response's `Content-Disposition` always names this
          // file `candidates.csv` (a static filename, confirmed live — see
          // `ApiEndpoints.employerCandidatesDownloadCsv`'s doc comment).
          final file = File('${dir.path}/candidates.csv');
          await file.writeAsBytes(bytes, flush: true);
          state = const CandidatesCsvDownloadIdle();
          final openResult = await OpenFile.open(file.path);
          if (openResult.type != ResultType.done) {
            // A real, reachable case confirmed on a physical device: the CSV
            // downloaded fine but this device has no spreadsheet/text app
            // registered for `.csv` — an honest, specific message beats the
            // generic catch-all below.
            state = CandidatesCsvDownloadFailed(UnexpectedFailure(_openFileFailureMessage(openResult.type)));
            return;
          }
        } on Object {
          state = CandidatesCsvDownloadFailed(ExceptionMapper.map(const UnexpectedResponseException()));
        }
      case Failed(failure: final failure):
        state = CandidatesCsvDownloadFailed(failure);
    }
  }
}

String _openFileFailureMessage(ResultType type) => switch (type) {
  ResultType.noAppToOpen => 'No app installed on this device can open this file. Install a compatible viewer and try again.',
  ResultType.fileNotFound => 'The downloaded file could not be found.',
  ResultType.permissionDenied => 'Permission denied while trying to open this file.',
  _ => 'Something unexpected happened. Please try again.',
};

final employerCandidatesCsvDownloadControllerProvider =
    NotifierProvider<EmployerCandidatesCsvDownloadController, CandidatesCsvDownloadState>(
      EmployerCandidatesCsvDownloadController.new,
    );
