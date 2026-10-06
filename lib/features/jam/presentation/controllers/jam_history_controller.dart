import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/jam_history_profile.dart';
import '../providers/jam_providers.dart';

class JamHistoryController extends AsyncNotifier<JamHistoryPage> {
  @override
  Future<JamHistoryPage> build() async {
    final result = await ref.read(jamHistoryRepositoryProvider).getHistoryPage();
    return switch (result) {
      Success(value: final data) => data,
      Failed(failure: final failure) => throw failure,
    };
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Result<void>> deleteSession(int sessionId) async {
    final result = await ref.read(jamHistoryRepositoryProvider).deleteSession(sessionId);
    if (result is Success) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }

  Future<Result<void>> deleteAssessment(int assessmentId) async {
    final result = await ref.read(jamHistoryRepositoryProvider).deleteAssessment(assessmentId);
    if (result is Success) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }
}

final jamHistoryControllerProvider = AsyncNotifierProvider<JamHistoryController, JamHistoryPage>(
  JamHistoryController.new,
  retry: (retryCount, error) => null,
);
