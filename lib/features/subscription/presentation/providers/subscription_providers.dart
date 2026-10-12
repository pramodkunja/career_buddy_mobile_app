import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/subscription_remote_datasource.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../data/services/razorpay_checkout_launcher_impl.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/services/razorpay_checkout_launcher.dart';
import '../controllers/subscription_checkout_controller.dart';

final subscriptionRemoteDataSourceProvider = Provider<SubscriptionRemoteDataSource>((ref) {
  return SubscriptionRemoteDataSource(ref.watch(apiClientProvider));
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepositoryImpl(ref.watch(subscriptionRemoteDataSourceProvider));
});

/// A fresh launcher per build so each new checkout attempt (e.g. retrying
/// after a cancellation) gets its own `Razorpay` instance — overridden in
/// tests with a fake, never the real native plugin.
final razorpayCheckoutLauncherProvider = Provider<RazorpayCheckoutLauncher>((ref) {
  return RazorpayCheckoutLauncherImpl();
});

final subscriptionCheckoutControllerProvider = NotifierProvider<SubscriptionCheckoutController, CheckoutState>(
  SubscriptionCheckoutController.new,
);
