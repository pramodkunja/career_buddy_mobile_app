import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/certifications_remote_datasource.dart';
import '../../data/repositories/certifications_repository_impl.dart';
import '../../domain/entities/certifications_status.dart';
import '../../domain/repositories/certifications_repository.dart';
import '../controllers/certificate_download_controller.dart';
import '../controllers/certificate_form_controller.dart';

final certificationsRemoteDataSourceProvider = Provider<CertificationsRemoteDataSource>((ref) {
  return CertificationsRemoteDataSource(ref.watch(apiClientProvider));
});

final certificationsRepositoryProvider = Provider<CertificationsRepository>((ref) {
  return CertificationsRepositoryImpl(ref.watch(certificationsRemoteDataSourceProvider));
});

/// The `GET api_certifications_status` fetch — same `AsyncNotifier` +
/// `retry: null` shape as `ResumeHistoryController`.
class CertificationsStatusController extends AsyncNotifier<CertificationsStatus> {
  @override
  Future<CertificationsStatus> build() async {
    final result = await ref.read(certificationsRepositoryProvider).getStatus();
    return switch (result) {
      Success(value: final status) => status,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final certificationsStatusControllerProvider =
    AsyncNotifierProvider<CertificationsStatusController, CertificationsStatus>(
      CertificationsStatusController.new,
      retry: (retryCount, error) => null,
    );

final certificateFormControllerProvider =
    NotifierProvider.family<CertificateFormController, CertificateFormState, String>(
      CertificateFormController.new,
    );

final certificateDownloadControllerProvider =
    NotifierProvider.family<CertificateDownloadController, CertificateDownloadState, String>(
      CertificateDownloadController.new,
    );
