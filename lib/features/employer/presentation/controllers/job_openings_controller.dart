import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/job_openings.dart';
import '../providers/job_openings_providers.dart';

class JobOpeningsController extends AsyncNotifier<JobOpeningsPage> {
  @override
  Future<JobOpeningsPage> build() async {
    final result = await ref.read(jobOpeningsRepositoryProvider).getJobOpenings();
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final jobOpeningsControllerProvider = AsyncNotifierProvider<JobOpeningsController, JobOpeningsPage>(
  JobOpeningsController.new,
  retry: (retryCount, error) => null,
);
