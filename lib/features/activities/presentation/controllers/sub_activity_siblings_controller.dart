import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/sub_activity_summary.dart';
import '../providers/activities_providers.dart';

/// The current sub-activity's siblings (every sub-activity of the same
/// parent activity, in order) — used to derive the web's "Sub-Activity X
/// of Y" header, Previous/Next navigation, and the sidebar sub-navigation
/// list (`templates/activities/sub_activity.html:73,188-224`), none of
/// which `sub_activity_detail_api` exposes directly (see
/// `docs/BACKEND_CONTRACT_activities.md`).
///
/// Derived from the existing `ActivitiesRepository.getActivityDetail`
/// (the same endpoint the Activity Detail screen already uses), not a new
/// endpoint. One instance per **activity** id (`.family`) — reused as-is
/// when the user moves between sibling sub-activities via Previous/Next,
/// since they all share the same parent.
///
/// Failures are swallowed into an empty list rather than surfaced as an
/// error — this is supplementary navigation, not core screen content (see
/// `AdjacentActivitiesController`, the same pattern on Activity Detail).
class SubActivitySiblingsController extends AsyncNotifier<List<SubActivitySummary>> {
  SubActivitySiblingsController(this.activityId);

  final int activityId;

  @override
  Future<List<SubActivitySummary>> build() async {
    final result = await ref.read(activitiesRepositoryProvider).getActivityDetail(activityId);
    return switch (result) {
      Success(value: final data) => data.subActivities,
      Failed() => const [],
    };
  }
}

final subActivitySiblingsControllerProvider =
    AsyncNotifierProvider.family<SubActivitySiblingsController, List<SubActivitySummary>, int>(
      SubActivitySiblingsController.new,
      retry: (retryCount, error) => null,
    );
