import '../../../../core/utils/result.dart';
import '../entities/dashboard_data.dart';

abstract class DashboardRepository {
  Future<Result<DashboardData>> getDashboard();
}
