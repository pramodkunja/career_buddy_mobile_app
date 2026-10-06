import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/profile_data.dart';
import '../providers/auth_providers.dart';

/// Same reasoning as `DashboardController` — `AsyncValue`'s built-in
/// loading/data/error triad covers everything this screen needs.
class ProfileController extends AsyncNotifier<ProfileOverview> {
  @override
  Future<ProfileOverview> build() async {
    final result = await ref.read(profileRepositoryProvider).getProfile();
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, ProfileOverview>(
  ProfileController.new,
  retry: (retryCount, error) => null,
);
