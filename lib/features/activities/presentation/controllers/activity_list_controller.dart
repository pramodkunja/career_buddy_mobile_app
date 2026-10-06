import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/activity_list_data.dart';
import '../providers/activities_providers.dart';

/// Loads the activity list for the current category filter. The filter
/// lives on the controller itself (not as a separate provider argument),
/// since there's only ever one activity list screen at a time — no need
/// for `.family`-style per-argument caching here (contrast with the
/// detail/sub-activity controllers, which do use `.family`).
class ActivityListController extends AsyncNotifier<ActivityListData> {
  String? _category;

  @override
  Future<ActivityListData> build() async {
    final result = await ref.read(activitiesRepositoryProvider).getActivityList(category: _category);
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  /// Pass `null` or `''` for "All".
  Future<void> filterByCategory(String? category) async {
    _category = (category == null || category.isEmpty) ? null : category;
    ref.invalidateSelf();
    await future;
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final activityListControllerProvider = AsyncNotifierProvider<ActivityListController, ActivityListData>(
  ActivityListController.new,
  // See DashboardController for why: a single deliberate attempt with an
  // explicit Retry action beats Riverpod's default backoff-retry, which
  // would hide a real failure behind an extended spinner.
  retry: (retryCount, error) => null,
);
