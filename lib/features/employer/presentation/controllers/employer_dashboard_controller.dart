import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/employer_dashboard_summary.dart';
import '../providers/employer_dashboard_providers.dart';

/// `AsyncNotifier` (not a custom sealed state) — this screen only ever
/// needs the built-in loading/data/error triad plus retry, the same
/// reasoning already documented for the (planned) student dashboard
/// controller: nothing here needs a bespoke state machine.
class EmployerDashboardController extends AsyncNotifier<EmployerDashboardSummary> {
  @override
  Future<EmployerDashboardSummary> build() async {
    final result = await ref.read(employerDashboardRepositoryProvider).getDashboard();
    return switch (result) {
      Success(value: final summary) => summary,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Result<void>> deleteJob(int jobId) async {
    final result = await ref.read(employerDashboardRepositoryProvider).deleteJob(jobId);
    if (result is Success) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }
}
