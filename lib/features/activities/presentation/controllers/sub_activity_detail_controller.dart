import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/sub_activity_detail.dart';
import '../providers/activities_providers.dart';

typedef SubActivityDetailKey = ({int activityId, int subActivityId});

/// One instance per `(activityId, subActivityId)` pair (`.family`) — keyed
/// on both, not just `subActivityId`, because the real web page this
/// scrapes lives at the composite URL
/// `/activities/{activity_pk}/sub/{sub_pk}/` (see
/// `RoutePaths.subActivityDetail`'s doc comment) and the fetch genuinely
/// needs both ids.
class SubActivityDetailController extends AsyncNotifier<SubActivityDetail> {
  SubActivityDetailController(this.key);

  final SubActivityDetailKey key;

  @override
  Future<SubActivityDetail> build() async {
    final result = await ref
        .read(activitiesRepositoryProvider)
        .getSubActivityDetail(key.activityId, key.subActivityId);
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

final subActivityDetailControllerProvider =
    AsyncNotifierProvider.family<SubActivityDetailController, SubActivityDetail, SubActivityDetailKey>(
      SubActivityDetailController.new,
      retry: (retryCount, error) => null,
    );
