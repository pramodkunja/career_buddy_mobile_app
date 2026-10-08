import 'package:open_file_platform_interface/open_file_platform_interface.dart';

/// Stands in for `OpenFilePlatform.platform` so controller tests can drive
/// the exact [OpenResult] a real device would hand back (including the
/// `ResultType.noAppToOpen` case a real Android device returned — see
/// `ProtectedMediaDownloadController`'s doc comment) without a registered
/// platform channel. Written with `extends` (not `implements`), same as
/// `FakeVideoPlayerPlatform`, so it passes `PlatformInterface`'s token check
/// without needing a mock mixin.
class FakeOpenFilePlatform extends OpenFilePlatform {
  FakeOpenFilePlatform({OpenResult? result}) : result = result ?? OpenResult(type: ResultType.done, message: 'done');

  OpenResult result;
  String? lastFilePath;

  @override
  Future<OpenResult> open(
    String? filePath, {
    String? type,
    bool isIOSAppOpen = false,
    String linuxDesktopName = 'xdg',
    bool linuxUseGio = false,
    bool linuxByProcess = false,
  }) async {
    lastFilePath = filePath;
    return result;
  }
}
