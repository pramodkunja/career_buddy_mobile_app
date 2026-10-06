import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/employer_dashboard_remote_datasource.dart';
import '../../data/employer_dashboard_repository_impl.dart';
import '../../domain/entities/employer_dashboard_summary.dart';
import '../../domain/repositories/employer_dashboard_repository.dart';
import '../controllers/employer_dashboard_controller.dart';

final employerDashboardRemoteDataSourceProvider = Provider<EmployerDashboardRemoteDataSource>((ref) {
  return EmployerDashboardRemoteDataSource(ref.watch(apiClientProvider));
});

final employerDashboardRepositoryProvider = Provider<EmployerDashboardRepository>((ref) {
  return EmployerDashboardRepositoryImpl(ref.watch(employerDashboardRemoteDataSourceProvider));
});

final employerDashboardControllerProvider =
    AsyncNotifierProvider<EmployerDashboardController, EmployerDashboardSummary>(
      EmployerDashboardController.new,
      // Same reasoning as `dashboardControllerProvider`: a single attempt
      // with our own explicit Retry button, not Riverpod's silent
      // backoff-retry loop.
      retry: (retryCount, error) => null,
    );
