import 'dart:io';

import 'package:career_buddy_lms/core/errors/exceptions.dart';
import 'package:career_buddy_lms/features/ai_speaking/domain/services/audio_recorder_service.dart';
import 'package:career_buddy_lms/features/aria_chat/data/datasources/aria_remote_datasource.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_chat_message.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_chat_reply.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_stream_event.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/entities/aria_voice.dart';
import 'package:career_buddy_lms/features/aria_chat/domain/services/aria_voice_playback_service.dart';
import 'package:career_buddy_lms/features/aria_chat/presentation/controllers/aria_chat_controller.dart';
import 'package:career_buddy_lms/features/aria_chat/presentation/providers/aria_chat_providers.dart';
import 'package:career_buddy_lms/features/auth/domain/entities/auth_user.dart';
import 'package:career_buddy_lms/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake [AriaRemoteDataSource] the controller talks to through
/// [ariaRemoteDataSourceProvider] — implements the interface directly
/// (this feature has no repository layer, matching the task's "don't
/// over-engineer" guidance); overriding the provider with this fake is the
/// seam. [sendMessageStream] is the one [AriaChatController.sendMessage]
/// actually calls; [sendMessage] is stubbed only so the class type-checks.
/// [transcribeVoice]/[synthesizeSpeech] back the voice tests further down
/// this file.
class _FakeAriaRemoteDataSource implements AriaRemoteDataSource {
  _FakeAriaRemoteDataSource({List<AriaStreamEvent>? events, this.error}) : events = events ?? const [];

  List<AriaStreamEvent> events;
  Object? error;
  final List<List<AriaChatMessage>> capturedHistories = [];
  final List<String> capturedConversationIds = [];
  final List<String> capturedLanguages = [];

  String? transcriptionResult;
  Object? transcriptionError;
  final List<String> capturedTranscribeAudio = [];
  final List<String> capturedTranscribeLanguages = [];

  String? ttsAudioResult;
  Object? ttsError;
  final List<String> capturedTtsText = [];

  @override
  Future<AriaChatReply> sendMessage({
    required String message,
    required String page,
    required String path,
    required bool isEmployer,
    required String conversationId,
    required List<AriaChatMessage> history,
  }) async => throw UnimplementedError('not called by the controller');

  @override
  Stream<AriaStreamEvent> sendMessageStream({
    required String message,
    required String page,
    required String path,
    required bool isEmployer,
    required String conversationId,
    required List<AriaChatMessage> history,
    required String language,
  }) async* {
    capturedHistories.add(history);
    capturedConversationIds.add(conversationId);
    capturedLanguages.add(language);
    if (error != null) throw error!;
    for (final event in events) {
      yield event;
    }
  }

  @override
  Future<AriaVoiceTranscription> transcribeVoice({
    required String audioBase64,
    required String mimeType,
    required String language,
  }) async {
    capturedTranscribeAudio.add(audioBase64);
    capturedTranscribeLanguages.add(language);
    if (transcriptionError != null) throw transcriptionError!;
    return AriaVoiceTranscription(text: transcriptionResult ?? '', source: 'sarvam');
  }

  @override
  Future<String?> synthesizeSpeech({required String text, required String language}) async {
    capturedTtsText.add(text);
    if (ttsError != null) throw ttsError!;
    return ttsAudioResult;
  }
}

/// A fake [AudioRecorderService] — no real microphone/plugin involved.
/// [stop] actually writes a tiny file to disk (synthetic, non-personal
/// bytes — see this task's Security/Privacy requirement to use synthetic
/// test audio wherever possible) so
/// [AriaChatController.stopRecordingAndSend]'s real `File(...).readAsBytes()`
/// call has something real to read, exactly as it would on device.
class _FakeAudioRecorderService implements AudioRecorderService {
  bool permissionGranted = true;
  String? stopResult = '${Directory.systemTemp.path}/aria_voice_test_recording.m4a';
  var startCalls = 0;
  var cancelCalls = 0;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async {
    final path = stopResult;
    if (path != null) {
      await File(path).writeAsBytes(const [0, 1, 2, 3]);
    }
    return path;
  }

  @override
  Future<void> cancel() async => cancelCalls++;
}

/// A fake [AriaVoicePlaybackService] — no real audio player/TTS plugin
/// involved, so these tests exercise [AriaChatController]'s own state
/// machine without touching a platform channel.
class _FakeAriaVoicePlaybackService implements AriaVoicePlaybackService {
  bool playResult = true;
  final List<String> playedAudio = [];
  final List<String> spokenDeviceText = [];
  var stopCalls = 0;
  void Function()? _onComplete;

