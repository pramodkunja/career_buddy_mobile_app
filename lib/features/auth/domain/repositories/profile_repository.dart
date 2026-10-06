import '../../../../core/utils/result.dart';
import '../entities/profile_data.dart';

abstract interface class ProfileRepository {
  Future<Result<ProfileOverview>> getProfile();
  Future<Result<void>> updateProfile(ProfileEditData data);
}
