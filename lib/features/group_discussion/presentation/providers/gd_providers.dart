/// Group Discussion. Ported from `GD_app` (read in full: `GD_app/urls.py`,
/// `views.py`, `models.py`, `agents.py`, `consumers.py`, `routing.py`, and
/// `business_english_lms/asgi.py`; `templates/GD_app/*.html` and
/// `GD_app/static/GD_app/js/gd.js` for the real client-side turn-taking/TTS/
/// STT UX this feature reproduces on-device). See `ApiEndpoints`'s Group
/// Discussion doc comments for the exact confirmed HTTP contracts, and
/// `GdRealtimeService`/`GdWebSocketService` for the WebSocket protocol.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/gd_remote_datasource.dart';
import '../../data/gd_repository_impl.dart';
import '../../data/gd_speech_service_impl.dart';
import '../../data/gd_tts_service_impl.dart';
import '../../data/gd_websocket_service.dart';
import '../../domain/repositories/gd_repository.dart';
import '../../domain/services/gd_realtime_service.dart';
import '../../domain/services/gd_speech_service.dart';
import '../../domain/services/gd_tts_service.dart';
import '../controllers/gd_session_controller.dart';

final gdRemoteDataSourceProvider = Provider<GdRemoteDataSource>((ref) {
  return GdRemoteDataSource(ref.watch(apiClientProvider));
});

final gdRepositoryProvider = Provider<GdRepository>((ref) {
  return GdRepositoryImpl(ref.watch(gdRemoteDataSourceProvider));
});

/// A new instance per read/session — same reasoning as
/// `jamAudioRecorderServiceProvider`: this holds real connection state
/// (the open socket), so it must not be shared/reused across sessions.
final gdRealtimeServiceProvider = Provider<GdRealtimeService>((ref) {
  final service = GdWebSocketService();
  ref.onDispose(service.dispose);
  return service;
});

final gdSpeechServiceProvider = Provider<GdSpeechService>((ref) {
  return GdSpeechServiceImpl();
});

final gdTtsServiceProvider = Provider<GdTtsService>((ref) {
  return GdTtsServiceImpl();
});

final gdSessionControllerProvider = NotifierProvider<GdSessionController, GdState>(GdSessionController.new);
