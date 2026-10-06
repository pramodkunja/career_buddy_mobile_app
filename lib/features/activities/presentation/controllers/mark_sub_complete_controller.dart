import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../providers/activities_providers.dart';
import 'sub_activity_detail_controller.dart';

sealed class MarkCompleteState {
  const MarkCompleteState();
}

final class MarkCompleteIdle extends MarkCompleteState {
  const MarkCompleteIdle();
}

final class MarkCompleteSubmitting extends MarkCompleteState {
  const MarkCompleteSubmitting();
}

final class MarkCompleteFailed extends MarkCompleteState {
  const MarkCompleteFailed(this.failure);
  final Failure failure;
}

/// Drives the web's "Mark Complete" form
/// (`templates/activities/sub_activity.html:157-179`). This controller
/// only tracks the submit action's own transient state — whether the
/// sub-activity IS now completed is never guessed client-side; on success
/// it invalidates `SubActivityDetailController`, so the screen's "completed"
/// UI only ever appears once the server's own next GET confirms it.
class MarkSubCompleteController extends Notifier<MarkCompleteState> {
  MarkSubCompleteController(this.key);

  final SubActivityDetailKey key;

  @override
  MarkCompleteState build() => const MarkCompleteIdle();

  Future<void> submit() async {
    if (state is MarkCompleteSubmitting) return;
    state = const MarkCompleteSubmitting();
    final result = await ref.read(activitiesRepositoryProvider).markSubComplete(key.subActivityId);
    switch (result) {
      case Success():
        state = const MarkCompleteIdle();
        ref.invalidate(subActivityDetailControllerProvider(key));
      case Failed(failure: final failure):
        state = MarkCompleteFailed(failure);
    }
  }
}

final markSubCompleteControllerProvider =
    NotifierProvider.family<MarkSubCompleteController, MarkCompleteState, SubActivityDetailKey>(
      MarkSubCompleteController.new,
    );
