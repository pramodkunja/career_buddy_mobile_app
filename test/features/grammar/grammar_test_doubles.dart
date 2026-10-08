import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/student_registration_data.dart';
import 'package:career_buddy_lms/features/auth/domain/repositories/auth_repository.dart';
import 'package:career_buddy_lms/features/grammar/data/grammar_media_datasource.dart';
import 'package:career_buddy_lms/features/grammar/domain/services/grammar_tts_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Shared test doubles for the Grammar detail screen + media viewer widget
/// tests. Not itself a `_test.dart` file, so `flutter test` never picks it
/// up as a suite on its own.
class FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> restoreSession() async => const AuthUser(username: 'demo');

  @override
  Future<Result<AuthUser>> login({required String usernameOrEmail, required String password}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> logout() async => const Success(null);

  @override
  Future<Result<String>> sendOtp(String email) async => throw UnimplementedError();

  @override
  Future<Result<String>> verifyOtp({required String email, required String code}) async =>
      throw UnimplementedError();

  @override
  Future<Result<AuthUser>> register(StudentRegistrationData data) async => throw UnimplementedError();
}

/// A [GrammarMediaDataSource] whose two fetches are fully test-controlled:
/// by default they resolve immediately, but setting [slideImageGate] /
/// [videoGate] lets a test hold the returned future open to assert a
/// loading state before releasing it.
class FakeGrammarMediaDataSource extends GrammarMediaDataSource {
  FakeGrammarMediaDataSource() : super(ApiClient.forTesting(Dio()));

  /// A real, valid 1x1 transparent PNG — `Image.memory` decodes this
  /// eagerly, so arbitrary placeholder bytes throw an "Invalid image data"
  /// decode error inside the widget tree.
  static final Uint8List _validPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  final List<String> requestedSlideFileNames = [];
  Uint8List slideImageBytes = _validPngBytes;
  Completer<void>? slideImageGate;

  @override
  Future<Uint8List> fetchSlideImage(String slug, String fileName) async {
    requestedSlideFileNames.add(fileName);
    final gate = slideImageGate;
    if (gate != null) await gate.future;
    return slideImageBytes;
  }

  String videoPath = '/tmp/fake_grammar_video.mp4';
  Completer<void>? videoGate;
  int fetchVideoCallCount = 0;

  @override
  Future<String> fetchVideoToTempFile(String slug) async {
    fetchVideoCallCount++;
    final gate = videoGate;
    if (gate != null) await gate.future;
    return videoPath;
  }

  /// `null` (the default) simulates a fetch failure (e.g. unauthenticated,
  /// or any server error) — tests asserting graceful degradation (no
  /// illustration shown, no crash, no visible error) should leave this
  /// unset rather than return an empty string, which would never actually
  /// happen on a real failure (an exception, not an empty 200).
  String? illustrationSvg = '<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';
  final List<({String slug, int index})> requestedIllustrations = [];

  @override
  Future<String> fetchIllustrationSvg(String slug, int index) async {
    requestedIllustrations.add((slug: slug, index: index));
    final svg = illustrationSvg;
    if (svg == null) throw const UnexpectedResponseException();
    return svg;
  }
}

/// A [GrammarTtsService] that records what it was asked to speak, without
/// touching any real platform channel.
class FakeGrammarTtsService implements GrammarTtsService {
  final List<String> spokenTexts = [];
  int stopCallCount = 0;
  void Function()? onCompleteCallback;

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  @override
  void setOnComplete(void Function() callback) {
    onCompleteCallback = callback;
  }
}

/// A minimal [VideoPlayerPlatform] fake so `video_player` widgets can be
/// exercised under `flutter test` without a real platform channel — the
/// plugin ships no such fake for app-level tests. Emits a single
/// `initialized` event right after `createWithOptions` so
/// `VideoPlayerController.initialize()` (which awaits exactly that event)
/// resolves.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextId = 0;
  final Map<int, StreamController<VideoEvent>> _controllers = {};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    final controller = StreamController<VideoEvent>();
    _controllers[id] = controller;
    scheduleMicrotask(() {
      controller.add(
        VideoEvent(eventType: VideoEventType.initialized, duration: const Duration(seconds: 10), size: const Size(640, 360)),
      );
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _controllers[playerId]!.stream;

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.shrink();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> dispose(int playerId) async {
    await _controllers.remove(playerId)?.close();
  }
}
