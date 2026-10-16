import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/create_resume_outcomes.dart';
import '../../domain/entities/create_resume_state.dart';
import '../../domain/entities/create_resume_validation_error.dart';
import '../providers/resume_providers.dart';

/// Phase 39 — mirrors `ManualResumePdfController` exactly: the same
/// temp-file-then-`open_file` technique every in-app PDF download in this
/// app already uses, and the same `_generation` guard (see that
/// controller's own doc comment for the full Riverpod-lifecycle reasoning).
/// `open_file`/`path_provider` are both already project dependencies — no
/// new package needed.
sealed class CreateResumePdfState {
  const CreateResumePdfState();
}

final class CreateResumePdfIdle extends CreateResumePdfState {
  const CreateResumePdfIdle();
}

final class CreateResumePdfGenerating extends CreateResumePdfState {
  const CreateResumePdfGenerating();
}

final class CreateResumePdfValidationFailed extends CreateResumePdfState {
  const CreateResumePdfValidationFailed(this.errors);
  final List<CreateResumeValidationError> errors;
}

final class CreateResumePdfFailed extends CreateResumePdfState {
  const CreateResumePdfFailed(this.failure);
  final Failure failure;
}

class CreateResumePdfController extends Notifier<CreateResumePdfState> {
  int _generation = 0;

  @override
  CreateResumePdfState build() {
    _generation++;
    return const CreateResumePdfIdle();
  }

  Future<void> generateAndOpen(CreateResumeFormState form) async {
    if (state is CreateResumePdfGenerating) return;
    final requestGeneration = _generation;
    state = const CreateResumePdfGenerating();

    final result = await ref
        .read(createResumeRepositoryProvider)
        .generatePdf(form);
    if (!ref.mounted || requestGeneration != _generation) return;
    switch (result) {
      case Failed(failure: final failure):
        state = CreateResumePdfFailed(failure);
        return;
      case Success(value: final outcome):
        switch (outcome) {
          case CreateResumePdfRejected(:final errors):
            ref
                .read(createResumeBuilderControllerProvider.notifier)
                .setServerErrors(errors);
            state = CreateResumePdfValidationFailed(errors);
            return;
          case CreateResumePdfReady(:final bytes, :final filename):
            ref
                .read(createResumeBuilderControllerProvider.notifier)
                .clearServerErrors();
            await _saveAndOpen(
              bytes: bytes,
              filename: filename,
              requestGeneration: requestGeneration,
            );
        }
    }
  }

  Future<void> _saveAndOpen({
    required List<int> bytes,
    required String filename,
    required int requestGeneration,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      if (!ref.mounted || requestGeneration != _generation) return;
      state = const CreateResumePdfIdle();
      final result = await OpenFile.open(file.path);
      if (!ref.mounted || requestGeneration != _generation) return;
      if (result.type != ResultType.done) {
        state = CreateResumePdfFailed(
          UnexpectedFailure(_openFileFailureMessage(result.type)),
        );
      }
    } on Object {
      if (!ref.mounted || requestGeneration != _generation) return;
      state = CreateResumePdfFailed(
        ExceptionMapper.map(const UnexpectedResponseException()),
      );
    }
  }

  void reset() {
    if (state is! CreateResumePdfGenerating) {
      state = const CreateResumePdfIdle();
    }
  }
}

String _openFileFailureMessage(ResultType type) => switch (type) {
  ResultType.noAppToOpen =>
    'No app installed on this device can open a PDF. Install a compatible viewer and try again.',
  ResultType.fileNotFound => 'The generated PDF could not be found.',
  ResultType.permissionDenied =>
    'Permission denied while trying to open the PDF.',
  _ => 'Something unexpected happened. Please try again.',
};
