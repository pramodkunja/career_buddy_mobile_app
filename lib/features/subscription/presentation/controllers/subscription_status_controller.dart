import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/subscription_status.dart';
import '../providers/subscription_providers.dart';

class SubscriptionStatusController extends AsyncNotifier<SubscriptionStatus> {
  @override
  Future<SubscriptionStatus> build() async {
    final result = await ref.read(subscriptionRepositoryProvider).getStatus();
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

final subscriptionStatusControllerProvider =
    AsyncNotifierProvider<SubscriptionStatusController, SubscriptionStatus>(
      SubscriptionStatusController.new,
      // Disable automatic retries so a network failure goes straight to
      // AsyncError — same pattern as ProfileController.
      retry: (retryCount, error) => null,
    );
