import '../../../../core/utils/result.dart';
import '../entities/employer_all_applications.dart';

abstract class EmployerAllApplicationsRepository {
  Future<Result<EmployerAllApplicationsPage>> getApplications({
    String query = '',
    String statusFilter = '',
    String sourceFilter = '',
  });
}
