import '../../../../core/utils/result.dart';
import '../entities/jam_history_profile.dart';

/// The "Profile"/"Danger Zone" screen's own repository seam — additive,
/// same reasoning as [JamHistoryRepository].
abstract class JamProfileRepository {
  /// `jam:profile` GET.
  Future<Result<JamProfile>> getProfile();

  /// `jam:profile` POST.
  Future<Result<void>> updateProfile(JamProfileUpdate data);

  /// `jam:reset_progress` — destructive; deletes every session.
  Future<Result<void>> resetProgress();
}
