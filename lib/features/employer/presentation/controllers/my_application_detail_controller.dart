import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/my_application_detail.dart';
import '../providers/my_application_detail_providers.dart';

/// One instance per application id (`.family`).
class MyApplicationDetailController extends AsyncNotifier<MyApplicationDetail> {
  MyApplicationDetailController(this.applicationId);

  final int applicationId;

  @override
  Future<MyApplicationDetail> build() async {
    final result = await ref.read(myApplicationDetailRepositoryProvider).getApplicationDetail(applicationId);
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

final myApplicationDetailControllerProvider =
    AsyncNotifierProvider.family<MyApplicationDetailController, MyApplicationDetail, int>(
      MyApplicationDetailController.new,
      retry: (retryCount, error) => null,
    );
