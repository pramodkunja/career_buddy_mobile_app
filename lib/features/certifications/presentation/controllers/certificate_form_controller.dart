import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../providers/certifications_providers.dart';

/// Transient state of the "Generate Certificate" / "Edit Name & Regenerate"
/// action for ONE subject — same shape as
/// `MarkSubCompleteController`/`MarkCompleteState`: this controller only
/// tracks the submit action itself. Whether the subject IS now `certified`
/// is never guessed client-side; on success it invalidates
/// `certificationsStatusControllerProvider`, so the section's own "certified"
/// UI only ever appears once the server's own next GET confirms it (never
/// trusting/echoing a client-computed score or state).
sealed class CertificateFormState {
  const CertificateFormState();
}

final class CertificateFormIdle extends CertificateFormState {
  const CertificateFormIdle();
}

final class CertificateFormSubmitting extends CertificateFormState {
  const CertificateFormSubmitting();
}

final class CertificateFormFailed extends CertificateFormState {
  const CertificateFormFailed(this.failure);
  final Failure failure;
}

/// Keyed per subject slug (`NotifierProvider.family`) so generating/editing
/// one subject's certificate never shows a spinner on another subject's
/// card. Same constructor-param family-notifier shape as
/// `MarkSubCompleteController`.
class CertificateFormController extends Notifier<CertificateFormState> {
  CertificateFormController(this.subject);

  final String subject;

  @override
  CertificateFormState build() => const CertificateFormIdle();

  Future<bool> generate(String name) =>
      _submit(() => ref.read(certificationsRepositoryProvider).generateCertificate(subject: subject, name: name));

  Future<bool> regenerate(String name) =>
      _submit(() => ref.read(certificationsRepositoryProvider).regenerateCertificate(subject: subject, name: name));

  Future<bool> _submit(Future<Result<Object?>> Function() call) async {
    if (state is CertificateFormSubmitting) return false;
    state = const CertificateFormSubmitting();
    final result = await call();
    switch (result) {
      case Success():
        state = const CertificateFormIdle();
        ref.invalidate(certificationsStatusControllerProvider);
        return true;
      case Failed(failure: final failure):
        state = CertificateFormFailed(failure);
        return false;
    }
  }
}
