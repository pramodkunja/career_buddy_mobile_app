import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/jam_history_profile.dart';
import '../providers/jam_providers.dart';

class JamProfileController extends AsyncNotifier<JamProfile> {
  @override
  Future<JamProfile> build() async {
    final result = await ref.read(jamProfileRepositoryProvider).getProfile();
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Result<void>> updateProfile(JamProfileUpdate data) async {
    final result = await ref.read(jamProfileRepositoryProvider).updateProfile(data);
    if (result is Success) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }

  /// Destructive — the screen is responsible for confirming with the user
  /// first (web wording: "Are you sure you want to reset all your
  /// progress?").
  Future<Result<void>> resetProgress() async {
    final result = await ref.read(jamProfileRepositoryProvider).resetProgress();
    if (result is Success) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }
}

final jamProfileControllerProvider = AsyncNotifierProvider<JamProfileController, JamProfile>(
  JamProfileController.new,
  retry: (retryCount, error) => null,
);
