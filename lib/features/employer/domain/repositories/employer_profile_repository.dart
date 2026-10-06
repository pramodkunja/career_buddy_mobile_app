import '../../../../core/utils/result.dart';
import '../entities/employer_profile_form.dart';

abstract class EmployerProfileRepository {
  Future<Result<EmployerProfileFormData>> getProfileForm({required bool isCreate});
  Future<Result<void>> updateProfile(EmployerProfileSubmission data, {required bool isCreate});
}
