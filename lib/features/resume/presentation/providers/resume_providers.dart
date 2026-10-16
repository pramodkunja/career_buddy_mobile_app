import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/create_resume_remote_datasource.dart';
import '../../data/create_resume_repository_impl.dart';
import '../../data/manual_resume_draft_local_datasource.dart';
import '../../data/manual_resume_draft_repository_impl.dart';
import '../../data/resume_remote_datasource.dart';
import '../../data/resume_repository_impl.dart';
import '../../domain/entities/create_resume_draft_summary.dart';
import '../../domain/entities/resume_history_item.dart';
import '../../domain/repositories/create_resume_repository.dart';
import '../../domain/repositories/manual_resume_draft_repository.dart';
import '../../domain/repositories/resume_repository.dart';
import '../controllers/create_resume_builder_controller.dart';
import '../controllers/create_resume_drafts_controller.dart';
import '../controllers/create_resume_pdf_controller.dart';
import '../controllers/create_resume_preview_controller.dart';
import '../controllers/manual_resume_builder_controller.dart';
import '../controllers/manual_resume_page_preview_controller.dart';
import '../controllers/manual_resume_pdf_controller.dart';
import '../controllers/manual_resume_preview_controller.dart';
import '../controllers/resume_builder_controller.dart';
import '../controllers/resume_history_controller.dart';
import '../controllers/role_picker_controller.dart';

final resumeRemoteDataSourceProvider = Provider<ResumeRemoteDataSource>((ref) {
  return ResumeRemoteDataSource(ref.watch(apiClientProvider));
});

final resumeRepositoryProvider = Provider<ResumeRepository>((ref) {
  return ResumeRepositoryImpl(ref.watch(resumeRemoteDataSourceProvider));
});

final resumeBuilderControllerProvider =
    NotifierProvider<ResumeBuilderController, ResumeBuilderState>(
      ResumeBuilderController.new,
    );

final resumeHistoryControllerProvider =
    AsyncNotifierProvider<ResumeHistoryController, List<ResumeHistoryItem>>(
      ResumeHistoryController.new,
      retry: (retryCount, error) => null,
    );

final rolePickerControllerProvider =
    NotifierProvider<RolePickerController, RolePickerState>(
      RolePickerController.new,
    );

final manualResumeDraftLocalDataSourceProvider =
    Provider<ManualResumeDraftLocalDataSource>((ref) {
      return ManualResumeDraftLocalDataSource(ref.watch(secureStorageProvider));
    });

final manualResumeDraftRepositoryProvider =
    Provider<ManualResumeDraftRepository>((ref) {
      return ManualResumeDraftRepositoryImpl(
        ref.watch(manualResumeDraftLocalDataSourceProvider),
      );
    });

final manualResumeBuilderControllerProvider =
    NotifierProvider<ManualResumeBuilderController, ManualResumeBuilderState>(
      ManualResumeBuilderController.new,
    );

final manualResumePreviewControllerProvider =
    NotifierProvider<ManualResumePreviewController, ManualResumePreviewState>(
      ManualResumePreviewController.new,
    );

final manualResumePagePreviewControllerProvider =
    NotifierProvider<
      ManualResumePagePreviewController,
      ManualResumePagePreviewState
    >(ManualResumePagePreviewController.new);

final manualResumePdfControllerProvider =
    NotifierProvider<ManualResumePdfController, ManualResumePdfState>(
      ManualResumePdfController.new,
    );

// --------------------------------------------------------------------- //
//  Create Resume — the free-form, server-backed builder (Phase 39).
// --------------------------------------------------------------------- //

final createResumeRemoteDataSourceProvider =
    Provider<CreateResumeRemoteDataSource>((ref) {
      return CreateResumeRemoteDataSource(ref.watch(apiClientProvider));
    });

final createResumeRepositoryProvider = Provider<CreateResumeRepository>((ref) {
  return CreateResumeRepositoryImpl(
    ref.watch(createResumeRemoteDataSourceProvider),
  );
});

final createResumeBuilderControllerProvider =
    NotifierProvider<CreateResumeBuilderController, CreateResumeBuilderState>(
      CreateResumeBuilderController.new,
    );

final createResumePreviewControllerProvider =
    NotifierProvider<CreateResumePreviewController, CreateResumePreviewState>(
      CreateResumePreviewController.new,
    );

final createResumePdfControllerProvider =
    NotifierProvider<CreateResumePdfController, CreateResumePdfState>(
      CreateResumePdfController.new,
    );

final createResumeDraftsControllerProvider =
    AsyncNotifierProvider<
      CreateResumeDraftsController,
      List<CreateResumeDraftSummary>
    >(
      CreateResumeDraftsController.new,
      // Same reasoning as `resumeHistoryControllerProvider`/
      // `dashboardControllerProvider`: without this, Riverpod retries a
      // failed `build()` several times with exponential backoff before
      // surfacing the error — silently extending the loading spinner
      // instead of showing the real failure with an explicit Retry button.
      retry: (retryCount, error) => null,
    );
