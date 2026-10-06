import 'dart:async';

import 'package:career_buddy_lms/core/errors/failures.dart';
import 'package:career_buddy_lms/core/network/api_client.dart';
import 'package:career_buddy_lms/core/providers/core_providers.dart';
import 'package:career_buddy_lms/core/utils/result.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_message.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_report.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_session_summary.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_speaker.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_started_session.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/entities/gd_ws_event.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/repositories/gd_repository.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/services/gd_realtime_service.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/services/gd_speech_service.dart';
import 'package:career_buddy_lms/features/group_discussion/domain/services/gd_tts_service.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/controllers/gd_session_controller.dart';
import 'package:career_buddy_lms/features/group_discussion/presentation/providers/gd_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRealtimeService implements GdRealtimeService {
  final eventsController = StreamController<GdWsEvent>.broadcast();
  final statusController = StreamController<GdConnectionStatus>.broadcast();
  final List<Map<String, dynamic>> sentActions = [];
  int connectCallCount = 0;
  int disconnectCallCount = 0;

  @override
  Stream<GdWsEvent> get events => eventsController.stream;

  @override
  Stream<GdConnectionStatus> get connectionStatus => statusController.stream;

  @override
  Future<void> connect({required Uri uri, required String cookieHeader}) async {
    connectCallCount++;
  }

  @override
  void sendStart({String language = 'english'}) => sentActions.add({'action': 'start', 'language': language});

  @override
  void sendUserSpeaking() => sentActions.add({'action': 'user_speaking'});

  @override
  void sendUserMessage(String content, {String language = 'english'}) =>
      sentActions.add({'action': 'user_message', 'content': content, 'language': language});

  @override
  void sendEnd() => sentActions.add({'action': 'end'});

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
  }
}

class _FakeSpeechService implements GdSpeechService {
  bool initializeResult = true;
  bool _listening = false;
  void Function(String)? onPartial;
  void Function(String)? onFinal;
  int stopListeningCallCount = 0;

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
    onPartial = onPartialResult;
    onFinal = onFinalResult;
  }

  @override
  Future<void> stopListening() async {
    stopListeningCallCount++;
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }
}

class _FakeTtsService implements GdTtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}

  @override
  void setOnComplete(void Function() callback) {}
}

class _FakeGdRepository implements GdRepository {
  Result<GdStartedSession>? createResult;
  int createCallCount = 0;

  @override
  Future<Result<GdStartedSession>> createSession(String topic) async {
    createCallCount++;
    return createResult!;
  }

  @override
  Future<Result<List<GdSessionSummary>>> getSessions() async => const Success([]);

  @override
  Future<Result<GdReport?>> getSessionReport(int sessionId) async => const Success(null);
}

