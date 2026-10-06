import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/activity_list_data.dart';
import '../../domain/entities/adjacent_activities.dart';
import '../providers/activities_providers.dart';

/// Derives the Previous/Next activity links
/// (`templates/activities/detail.html:152-164`) from the existing,
/// already-built activity-list endpoint (`ActivitiesRepository.
/// getActivityList`) — the web computes these from raw `Activity.order`
/// comparisons, which no API exposes, but that same ordering is exactly
/// what an unfiltered activity list already returns, so no new endpoint is
/// needed.
///
/// One instance per activity id (`.family`), matching
/// `ActivityDetailController`. Failures are swallowed into an empty
/// [AdjacentActivities] rather than surfaced as an error state — this is
/// supplementary navigation, not core screen content, so the rest of the
/// Activity Detail screen must not be blocked or show an error banner just
/// because this secondary fetch failed.
class AdjacentActivitiesController extends AsyncNotifier<AdjacentActivities> {
  AdjacentActivitiesController(this.activityId);

  final int activityId;

  @override
  Future<AdjacentActivities> build() async {
    final result = await ref.read(activitiesRepositoryProvider).getActivityList();
    return switch (result) {
      Success(value: final data) => _computeAdjacent(data),
      Failed() => const AdjacentActivities(),
    };
  }

  AdjacentActivities _computeAdjacent(ActivityListData data) {
    // A Free-Plan preview only ever returns that plan's 4-activity
    // catalogue (`activities/views.py:_activity_list_data`), not the full,
    // unfiltered `Activity.order` sequence the web's own prev/next
    // computation walks — so this can't be derived correctly for a
    // Free-Plan user. Showing nothing is safer than showing wrong
    // neighbors (see `docs/BACKEND_CONTRACT_activities.md`).
    if (data.isFreePreview) return const AdjacentActivities();

    final index = data.activities.indexWhere((a) => a.id == activityId);
    if (index == -1) return const AdjacentActivities();

    final previous = index > 0 ? data.activities[index - 1] : null;
    final next = index < data.activities.length - 1 ? data.activities[index + 1] : null;

    return AdjacentActivities(
      previous: previous == null ? null : AdjacentActivityRef(id: previous.id, title: previous.title),
      next: next == null ? null : AdjacentActivityRef(id: next.id, title: next.title),
    );
  }
}

final adjacentActivitiesControllerProvider =
    AsyncNotifierProvider.family<AdjacentActivitiesController, AdjacentActivities, int>(
      AdjacentActivitiesController.new,
      retry: (retryCount, error) => null,
    );
