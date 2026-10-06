import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/dashboard_data.dart';
import '../providers/dashboard_providers.dart';

/// `AsyncValue`'s built-in loading/data/error triad already covers every
/// state this screen needs — unlike `AuthController`, there's no state
/// beyond "is the fetch in flight / did it succeed / did it fail", so a
/// custom sealed state would just duplicate what `AsyncNotifier` gives for
/// free (including retry/refresh support).
class DashboardController extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() async {
    final result = await ref.read(dashboardRepositoryProvider).getDashboard();
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

final dashboardControllerProvider = AsyncNotifierProvider<DashboardController, DashboardData>(
  DashboardController.new,
  // Riverpod retries a failed build() with backoff by default. That would
  // leave the screen showing a loading spinner — silently hiding the
  // failure — for however long the backoff takes, then finally surface the
  // error anyway. A single attempt with our own explicit Retry button gives
  // the user an honest, immediate error state instead.
  retry: (retryCount, error) => null,
);