  @override
  Future<bool> playAudioBytes(String base64Audio) async {
    playedAudio.add(base64Audio);
    return playResult;
  }

  @override
  Future<void> speakDeviceVoice(String text) async => spokenDeviceText.add(text);

  @override
  Future<void> stop() async => stopCalls++;

  @override
  void setOnComplete(void Function() callback) => _onComplete = callback;

  void completeNow() => _onComplete?.call();
}

ProviderContainer _container(
  _FakeAriaRemoteDataSource fake, {
  _FakeAudioRecorderService? recorder,
  _FakeAriaVoicePlaybackService? playback,
}) {
  final container = ProviderContainer(
    overrides: [
      ariaRemoteDataSourceProvider.overrideWithValue(fake),
      ariaAudioRecorderServiceProvider.overrideWithValue(recorder ?? _FakeAudioRecorderService()),
      ariaVoicePlaybackServiceProvider.overrideWithValue(playback ?? _FakeAriaVoicePlaybackService()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const _fastPathComplete = [
  AriaStreamComplete(AriaChatReply(reply: 'Hi there!', actions: [])),
];

void main() {
  group('AriaChatController.sendMessage (streaming)', () {
    test('appends the user message immediately, then the reply on a fast-path complete event', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete);
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      final future = notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);

      // The user's turn and the loading flag are set synchronously.
      final afterUserTurn = container.read(ariaChatControllerProvider);
      expect(afterUserTurn.messages, hasLength(1));
      expect(afterUserTurn.messages.single.role, AriaMessageRole.user);
      expect(afterUserTurn.messages.single.content, 'Hello');
      expect(afterUserTurn.sending, isTrue);

      await future;

      final afterReply = container.read(ariaChatControllerProvider);
      expect(afterReply.sending, isFalse);
      expect(afterReply.streamingText, isNull);
      expect(afterReply.messages, hasLength(2));
      expect(afterReply.messages.last.role, AriaMessageRole.assistant);
      expect(afterReply.messages.last.content, 'Hi there!');
      expect(afterReply.messages.last.isError, isFalse);
    });

    test('grows streamingText as token events arrive, then finalizes into a message', () async {
      final fake = _FakeAriaRemoteDataSource(
        events: const [
          AriaStreamToken('Hel'),
          AriaStreamToken('lo '),
          AriaStreamToken('there!'),
          AriaStreamComplete(AriaChatReply(reply: 'Hello there!', actions: [])),
        ],
      );
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      final seenStreamingTexts = <String?>[];
      container.listen(ariaChatControllerProvider, (prev, next) => seenStreamingTexts.add(next.streamingText));

      await notifier.sendMessage('Hi', page: 'home', path: '/home', isEmployer: false);

      expect(seenStreamingTexts, containsAllInOrder(['Hel', 'Hello ', 'Hello there!']));
      final finalState = container.read(ariaChatControllerProvider);
      expect(finalState.streamingText, isNull);
      expect(finalState.messages.last.content, 'Hello there!');
    });

    test('strips a <LANG:code> directive from the displayed text and updates the request language', () async {
      final fake = _FakeAriaRemoteDataSource(
        events: const [
          AriaStreamToken('Namaste'),
          AriaStreamToken('<LANG:hindi>'),
          AriaStreamComplete(AriaChatReply(reply: 'Namaste', actions: [])),
        ],
      );
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('Hi', page: 'home', path: '/home', isEmployer: false);
      expect(container.read(ariaChatControllerProvider).language, 'hindi');

      // The next send carries the newly-detected language.
      await notifier.sendMessage('Again', page: 'home', path: '/home', isEmployer: false);
      expect(fake.capturedLanguages, ['english', 'hindi']);
    });

    test('a failed stream appends a friendly error entry instead of crashing', () async {
      final fake = _FakeAriaRemoteDataSource(error: const UnexpectedResponseException());
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);

      final state = container.read(ariaChatControllerProvider);
      expect(state.sending, isFalse);
      expect(state.streamingText, isNull);
      expect(state.messages, hasLength(2));
      expect(state.messages.last.role, AriaMessageRole.assistant);
      expect(state.messages.last.isError, isTrue);
      expect(state.messages.last.content, isNotEmpty);
    });

    test('conversation_id stays stable across multiple sends', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete);
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('First', page: 'home', path: '/home', isEmployer: false);
      await notifier.sendMessage('Second', page: 'home', path: '/home', isEmployer: false);

      expect(fake.capturedConversationIds, hasLength(2));
      expect(fake.capturedConversationIds[0], fake.capturedConversationIds[1]);
      expect(fake.capturedConversationIds[0], container.read(ariaChatControllerProvider).conversationId);
    });

    test('history sent on the 2nd message includes the 1st exchange', () async {
      final fake = _FakeAriaRemoteDataSource(
        events: const [AriaStreamComplete(AriaChatReply(reply: 'First reply', actions: []))],
      );
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('First', page: 'home', path: '/home', isEmployer: false);
      await notifier.sendMessage('Second', page: 'home', path: '/home', isEmployer: false);

      expect(fake.capturedHistories, hasLength(2));
      expect(fake.capturedHistories[0], isEmpty);
      expect(fake.capturedHistories[1], hasLength(2));
      expect(fake.capturedHistories[1][0].role, AriaMessageRole.user);
      expect(fake.capturedHistories[1][0].content, 'First');
      expect(fake.capturedHistories[1][1].role, AriaMessageRole.assistant);
      expect(fake.capturedHistories[1][1].content, 'First reply');
    });

    test('ignores an empty/whitespace-only message', () async {
      final fake = _FakeAriaRemoteDataSource();
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('   ', page: 'home', path: '/home', isEmployer: false);

      expect(container.read(ariaChatControllerProvider).messages, isEmpty);
      expect(fake.capturedHistories, isEmpty);
    });

    test('ignores a 2nd send while one is already in flight', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete);
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      final first = notifier.sendMessage('First', page: 'home', path: '/home', isEmployer: false);
      await notifier.sendMessage('Second', page: 'home', path: '/home', isEmployer: false);
      await first;

      expect(fake.capturedHistories, hasLength(1));
      expect(container.read(ariaChatControllerProvider).messages, hasLength(2));
    });
  });

  group('AriaChatController.ensureGreeted', () {
    test('seeds the greeting only when there is no history yet', () {
      final container = _container(_FakeAriaRemoteDataSource());
      final notifier = container.read(ariaChatControllerProvider.notifier);

      notifier.ensureGreeted('Hello there!');
      expect(container.read(ariaChatControllerProvider).messages, hasLength(1));
      expect(container.read(ariaChatControllerProvider).messages.single.content, 'Hello there!');

      notifier.ensureGreeted('A different greeting');
      expect(container.read(ariaChatControllerProvider).messages, hasLength(1));
      expect(container.read(ariaChatControllerProvider).messages.single.content, 'Hello there!');
    });
  });

  group('AriaChatController.greetingFor', () {
    test('greets an authenticated user by their (best-effort) first name', () {
      expect(
        AriaChatController.greetingFor(const AuthAuthenticated(AuthUser(username: 'jane.doe'))),
        'Hello Jane!',
      );
    });

    test('prompts job-seeker-or-employer when unauthenticated', () {
      expect(AriaChatController.greetingFor(const AuthUnauthenticated()), 'Hello there! Job seeker or employer?');
      expect(AriaChatController.greetingFor(const AuthUnknown()), 'Hello there! Job seeker or employer?');
    });
  });

  group('AriaChatController.setLanguage', () {
    test('defaults to english, same as the real #chatbotLanguageSelect\'s first (unselected) option', () {
      final container = _container(_FakeAriaRemoteDataSource());

      expect(container.read(ariaChatControllerProvider).language, 'english');
    });

    test('updates AriaChatState.language — the same field <LANG:code> auto-detect already writes', () {
      final container = _container(_FakeAriaRemoteDataSource());
      final notifier = container.read(ariaChatControllerProvider.notifier);

      notifier.setLanguage('hindi');

      expect(container.read(ariaChatControllerProvider).language, 'hindi');
    });

    test('a manual selection is carried into the next streaming request', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete);
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      notifier.setLanguage('vietnam');
      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);

      expect(fake.capturedLanguages, ['vietnam']);
    });

    test('a manual selection is also carried into voice transcription and TTS', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)
        ..transcriptionResult = 'hola'
        ..ttsAudioResult = 'YXVkaW8=';
      final recorder = _FakeAudioRecorderService();
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, recorder: recorder, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      notifier.setLanguage('arabic');

      await notifier.startRecording();
      await notifier.stopRecordingAndSend(page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);

      expect(fake.capturedTranscribeLanguages, ['arabic']);
      expect(fake.capturedLanguages, ['arabic']); // the auto-sent message's own streaming request
      expect(fake.capturedTtsText, isNotEmpty); // the reply's auto-speak also used state.language
    });

    test('is a no-op (does not cancel a recording) when already set to the same language', () async {
      final recorder = _FakeAudioRecorderService();
      final container = _container(_FakeAriaRemoteDataSource(), recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.startRecording();

      notifier.setLanguage('english'); // already the current/default language

      expect(container.read(ariaChatControllerProvider).voiceStatus, AriaVoiceStatus.recording);
      expect(recorder.cancelCalls, 0);
    });

    test('cancels (does not transcribe) an in-progress recording — matching the real web\'s own change handler', () async {
      final fake = _FakeAriaRemoteDataSource();
      final recorder = _FakeAudioRecorderService();
      final container = _container(fake, recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.startRecording();

      notifier.setLanguage('russian');
      await Future<void>.delayed(Duration.zero); // cancelRecording() is fire-and-forget internally

      expect(container.read(ariaChatControllerProvider).voiceStatus, AriaVoiceStatus.idle);
      expect(recorder.cancelCalls, 1);
      expect(fake.capturedTranscribeAudio, isEmpty);
    });

    test('does not stop an in-progress streaming reply', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete);
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      final future = notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);

      notifier.setLanguage('hindi');

      await future;
      final state = container.read(ariaChatControllerProvider);
      expect(state.sending, isFalse);
      expect(state.messages, hasLength(2));
      expect(state.messages.last.content, 'Hi there!');
    });

    test('does not stop in-progress TTS playback', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ariaChatControllerProvider).speakerState, AriaSpeakerState.speaking);
      final stopCallsBeforeLanguageChange = playback.stopCalls;

      notifier.setLanguage('hindi');

      expect(container.read(ariaChatControllerProvider).speakerState, AriaSpeakerState.speaking);
      // Unchanged — setLanguage itself must not call stop(); the one+ call(s)
      // already counted above are `_autoSpeak`'s own always-stop-before-
      // speaking step from the reply that already landed, not from this.
      expect(playback.stopCalls, stopCallsBeforeLanguageChange);
    });
  });

  group('AriaChatController voice recording', () {
    test('startRecording moves idle -> recording when permission is granted', () async {
      final recorder = _FakeAudioRecorderService();
      final container = _container(_FakeAriaRemoteDataSource(), recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.startRecording();

      expect(container.read(ariaChatControllerProvider).voiceStatus, AriaVoiceStatus.recording);
      expect(recorder.startCalls, 1);
    });

    test('startRecording surfaces a voiceError and stays idle when permission is denied', () async {
      final recorder = _FakeAudioRecorderService()..permissionGranted = false;
      final container = _container(_FakeAriaRemoteDataSource(), recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.startRecording();

      final state = container.read(ariaChatControllerProvider);
      expect(state.voiceStatus, AriaVoiceStatus.idle);
      expect(state.voiceError, isNotNull);
      expect(recorder.startCalls, 0);
    });

    test('a 2nd startRecording while already recording is a no-op', () async {
      final recorder = _FakeAudioRecorderService();
      final container = _container(_FakeAriaRemoteDataSource(), recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.startRecording();
      await notifier.startRecording();

      expect(recorder.startCalls, 1);
    });

    test('cancelRecording discards the recording and returns to idle', () async {
      final recorder = _FakeAudioRecorderService();
      final container = _container(_FakeAriaRemoteDataSource(), recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.startRecording();

      await notifier.cancelRecording();

      expect(container.read(ariaChatControllerProvider).voiceStatus, AriaVoiceStatus.idle);
      expect(recorder.cancelCalls, 1);
    });

    test('cancelRecording is a no-op when not currently recording', () async {
      final recorder = _FakeAudioRecorderService();
      final container = _container(_FakeAriaRemoteDataSource(), recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.cancelRecording();

      expect(recorder.cancelCalls, 0);
    });

    test('stopRecordingAndSend is a no-op when not currently recording', () async {
      final fake = _FakeAriaRemoteDataSource();
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.stopRecordingAndSend(page: 'home', path: '/home', isEmployer: false);

      expect(fake.capturedTranscribeAudio, isEmpty);
    });

    test('a successful transcription is sent immediately, same as typed text — the web auto-sends voice input', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)..transcriptionResult = 'What jobs are open?';
      final recorder = _FakeAudioRecorderService();
      final container = _container(fake, recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.startRecording();

      await notifier.stopRecordingAndSend(page: 'home', path: '/home', isEmployer: false);

      expect(fake.capturedTranscribeAudio, hasLength(1));
      final state = container.read(ariaChatControllerProvider);
      expect(state.voiceStatus, AriaVoiceStatus.idle);
      expect(state.messages, hasLength(2));
      expect(state.messages.first.role, AriaMessageRole.user);
      expect(state.messages.first.content, 'What jobs are open?');
      expect(state.messages.last.content, 'Hi there!');
    });

    test('an empty transcription surfaces a voiceError and sends nothing', () async {
      final fake = _FakeAriaRemoteDataSource()..transcriptionResult = '';
      final recorder = _FakeAudioRecorderService();
      final container = _container(fake, recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.startRecording();

      await notifier.stopRecordingAndSend(page: 'home', path: '/home', isEmployer: false);

      final state = container.read(ariaChatControllerProvider);
      expect(state.voiceStatus, AriaVoiceStatus.idle);
      expect(state.voiceError, isNotNull);
      expect(state.messages, isEmpty);
    });

    test('a failed transcription request surfaces a voiceError and sends nothing', () async {
      final fake = _FakeAriaRemoteDataSource()..transcriptionError = const UnexpectedResponseException();
      final recorder = _FakeAudioRecorderService();
      final container = _container(fake, recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.startRecording();

      await notifier.stopRecordingAndSend(page: 'home', path: '/home', isEmployer: false);

      final state = container.read(ariaChatControllerProvider);
      expect(state.voiceStatus, AriaVoiceStatus.idle);
      expect(state.voiceError, isNotNull);
      expect(state.messages, isEmpty);
    });

    test('a recording that produced no file surfaces a voiceError', () async {
      final recorder = _FakeAudioRecorderService()..stopResult = null;
      final container = _container(_FakeAriaRemoteDataSource(), recorder: recorder);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.startRecording();

      await notifier.stopRecordingAndSend(page: 'home', path: '/home', isEmployer: false);

      final state = container.read(ariaChatControllerProvider);
      expect(state.voiceStatus, AriaVoiceStatus.idle);
      expect(state.voiceError, isNotNull);
    });
  });

  group('AriaChatController auto-speak / header speaker button', () {
    test('ensureGreeted speaks the greeting through the real TTS endpoint', () async {
      final fake = _FakeAriaRemoteDataSource()..ttsAudioResult = 'ZmFrZS13YXY=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      notifier.ensureGreeted('Hello there!');
      await Future<void>.delayed(Duration.zero);

      expect(fake.capturedTtsText, ['Hello there!']);
      expect(playback.playedAudio, ['ZmFrZS13YXY=']);
      expect(container.read(ariaChatControllerProvider).speakerState, AriaSpeakerState.speaking);
    });

    test('reopening with existing history does not re-greet or re-speak', () async {
      final fake = _FakeAriaRemoteDataSource();
      final container = _container(fake);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      notifier.ensureGreeted('Hello there!');
      await Future<void>.delayed(Duration.zero);
      fake.capturedTtsText.clear();

      notifier.ensureGreeted('Hello there!');
      await Future<void>.delayed(Duration.zero);

      expect(fake.capturedTtsText, isEmpty);
    });

    test('every assistant reply is spoken automatically, regardless of how the turn was sent', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);

      expect(fake.capturedTtsText, ['Hi there!']);
      expect(playback.playedAudio, ['YXVkaW8=']);
    });

    test('falls back to on-device voice when the server has no TTS audio to offer', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)..ttsAudioResult = null;
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);

      expect(playback.playedAudio, isEmpty);
      expect(playback.spokenDeviceText, ['Hi there!']);
    });

    test('falls back to on-device voice when the TTS request itself fails', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)..ttsError = const UnexpectedResponseException();
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);

      expect(playback.spokenDeviceText, ['Hi there!']);
    });

    test('toggleSpeaker while speaking stops playback', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ariaChatControllerProvider).speakerState, AriaSpeakerState.speaking);

      notifier.toggleSpeaker();

      expect(container.read(ariaChatControllerProvider).speakerState, AriaSpeakerState.idle);
      expect(playback.stopCalls, greaterThanOrEqualTo(1));
    });

    test('toggleSpeaker while idle replays the last reply', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);
      notifier.toggleSpeaker(); // stop the auto-speak that just started
      fake.capturedTtsText.clear();

      notifier.toggleSpeaker();
      await Future<void>.delayed(Duration.zero);

      expect(fake.capturedTtsText, ['Hi there!']);
    });

    test('a natural playback completion returns the speaker state to idle', () async {
      final fake = _FakeAriaRemoteDataSource(events: _fastPathComplete)..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);
      await notifier.sendMessage('Hello', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);

      playback.completeNow();

      expect(container.read(ariaChatControllerProvider).speakerState, AriaSpeakerState.idle);
    });

    test('stopSpeaking is a no-op when nothing is speaking', () async {
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(_FakeAriaRemoteDataSource(), playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      notifier.stopSpeaking();

      expect(playback.stopCalls, 0);
    });
  });

  group('AriaChatController auto-navigate after speech (mirrors the real web\'s commitNavigation)', () {
    test('a single-action "intent" reply resolves pendingNavigation once speech finishes, not before', () async {
      final fake = _FakeAriaRemoteDataSource(
        events: const [
          AriaStreamComplete(
            AriaChatReply(
              reply: 'Opening the post new job page.',
              actions: [AriaChatAction(key: 'post_job', label: 'Post New Job', route: '/employer/employer/jobs/new/')],
              source: 'intent',
            ),
          ),
        ],
      )..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('post a job', page: 'home', path: '/home', isEmployer: true);
      await Future<void>.delayed(Duration.zero);

      // Speech has started but not yet finished — navigation must not have
      // resolved yet (the real web waits for speech to end first).
      expect(container.read(ariaChatControllerProvider).navigationGeneration, 0);

      playback.completeNow();

      final state = container.read(ariaChatControllerProvider);
      expect(state.navigationGeneration, 1);
      expect(state.pendingNavigation?.route, '/employer/employer/jobs/new/');
    });

    test('a reply with more than one action never auto-navigates', () async {
      final fake = _FakeAriaRemoteDataSource(
        events: const [
          AriaStreamComplete(
            AriaChatReply(
              reply: 'Here are a couple of options.',
              actions: [
                AriaChatAction(key: 'lessons', label: 'Go to Activities', route: '/activities/'),
                AriaChatAction(key: 'profile', label: 'View Dashboard', route: '/dashboard/'),
              ],
              source: 'intent',
            ),
          ),
        ],
      )..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('help', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);
      playback.completeNow();

      expect(container.read(ariaChatControllerProvider).navigationGeneration, 0);
    });

    test('a single-action "ai"-sourced reply never auto-navigates (only intent/skillup do on the real web)', () async {
      final fake = _FakeAriaRemoteDataSource(
        events: const [
          AriaStreamComplete(
            AriaChatReply(
              reply: 'You could try the Resume Builder.',
              actions: [AriaChatAction(key: 'resume_builder', label: 'Resume Builder', route: '/resume-builder/')],
              source: 'ai',
            ),
          ),
        ],
      )..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('any suggestions?', page: 'home', path: '/home', isEmployer: false);
      await Future<void>.delayed(Duration.zero);
      playback.completeNow();

      expect(container.read(ariaChatControllerProvider).navigationGeneration, 0);
    });

    test('navigationGeneration bumps again for a second eligible reply, even with the same action', () async {
      const reply = AriaStreamComplete(
        AriaChatReply(
          reply: 'Opening the post new job page.',
          actions: [AriaChatAction(key: 'post_job', label: 'Post New Job', route: '/employer/employer/jobs/new/')],
          source: 'intent',
        ),
      );
      final fake = _FakeAriaRemoteDataSource(events: const [reply])..ttsAudioResult = 'YXVkaW8=';
      final playback = _FakeAriaVoicePlaybackService();
      final container = _container(fake, playback: playback);
      final notifier = container.read(ariaChatControllerProvider.notifier);

      await notifier.sendMessage('post a job', page: 'home', path: '/home', isEmployer: true);
      await Future<void>.delayed(Duration.zero);
      playback.completeNow();
      expect(container.read(ariaChatControllerProvider).navigationGeneration, 1);

      fake.events = const [reply];
      await notifier.sendMessage('post a job again', page: 'home', path: '/home', isEmployer: true);
      await Future<void>.delayed(Duration.zero);
      playback.completeNow();

      expect(container.read(ariaChatControllerProvider).navigationGeneration, 2);
    });
  });
}
