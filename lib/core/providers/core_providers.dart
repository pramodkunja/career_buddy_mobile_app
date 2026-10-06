import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';

/// [ApiClient] construction is async (it needs a filesystem directory for
/// the cookie jar), so it's created once in `main()` and injected here via
/// `ProviderScope(overrides: ...)` rather than every feature awaiting a
/// [FutureProvider].
final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('apiClientProvider must be overridden in main()');
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
