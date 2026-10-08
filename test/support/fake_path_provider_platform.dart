import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Stands in for `PathProviderPlatform.instance` so download-controller
/// tests can exercise a real temp-directory write without a registered
/// platform channel. Written with `extends` (not `implements`), same as
/// `FakeVideoPlayerPlatform`, so it passes `PlatformInterface`'s token check
/// without needing a mock mixin.
class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.directory);

  final Directory directory;

  @override
  Future<String?> getTemporaryPath() async => directory.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory.path;
}
