import '../../../../core/utils/result.dart';
import '../entities/employer_dashboard_summary.dart';

abstract class EmployerDashboardRepository {
  Future<Result<EmployerDashboardSummary>> getDashboard();
  Future<Result<void>> deleteJob(int jobId);
}
