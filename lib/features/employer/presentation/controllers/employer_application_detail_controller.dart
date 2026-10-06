import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/employer_application_detail.dart';
import '../providers/employer_application_detail_providers.dart';

/// One instance per application id (`.family`), matching
/// `ActivityDetailController`'s own pattern for the same reason: navigating
/// between two different applications' detail screens must not share or
/// clobber state.
class EmployerApplicationDetailController extends AsyncNotifier<EmployerApplicationDetail> {
  EmployerApplicationDetailController(this.applicationId);

  final int applicationId;

  @override
  Future<EmployerApplicationDetail> build() async {
    final result = await ref.read(employerApplicationDetailRepositoryProvider).getApplicationDetail(applicationId);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  /// The server's own success message ("The candidate has been notified by
  /// email.") only exists as a Django flash message on the next HTML
  /// render, which this client doesn't scrape — the screen shows its own
  /// confirmation on [Success] instead.
  Future<Result<void>> updateStatus({required String status, required String employerNotes}) async {
    final result = await ref
        .read(employerApplicationDetailRepositoryProvider)
        .updateStatus(applicationId: applicationId, status: status, employerNotes: employerNotes);
    if (result is Success) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }
}

final employerApplicationDetailControllerProvider =
    AsyncNotifierProvider.family<EmployerApplicationDetailController, EmployerApplicationDetail, int>(
      EmployerApplicationDetailController.new,
      retry: (retryCount, error) => null,
    );
