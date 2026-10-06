import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/employer_all_applications.dart';
import '../providers/employer_all_applications_providers.dart';

/// Mirrors the web's own `?q=`/`?status=`/`?source=` query params.
class EmployerAllApplicationsController extends AsyncNotifier<EmployerAllApplicationsPage> {
  String _query = '';
  String _statusFilter = '';
  String _sourceFilter = '';

  String get query => _query;
  String get statusFilter => _statusFilter;
  String get sourceFilter => _sourceFilter;

  @override
  Future<EmployerAllApplicationsPage> build() async {
    final result = await ref
        .read(employerAllApplicationsRepositoryProvider)
        .getApplications(query: _query, statusFilter: _statusFilter, sourceFilter: _sourceFilter);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> applyFilters({required String query, required String statusFilter, required String sourceFilter}) async {
    if (_query == query && _statusFilter == statusFilter && _sourceFilter == sourceFilter) return;
    _query = query;
    _statusFilter = statusFilter;
    _sourceFilter = sourceFilter;
    ref.invalidateSelf();
    await future;
  }
}

final employerAllApplicationsControllerProvider =
    AsyncNotifierProvider<EmployerAllApplicationsController, EmployerAllApplicationsPage>(
      EmployerAllApplicationsController.new,
      retry: (retryCount, error) => null,
    );
