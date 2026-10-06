import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/resume_history_item.dart';
import '../providers/resume_providers.dart';

/// `AsyncNotifier`, same reasoning as `EmployerDashboardController`/
/// `DashboardController` — nothing here needs a bespoke state machine
/// beyond loading/data/error/retry.
class ResumeHistoryController extends AsyncNotifier<List<ResumeHistoryItem>> {
  @override
  Future<List<ResumeHistoryItem>> build() async {
    final result = await ref.read(resumeRepositoryProvider).getHistory();
    return switch (result) {
      Success(value: final items) => items,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}