GdReport _report() => const GdReport(
  overallScore: 80,
  fluency: GdReportDimension(score: 20, feedback: 'Good.'),
  grammar: GdReportDimension(score: 20, feedback: 'Good.'),
  relevance: GdReportDimension(score: 20, feedback: 'Good.'),
  confidence: GdReportDimension(score: 20, feedback: 'Good.'),
  strengths: ['Clarity'],
  improvements: ['Pace'],
  summary: 'Well done.',
);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('GdSessionController', () {
    late _FakeRealtimeService realtime;
    late _FakeSpeechService speech;
    late _FakeTtsService tts;
    late _FakeGdRepository repo;
    late ProviderContainer container;

    setUp(() {
      realtime = _FakeRealtimeService();
      speech = _FakeSpeechService();
      tts = _FakeTtsService();
      repo = _FakeGdRepository();
      container = ProviderContainer(
        overrides: [
          gdRealtimeServiceProvider.overrideWithValue(realtime),
          gdSpeechServiceProvider.overrideWithValue(speech),
          gdTtsServiceProvider.overrideWithValue(tts),
          gdRepositoryProvider.overrideWithValue(repo),
          apiClientProvider.overrideWithValue(ApiClient.forTesting(Dio())),
        ],
      );
      addTearDown(container.dispose);
    });

    test('starts in GdIdle', () {
      expect(container.read(gdSessionControllerProvider), isA<GdIdle>());
    });

    test('startDiscussion creates the session, connects, and sends start once connected', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);

      final future = notifier.startDiscussion('AI jobs');
      await _flush();
      expect(container.read(gdSessionControllerProvider), isA<GdConnectingSocket>());

      realtime.statusController.add(GdConnectionStatus.connecting);
      await _flush();
      realtime.statusController.add(GdConnectionStatus.connected);
      await future;
      await _flush();

      final state = container.read(gdSessionControllerProvider) as GdLive;
      expect(state.session.sessionId, 5);
      expect(state.messages, isEmpty);
      expect(realtime.connectCallCount, 1);
      expect(realtime.sentActions, [
        {'action': 'start', 'language': 'english'},
      ]);
    });

    test('startDiscussion moves to GdCreateFailed on a failed create_session (e.g. locked)', () async {
      repo.createResult = const Failed(ForbiddenFailure());
      final notifier = container.read(gdSessionControllerProvider.notifier);

      await notifier.startDiscussion('Any topic');

      final state = container.read(gdSessionControllerProvider) as GdCreateFailed;
      expect(state.failure, isA<ForbiddenFailure>());
      expect(realtime.connectCallCount, 0);
    });

    test('a typing event updates the live typing indicator', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();

      realtime.eventsController.add(
        const GdTypingEvent(speaker: GdSpeaker.alex, speakerName: 'Alex', avatar: '🔵', colorHex: '#4F8EF7'),
      );
      await _flush();

      final state = container.read(gdSessionControllerProvider) as GdLive;
      expect(state.typingSpeaker?.speakerName, 'Alex');
    });

    test('an agent message event is appended to the transcript and spoken aloud via TTS', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();

      realtime.eventsController.add(
        GdMessageEvent(
          GdMessage(
            speaker: GdSpeaker.alex,
            speakerName: 'Alex',
            avatar: '🔵',
            colorHex: '#4F8EF7',
            content: 'Statistically speaking, this matters.',
            isUser: false,
            receivedAt: DateTime.now(),
          ),
        ),
      );
      await _flush();

      final state = container.read(gdSessionControllerProvider) as GdLive;
      expect(state.messages, hasLength(1));
      expect(state.messages.single.content, 'Statistically speaking, this matters.');
      expect(state.typingSpeaker, isNull);
      expect(tts.spoken, ['Statistically speaking, this matters.']);
    });

    test('a user message event is appended but not spoken aloud', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();

      realtime.eventsController.add(
        GdMessageEvent(
          GdMessage(
            speaker: GdSpeaker.user,
            speakerName: 'You',
            avatar: '🧑',
            colorHex: '#F59E0B',
            content: 'I agree with that.',
            isUser: true,
            receivedAt: DateTime.now(),
          ),
        ),
      );
      await _flush();

      final state = container.read(gdSessionControllerProvider) as GdLive;
      expect(state.messages, hasLength(1));
      expect(tts.spoken, isEmpty);
    });

    test('startUserTurn sends user_speaking and starts listening', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();

      await notifier.startUserTurn();

      final state = container.read(gdSessionControllerProvider) as GdLive;
      expect(state.micState, GdMicState.listening);
      expect(realtime.sentActions.last, {'action': 'user_speaking'});
      expect(speech.isListening, isTrue);
    });

    test('startUserTurn surfaces a real error when speech recognition fails to initialize', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      speech.initializeResult = false;
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();

      await notifier.startUserTurn();

      final state = container.read(gdSessionControllerProvider) as GdLive;
      expect(state.micState, GdMicState.idle);
      expect(state.sttError, isNotNull);
      expect(realtime.sentActions.any((a) => a['action'] == 'user_speaking'), isFalse);
    });

    test('finishUserTurn sends the recognized text as user_message and resets mic state', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();
      await notifier.startUserTurn();

      // Mirrors `speech_to_text`'s own async final-result delivery: stopping
      // triggers the callback registered by `startListening`, it doesn't
      // return the text directly.
      speech.onFinal?.call('AI will change many jobs.');
      await notifier.finishUserTurn();

      expect(speech.stopListeningCallCount, 1);
      expect(realtime.sentActions.last, {
        'action': 'user_message',
        'content': 'AI will change many jobs.',
        'language': 'english',
      });
      final state = container.read(gdSessionControllerProvider) as GdLive;
      expect(state.micState, GdMicState.idle);
    });

    test('status: analyzing moves to GdEnding, and the report event moves to GdReportReady', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();

      await notifier.endDiscussion();
      expect(realtime.sentActions.last, {'action': 'end'});

      realtime.eventsController.add(const GdStatusEvent(status: 'analyzing'));
      await _flush();
      expect(container.read(gdSessionControllerProvider), isA<GdEnding>());

      realtime.eventsController.add(GdReportEvent(_report()));
      await _flush();

      final state = container.read(gdSessionControllerProvider) as GdReportReady;
      expect(state.report.overallScore, 80);
      expect(realtime.disconnectCallCount, 1);
    });

    test('a dropped connection surfaces GdConnectionLost, preserving the transcript so far', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();
      realtime.eventsController.add(
        GdMessageEvent(
          GdMessage(
            speaker: GdSpeaker.rishi,
            speakerName: 'Rishi',
            avatar: '🟢',
            colorHex: '#43E97B',
            content: 'Welcome everyone!',
            isUser: false,
            receivedAt: DateTime.now(),
          ),
        ),
      );
      await _flush();

      realtime.statusController.add(GdConnectionStatus.lost);
      await _flush();

      final state = container.read(gdSessionControllerProvider) as GdConnectionLost;
      expect(state.messages, hasLength(1));
      expect(state.session.sessionId, 5);
    });

    test('reconnect() reopens the socket but does not resend start', () async {
      repo.createResult = Success(const GdStartedSession(sessionId: 5, topic: 'AI jobs'));
      final notifier = container.read(gdSessionControllerProvider.notifier);
      await notifier.startDiscussion('AI jobs');
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();
      realtime.statusController.add(GdConnectionStatus.lost);
      await _flush();
      expect(realtime.connectCallCount, 1);

      await notifier.reconnect();
      realtime.statusController.add(GdConnectionStatus.connected);
      await _flush();

      expect(realtime.connectCallCount, 2);
      expect(container.read(gdSessionControllerProvider), isA<GdLive>());
      expect(realtime.sentActions.where((a) => a['action'] == 'start'), hasLength(1));
    });
  });
}
