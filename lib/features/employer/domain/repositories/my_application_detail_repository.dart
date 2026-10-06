import '../../../../core/utils/result.dart';
import '../entities/my_application_detail.dart';

abstract class MyApplicationDetailRepository {
  Future<Result<MyApplicationDetail>> getApplicationDetail(int applicationId);
}
