import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/activity_detail.dart';
import '../providers/activities_providers.dart';

/// One instance per activity id (`.family`), so navigating between two
/// activity detail screens doesn't share or clobber state.
class ActivityDetailController extends AsyncNotifier<ActivityDetail> {
  ActivityDetailController(this.activityId);

  final int activityId;

  @override
  Future<ActivityDetail> build() async {
    final result = await ref.read(activitiesRepositoryProvider).getActivityDetail(activityId);
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

final activityDetailControllerProvider = AsyncNotifierProvider.family<ActivityDetailController, ActivityDetail, int>(
  ActivityDetailController.new,
  retry: (retryCount, error) => null,
);
