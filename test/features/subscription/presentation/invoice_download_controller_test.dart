import 'dart:io';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/payment_verification_result.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/razorpay_order.dart';
import 'package:career_buddy_lms/features/subscription/domain/entities/subscription_status.dart';
import 'package:career_buddy_lms/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:career_buddy_lms/features/subscription/presentation/controllers/invoice_download_controller.dart';
import 'package:career_buddy_lms/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file_platform_interface/open_file_platform_interface.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../support/fake_open_file_platform.dart';
import '../../../support/fake_path_provider_platform.dart';

class _FakeSubscriptionRepository implements SubscriptionRepository {
  _FakeSubscriptionRepository({required this.downloadResult});

  Result<List<int>> downloadResult;

  @override
  Future<Result<List<int>>> downloadInvoice(int paymentId) async => downloadResult;

  @override
  Future<Result<SubscriptionStatus>> getStatus() async => throw UnimplementedError();

  @override
  Future<Result<RazorpayOrder>> createOrder(String planType) async =>
      throw UnimplementedError();

  @override
  Future<Result<PaymentVerificationResult>> verifyPayment({
    required String planType,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async => throw UnimplementedError();
}

void main() {
  late Directory tempDir;
  final originalOpenFile = OpenFilePlatform.platform;
  final originalPathProvider = PathProviderPlatform.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('invoice_download_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  tearDown(() async {
    OpenFilePlatform.platform = originalOpenFile;
    PathProviderPlatform.instance = originalPathProvider;
    await tempDir.delete(recursive: true);
  });

  ProviderContainer buildContainer(Result<List<int>> downloadResult) {
    final repo = _FakeSubscriptionRepository(downloadResult: downloadResult);
    final container = ProviderContainer(
      overrides: [subscriptionRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('InvoiceDownloadController.downloadAndOpen', () {
    test('downloads bytes, writes html file, and opens it', () async {
      final fakeOpenFile = FakeOpenFilePlatform(
        result: OpenResult(type: ResultType.done, message: 'done'),
      );
      OpenFilePlatform.platform = fakeOpenFile;
      final bytes = '<html>invoice</html>'.codeUnits;
      final container = buildContainer(Success(bytes));

      await container
          .read(invoiceDownloadControllerProvider(42).notifier)
          .downloadAndOpen('CB/2026-27/00042');

      expect(
        container.read(invoiceDownloadControllerProvider(42)),
        isA<InvoiceDownloadIdle>(),
      );
      // Slashes sanitized to dashes.
      expect(fakeOpenFile.lastFilePath, '${tempDir.path}/invoice_CB-2026-27-00042.html');
      expect(
        await File('${tempDir.path}/invoice_CB-2026-27-00042.html').readAsString(),
        '<html>invoice</html>',
      );
    });

    test('transitions through downloading → idle on success', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform(
        result: OpenResult(type: ResultType.done, message: 'done'),
      );
      final container = buildContainer(Success('<html/>'.codeUnits));

      final notifier = container.read(invoiceDownloadControllerProvider(1).notifier);
      final downloadFuture = notifier.downloadAndOpen('CB/2026-27/00001');

      expect(container.read(invoiceDownloadControllerProvider(1)), isA<InvoiceDownloading>());
      await downloadFuture;
      expect(container.read(invoiceDownloadControllerProvider(1)), isA<InvoiceDownloadIdle>());
    });

    test('sets InvoiceDownloadFailed on a repository failure', () async {
      final container = buildContainer(const Failed(NetworkFailure()));

      await container
          .read(invoiceDownloadControllerProvider(99).notifier)
          .downloadAndOpen('CB/2026-27/00099');

      expect(
        container.read(invoiceDownloadControllerProvider(99)),
        isA<InvoiceDownloadFailed>(),
      );
    });

    test('sets InvoiceDownloadFailed with specific message when no app can open the file', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform(
        result: OpenResult(type: ResultType.noAppToOpen, message: 'No APP found'),
      );
      final container = buildContainer(Success('<html/>'.codeUnits));

      await container
          .read(invoiceDownloadControllerProvider(5).notifier)
          .downloadAndOpen('CB/2026-27/00005');

      final state = container.read(invoiceDownloadControllerProvider(5));
      expect(state, isA<InvoiceDownloadFailed>());
      expect(
        (state as InvoiceDownloadFailed).failure.message,
        contains('No app installed'),
      );
    });

    test('different payment ids have independent states', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform(
        result: OpenResult(type: ResultType.done, message: 'done'),
      );
      final container = buildContainer(Success('<html/>'.codeUnits));

      // Start download for id=1, leave id=2 idle.
      final f1 = container
          .read(invoiceDownloadControllerProvider(1).notifier)
          .downloadAndOpen('CB/2026-27/00001');

      expect(container.read(invoiceDownloadControllerProvider(1)), isA<InvoiceDownloading>());
      expect(container.read(invoiceDownloadControllerProvider(2)), isA<InvoiceDownloadIdle>());
      await f1;
    });

    test('retry: calling downloadAndOpen again after failure succeeds when the repository is fixed', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform(
        result: OpenResult(type: ResultType.done, message: 'done'),
      );
      final repo = _FakeSubscriptionRepository(downloadResult: const Failed(NetworkFailure()));
      final container = ProviderContainer(
        overrides: [subscriptionRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(invoiceDownloadControllerProvider(10).notifier);

      // First attempt fails.
      await notifier.downloadAndOpen('CB/2026-27/00010');
      expect(container.read(invoiceDownloadControllerProvider(10)), isA<InvoiceDownloadFailed>());

      // Fix the repository, then retry — should recover to idle.
      repo.downloadResult = Success('<html>invoice</html>'.codeUnits);
      await notifier.downloadAndOpen('CB/2026-27/00010');
      expect(container.read(invoiceDownloadControllerProvider(10)), isA<InvoiceDownloadIdle>());
    });

    test('empty invoice number falls back to payment-id for the saved filename', () async {
      final fakeOpenFile = FakeOpenFilePlatform(
        result: OpenResult(type: ResultType.done, message: 'done'),
      );
      OpenFilePlatform.platform = fakeOpenFile;
      final bytes = '<html>invoice</html>'.codeUnits;
      final container = buildContainer(Success(bytes));

      await container
          .read(invoiceDownloadControllerProvider(99).notifier)
          .downloadAndOpen(''); // empty invoice number

      expect(container.read(invoiceDownloadControllerProvider(99)), isA<InvoiceDownloadIdle>());
      // When invoice number is empty, the controller falls back to payment-<id>.
      expect(fakeOpenFile.lastFilePath, '${tempDir.path}/invoice_payment-99.html');
    });

    test('permissionDenied open result surfaces as InvoiceDownloadFailed with a clear message', () async {
      OpenFilePlatform.platform = FakeOpenFilePlatform(
        result: OpenResult(type: ResultType.permissionDenied, message: 'Permission denied'),
      );
      final container = buildContainer(Success('<html/>'.codeUnits));

      await container
          .read(invoiceDownloadControllerProvider(7).notifier)
          .downloadAndOpen('CB/2026-27/00007');

      final state = container.read(invoiceDownloadControllerProvider(7));
      expect(state, isA<InvoiceDownloadFailed>());
      expect((state as InvoiceDownloadFailed).failure.message, contains('Permission denied'));
    });
  });
}
