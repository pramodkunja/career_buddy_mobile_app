import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/employer_job_applications.dart';
import '../providers/employer_job_applications_providers.dart';

/// One instance per job id (`.family`), matching
/// `EmployerApplicationDetailController`'s own pattern. [statusFilter]
/// mirrors the web's own `?status=` query param — set it to refetch
/// server-side filtered, same as clicking one of the web's status-filter
/// pills.
class EmployerJobApplicationsController extends AsyncNotifier<EmployerJobApplicationsPage> {
  EmployerJobApplicationsController(this.jobId);

  final int jobId;
  String _statusFilter = '';
  String get statusFilter => _statusFilter;

  @override
  Future<EmployerJobApplicationsPage> build() async {
    final result = await ref
        .read(employerJobApplicationsRepositoryProvider)
        .getApplications(jobId, statusFilter: _statusFilter);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> setStatusFilter(String statusFilter) async {
    if (_statusFilter == statusFilter) return;
    _statusFilter = statusFilter;
    ref.invalidateSelf();
    await future;
  }
}

final employerJobApplicationsControllerProvider =
    AsyncNotifierProvider.family<EmployerJobApplicationsController, EmployerJobApplicationsPage, int>(
      EmployerJobApplicationsController.new,
      retry: (retryCount, error) => null,
    );
