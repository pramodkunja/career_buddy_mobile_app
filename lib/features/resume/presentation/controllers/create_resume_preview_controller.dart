import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/create_resume_document.dart';
import '../../domain/entities/create_resume_outcomes.dart';
import '../../domain/entities/create_resume_state.dart';
import '../providers/resume_providers.dart';

/// Phase 39 — submits the current [CreateResumeFormState] to `preview_api`.
/// Simpler than `ManualResumePreviewController`: `preview_api` never
/// rejects (see [CreateResumePreviewOutcome]'s own doc comment), so there
/// is no separate "validation failed" state here — a non-empty `errors`
/// list is just part of the normal ready state, fed to the builder so the
/// in-progress steps can flag the same fields.
sealed class CreateResumePreviewState {
  const CreateResumePreviewState();
}

final class CreateResumePreviewIdle extends CreateResumePreviewState {
  const CreateResumePreviewIdle();
}

final class CreateResumePreviewLoading extends CreateResumePreviewState {
  const CreateResumePreviewLoading();
}

final class CreateResumePreviewReadyState extends CreateResumePreviewState {
  const CreateResumePreviewReadyState({
    required this.document,
    required this.filename,
  });
  final CreateResumeDocument document;
  final String filename;
}

final class CreateResumePreviewFailed extends CreateResumePreviewState {
  const CreateResumePreviewFailed(this.failure);
  final Failure failure;
}

class CreateResumePreviewController extends Notifier<CreateResumePreviewState> {
  /// See `ManualResumePdfController._generation`'s doc comment for the full
  /// reasoning — verified directly against the installed `riverpod: 3.4.3`
  /// that a plain (non-`autoDispose`) `NotifierProvider` re-runs [build] on
  /// the same instance on invalidation, so `ref.mounted` alone cannot catch
  /// a logout mid-request.
  int _generation = 0;

  @override
  CreateResumePreviewState build() {
    _generation++;
    return const CreateResumePreviewIdle();
  }

  Future<void> generate(CreateResumeFormState form) async {
    if (state is CreateResumePreviewLoading) return;
    final requestGeneration = _generation;
    state = const CreateResumePreviewLoading();
    final result = await ref.read(createResumeRepositoryProvider).preview(form);
    if (!ref.mounted || requestGeneration != _generation) return;
    final builder = ref.read(createResumeBuilderControllerProvider.notifier);
    switch (result) {
      case Success(value: final outcome):
        builder.setServerErrors(outcome.errors);
        state = CreateResumePreviewReadyState(
          document: outcome.document,
          filename: outcome.filename,
        );
      case Failed(failure: final failure):
        state = CreateResumePreviewFailed(failure);
    }
  }

  Future<void> retry(CreateResumeFormState form) => generate(form);
}
