import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/environment.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/gd_message.dart';
import '../../domain/entities/gd_report.dart';
import '../../domain/entities/gd_started_session.dart';
import '../../domain/entities/gd_ws_event.dart';
import '../../domain/gd_websocket_url.dart';
import '../../domain/services/gd_realtime_service.dart';
import '../../domain/services/gd_speech_service.dart';
import '../../domain/services/gd_tts_service.dart';
import '../providers/gd_providers.dart';

/// Real flow (`GD_app`, read in full — `views.py`/`consumers.py`/`agents.py`/
/// `gd.js`): pick a topic → `create_session` (HTTP) → connect the WebSocket
/// → send `action: 'start'` → the 3 AI agents (Alex/Maya/Rishi) take turns
/// automatically, each turn TTS'd aloud, until the user presses the mic
/// (`action: 'user_speaking'`, pausing the agents) and speaks their own turn
/// (captured on-device via `GdSpeechService`, sent as `action: 'user_message'`
/// once they're done, which resumes the agent loop) → `action: 'end'` →
/// server sends the final `report` event.
///
/// One deliberate deviation from `gd.js`'s own reconnect behavior
/// (`connectWS`'s `onclose` → `setTimeout(connectWS, 2000)`): that reconnect
/// only reopens the socket and never resends `start` itself (the user would
/// have to notice and press "Start" again, which — since `_start_discussion`
/// has no re-entrancy guard server-side — would reset `current_agent_index`
/// to 0 and post a brand new "Welcome everyone..." opening line, effectively
/// restarting the discussion from the top). This controller instead tracks
/// that `start` was already sent once per session and, on [reconnect], only
/// re-opens the socket and resumes showing the transcript already gathered —
/// never re-sends `start` — so a transient drop can't silently reset an
/// otherwise in-progress discussion. See [GdConnectionLost].
sealed class GdState {
  const GdState();
}

/// Before [GdSessionController.startDiscussion] has been called.
final class GdIdle extends GdState {
  const GdIdle();
}

final class GdCreatingSession extends GdState {
  const GdCreatingSession();
}

final class GdCreateFailed extends GdState {
  const GdCreateFailed(this.failure);
  final Failure failure;
}

final class GdConnectingSocket extends GdState {
  const GdConnectingSocket(this.session);
  final GdStartedSession session;
}

enum GdMicState { idle, listening }

/// The live discussion — transcript so far, whether an agent is currently
/// "typing" (about to speak), the user's own mic/STT state, and a live
/// (not-yet-sent) partial transcript of what the user is currently saying.
final class GdLive extends GdState {
  const GdLive({
    required this.session,
    required this.messages,
    required this.typingSpeaker,
    required this.micState,
    this.livePartialText = '',
    this.sttError,
  });

  final GdStartedSession session;
  final List<GdMessage> messages;
  final GdTypingEvent? typingSpeaker;
  final GdMicState micState;
  final String livePartialText;
  final String? sttError;
}

/// `action: 'end'` was sent; waiting for the `report` event
/// (`status: 'analyzing'` was received in between).
final class GdEnding extends GdState {
  const GdEnding({required this.session, required this.messages});
  final GdStartedSession session;
  final List<GdMessage> messages;
}

/// The socket closed/errored without this client having asked for that —
/// see this file's own doc comment for why [GdSessionController.reconnect]
/// does not resend `start`.
final class GdConnectionLost extends GdState {
  const GdConnectionLost({required this.session, required this.messages});
  final GdStartedSession session;
  final List<GdMessage> messages;
}

final class GdReportReady extends GdState {
  const GdReportReady(this.report);
  final GdReport report;
}

class GdSessionController extends Notifier<GdState> {
  late final GdRealtimeService _realtime;
  late final GdSpeechService _speech;
  late final GdTtsService _tts;
  StreamSubscription<GdWsEvent>? _eventsSub;
  StreamSubscription<GdConnectionStatus>? _statusSub;
  bool _sentStart = false;
  String _language = 'english';

  @override
  GdState build() {
    _realtime = ref.read(gdRealtimeServiceProvider);
    _speech = ref.read(gdSpeechServiceProvider);
    _tts = ref.read(gdTtsServiceProvider);
    // `ref.read`/anything touching other providers is not allowed inside
    // `onDispose` itself (Riverpod asserts against it) — `_realtime`/
    // `_speech`/`_tts` above are read once here, during `build()`, and
    // simply closed over by this callback rather than re-read from `ref`
    // at dispose time.
    ref.onDispose(() {
      _eventsSub?.cancel();
      _statusSub?.cancel();
      unawaited(_realtime.disconnect());
      unawaited(_speech.cancel());
      unawaited(_tts.stop());
    });
    return const GdIdle();
  }

  void setLanguage(String language) => _language = language;

