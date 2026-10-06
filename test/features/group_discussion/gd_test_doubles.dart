import 'dart:async';

import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_report.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_session_summary.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_started_session.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_ws_event.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/repositories/gd_repository.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/services/gd_realtime_service.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/services/gd_speech_service.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/services/gd_tts_service.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/controllers/gd_session_controller.dart';

/// Shared test doubles for Group Discussion widget tests — same reasoning
/// as `grammar_test_doubles.dart`: one place for the fakes every screen
/// test needs to satisfy `GdSessionController.build()`'s real dependencies
/// without touching a real socket, recognizer, or TTS engine.
class FakeGdRealtimeService implements GdRealtimeService {
  final eventsController = StreamController<GdWsEvent>.broadcast();
  final statusController = StreamController<GdConnectionStatus>.broadcast();
  final List<Map<String, dynamic>> sentActions = [];
  int connectCallCount = 0;

  @override
  Stream<GdWsEvent> get events => eventsController.stream;

  @override
  Stream<GdConnectionStatus> get connectionStatus => statusController.stream;

  @override
  Future<void> connect({required Uri uri, required String cookieHeader}) async {
    connectCallCount++;
  }

  @override
  void sendStart({String language = 'english'}) => sentActions.add({'action': 'start'});

  @override
  void sendUserSpeaking() => sentActions.add({'action': 'user_speaking'});

  @override
  void sendUserMessage(String content, {String language = 'english'}) =>
      sentActions.add({'action': 'user_message', 'content': content});

  @override
  void sendEnd() => sentActions.add({'action': 'end'});

  @override
  Future<void> disconnect() async {}
}

class FakeGdSpeechService implements GdSpeechService {
  bool initializeResult = true;
  bool _listening = false;

  @override
  Future<bool> initialize() async => initializeResult;

  @override
  bool get isListening => _listening;

  @override
  Future<void> startListening({
    required void Function(String) onPartialResult,
    required void Function(String) onFinalResult,
  }) async {
    _listening = true;
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }
}

class FakeGdTtsService implements GdTtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}

  @override
  void setOnComplete(void Function() callback) {}
}

class FakeGdRepository implements GdRepository {
  FakeGdRepository({this.createResult, Result<List<GdSessionSummary>>? sessionsResult, this.reportResult})
    : sessionsResult = sessionsResult ?? const Success(<GdSessionSummary>[]);

  Result<GdStartedSession>? createResult;
  int createCallCount = 0;

  /// Batch 10 — defaults to an empty history (same as this fake's
  /// pre-Batch-10 hardcoded behavior, so every existing call site that
  /// never set this keeps working unchanged).
  Result<List<GdSessionSummary>> sessionsResult;

  /// Batch 10 — defaults to `Success(null)` ("no report yet"), same as
  /// this fake's pre-Batch-10 hardcoded behavior.
  Result<GdReport?>? reportResult;
  final List<int> reportRequestedFor = [];

  @override
  Future<Result<GdStartedSession>> createSession(String topic) async {
    createCallCount++;
    return createResult!;
  }

  @override
  Future<Result<List<GdSessionSummary>>> getSessions() async => sessionsResult;

  @override
  Future<Result<GdReport?>> getSessionReport(int sessionId) async {
    reportRequestedFor.add(sessionId);
    return reportResult ?? const Success(null);
  }
}

/// A `GdSessionController` that still runs the real `build()` (so its
/// `_realtime`/`_speech`/`_tts` fields are genuinely wired to whatever
/// fakes are overridden in the same `ProviderScope`), but starts from
/// [initial] instead of always `GdIdle` — lets a screen test render any
/// state in the state machine directly, the same "fixed controller"
/// pattern `JamTopicsScreen`'s own tests use.
class FixedGdSessionController extends GdSessionController {
  FixedGdSessionController(this.initial);
  final GdState initial;

  @override
  GdState build() {
    super.build();
    return initial;
  }
}
