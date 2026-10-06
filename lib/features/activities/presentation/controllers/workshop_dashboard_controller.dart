import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/activity_summary.dart';
import '../providers/activities_providers.dart';

/// W013 — Workshop Dashboard. Scrapes the real, dedicated
/// `/activities/workshop/` page directly (`ActivitiesRepository.
/// getWorkshopModules`) — see `ApiEndpoints.workshopDashboardHtml`'s doc
/// comment. This endpoint is unconditionally ungated
/// (`Activity.objects.filter(category='workshop', is_active=True)`, no
/// plan check at all), so every authenticated user sees all 3 workshop
/// cards, matching the real web page exactly — including Free Plan users,
/// who previously saw an empty dashboard here (see git history / the
/// now-stale `docs/W013_WORKSHOP_DASHBOARD.md` for that prior, confirmed
/// limitation: an earlier version of this controller reused the general
/// Activities list endpoint with a `category` filter, which silently
/// drops to a Free Plan user's fixed free-catalogue selection instead of
/// honoring `category` at all).
class WorkshopDashboardController extends AsyncNotifier<List<ActivitySummary>> {
  @override
  Future<List<ActivitySummary>> build() async {
    final result = await ref.read(activitiesRepositoryProvider).getWorkshopModules();
    return switch (result) {
      Success(value: final data) => data.activities,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final workshopDashboardControllerProvider = AsyncNotifierProvider<WorkshopDashboardController, List<ActivitySummary>>(
  WorkshopDashboardController.new,
  retry: (retryCount, error) => null,
);
