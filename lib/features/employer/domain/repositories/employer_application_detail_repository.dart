import '../../../../core/utils/result.dart';
import '../entities/employer_application_detail.dart';

abstract interface class EmployerApplicationDetailRepository {
  Future<Result<EmployerApplicationDetail>> getApplicationDetail(int applicationId);

  Future<Result<void>> updateStatus({
    required int applicationId,
    required String status,
    required String employerNotes,
  });
}
