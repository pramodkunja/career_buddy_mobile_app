import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../providers/subscription_providers.dart';

sealed class InvoiceDownloadState {
  const InvoiceDownloadState();
}

final class InvoiceDownloadIdle extends InvoiceDownloadState {
  const InvoiceDownloadIdle();
}

final class InvoiceDownloading extends InvoiceDownloadState {
  const InvoiceDownloading();
}

final class InvoiceDownloadFailed extends InvoiceDownloadState {
  const InvoiceDownloadFailed(this.failure);
  final Failure failure;
}

/// Fetches the GST invoice HTML for one payment through the app's own
/// authenticated Dio client, saves it as a local `.html` file, then hands
/// it to `open_file` to render in the device's default browser. The invoice
/// template uses fully-inline CSS so the file renders correctly without any
/// network dependency — confirmed by reading `gst_invoice.html` directly.
///
/// Keyed by the `RazorpayPayment` pk, so each invoice row tracks its own
/// in-flight state independently (same pattern as
/// `ProtectedMediaDownloadController`/`invoiceDownloadControllerProvider`).
class InvoiceDownloadController extends Notifier<InvoiceDownloadState> {
  InvoiceDownloadController(this._paymentId);

  final int _paymentId;

  @override
  InvoiceDownloadState build() => const InvoiceDownloadIdle();

  Future<void> downloadAndOpen(String invoiceNumber) async {
    if (state is InvoiceDownloading) return;
    state = const InvoiceDownloading();

    final result = await ref
        .read(subscriptionRepositoryProvider)
        .downloadInvoice(_paymentId);
    switch (result) {
      case Success(value: final bytes):
        try {
          final dir = await getTemporaryDirectory();
          // Sanitize CB/2026-27/00042 → CB-2026-27-00042 for a safe filename.
          // Fall back to the payment ID when the invoice number is absent so
          // the file path is never just `invoice_.html`.
          final nameForFile = invoiceNumber.isNotEmpty ? invoiceNumber : 'payment-$_paymentId';
          final safeName = nameForFile.replaceAll('/', '-');
          final file = File('${dir.path}/invoice_$safeName.html');
          await file.writeAsBytes(bytes, flush: true);
          state = const InvoiceDownloadIdle();
          final openResult = await OpenFile.open(file.path);
          if (openResult.type != ResultType.done) {
            state = InvoiceDownloadFailed(
              UnexpectedFailure(_openFileFailureMessage(openResult.type)),
            );
          }
        } on Object {
          state = InvoiceDownloadFailed(
            ExceptionMapper.map(const UnexpectedResponseException()),
          );
        }
      case Failed(failure: final failure):
        state = InvoiceDownloadFailed(failure);
    }
  }
}

final invoiceDownloadControllerProvider = NotifierProvider.family<
    InvoiceDownloadController, InvoiceDownloadState, int>(
  InvoiceDownloadController.new,
);

String _openFileFailureMessage(ResultType type) => switch (type) {
  ResultType.noAppToOpen =>
    'No app installed on this device can open this file. Install a compatible browser and try again.',
  ResultType.fileNotFound => 'The downloaded file could not be found.',
  ResultType.permissionDenied =>
    'Permission denied while trying to open this file.',
  _ => 'Something unexpected happened. Please try again.',
};
