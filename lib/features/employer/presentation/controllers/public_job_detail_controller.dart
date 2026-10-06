import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/public_job_detail.dart';
import '../providers/public_job_detail_providers.dart';

/// One instance per job id (`.family`), matching
/// `EmployerApplicationDetailController`'s own pattern.
class PublicJobDetailController extends AsyncNotifier<PublicJobDetail> {
  PublicJobDetailController(this.jobId);

  final int jobId;

  @override
  Future<PublicJobDetail> build() async {
    final result = await ref.read(publicJobDetailRepositoryProvider).getJobDetail(jobId);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Result<void>> apply(PublicJobApplicationSubmission data) async {
    return ref.read(publicJobDetailRepositoryProvider).apply(jobId, data);
  }
}

final publicJobDetailControllerProvider =
    AsyncNotifierProvider.family<PublicJobDetailController, PublicJobDetail, int>(
      PublicJobDetailController.new,
      retry: (retryCount, error) => null,
    );