  /// `GD_app:create_session`, then connects the WebSocket and sends
  /// `action: 'start'` once connected.
  Future<void> startDiscussion(String topic) async {
    state = const GdCreatingSession();
    final result = await ref.read(gdRepositoryProvider).createSession(topic);
    switch (result) {
      case Success(value: final session):
        state = GdConnectingSocket(session);
        await _connect(session);
      case Failed(failure: final failure):
        state = GdCreateFailed(failure);
    }
  }

  Future<void> _connect(GdStartedSession session) async {
    await _eventsSub?.cancel();
    await _statusSub?.cancel();
    _statusSub = _realtime.connectionStatus.listen((status) => _onConnectionStatus(session, status));
    _eventsSub = _realtime.events.listen(_onEvent);

    final wsUri = buildGdWebSocketUri(EnvironmentConfig.baseUrl, session.sessionId);
    final cookieHeader = await ref.read(apiClientProvider).buildCookieHeader();
    await _realtime.connect(uri: wsUri, cookieHeader: cookieHeader);
  }

  void _onConnectionStatus(GdStartedSession session, GdConnectionStatus status) {
    switch (status) {
      case GdConnectionStatus.connecting:
        break;
      case GdConnectionStatus.connected:
        final previousMessages = switch (state) {
          GdConnectionLost(messages: final m) => m,
          _ => const <GdMessage>[],
        };
        state = GdLive(
          session: session,
          messages: previousMessages,
          typingSpeaker: null,
          micState: GdMicState.idle,
        );
        if (!_sentStart) {
          _sentStart = true;
          _realtime.sendStart(language: _language);
        }
      case GdConnectionStatus.lost:
        final messages = switch (state) {
          GdLive(messages: final m) => m,
          GdEnding(messages: final m) => m,
          GdConnectionLost(messages: final m) => m,
          _ => const <GdMessage>[],
        };
        state = GdConnectionLost(session: session, messages: messages);
      case GdConnectionStatus.idle:
        break;
    }
  }

  void _onEvent(GdWsEvent event) {
    switch (event) {
      case GdStatusEvent(status: final status):
        if (status == 'analyzing') {
          final current = state;
          if (current is GdLive) state = GdEnding(session: current.session, messages: current.messages);
        }
      case GdTypingEvent():
        if (state case GdLive live) {
          state = GdLive(
            session: live.session,
            messages: live.messages,
            typingSpeaker: event,
            micState: live.micState,
            livePartialText: live.livePartialText,
            sttError: live.sttError,
          );
        }
      case GdMessageEvent(message: final message):
        if (state case GdLive live) {
          state = GdLive(
            session: live.session,
            messages: [...live.messages, message],
            typingSpeaker: null,
            micState: live.micState,
            sttError: live.sttError,
          );
          if (!message.isUser) unawaited(_tts.speak(message.content));
        }
      case GdReportEvent(report: final report):
        unawaited(_realtime.disconnect());
        state = GdReportReady(report);
    }
  }

  /// The mic control: presses "Speak" (`action: 'user_speaking'`, pausing
  /// the agents) and starts on-device STT.
  Future<void> startUserTurn() async {
    final current = state;
    if (current is! GdLive) return;

    final ready = await _speech.initialize();
    if (!ready) {
      state = GdLive(
        session: current.session,
        messages: current.messages,
        typingSpeaker: current.typingSpeaker,
        micState: GdMicState.idle,
        sttError: 'Could not start speech recognition. Please check the microphone/speech permission for this app.',
      );
      return;
    }

    _realtime.sendUserSpeaking();
    state = GdLive(
      session: current.session,
      messages: current.messages,
      typingSpeaker: current.typingSpeaker,
      micState: GdMicState.listening,
    );

    await _speech.startListening(onPartialResult: _onSttPartial, onFinalResult: _onSttFinal);
  }

  void _onSttPartial(String text) {
    if (state case GdLive live) {
      state = GdLive(
        session: live.session,
        messages: live.messages,
        typingSpeaker: live.typingSpeaker,
        micState: live.micState,
        livePartialText: text,
        sttError: live.sttError,
      );
    }
  }

  void _onSttFinal(String text) {
    if (state case GdLive live) {
      _realtime.sendUserMessage(text.trim(), language: _language);
      state = GdLive(
        session: live.session,
        messages: live.messages,
        typingSpeaker: live.typingSpeaker,
        micState: GdMicState.idle,
      );
    }
  }

  /// "Done Speaking" — stops the STT session; [_onSttFinal] (registered in
  /// [startUserTurn]) fires asynchronously with the recognized text and
  /// actually sends `action: 'user_message'`.
  Future<void> finishUserTurn() async {
    if (state is! GdLive) return;
    await _speech.stopListening();
  }

  Future<void> endDiscussion() async {
    if (state is! GdLive) return;
    _realtime.sendEnd();
  }

  /// Retries the WebSocket connection after [GdConnectionLost] — see this
  /// file's own doc comment for why `start` is deliberately not resent.
  Future<void> reconnect() async {
    if (state case GdConnectionLost(session: final session)) {
      state = GdConnectingSocket(session);
      await _connect(session);
    }
  }
}
