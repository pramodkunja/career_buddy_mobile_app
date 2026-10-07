import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai_speaking/domain/services/audio_recorder_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/aria_chat_message.dart';
import '../../domain/entities/aria_stream_event.dart';
import '../../domain/services/aria_voice_playback_service.dart';
import '../providers/aria_chat_providers.dart';

/// Mirrors the mic button's own three real states — idle, actively
/// recording, and uploading-for-transcription — the same "Recording" →
/// "Recorded"/"Submitting" shape `AiSpeakingController` already uses,
/// collapsed into one enum here since ARIA's voice flow has no separate
/// "ready to submit" pause (stopping the mic immediately uploads, matching
/// the real web's own `MediaRecorder.onstop` handler which transcribes
/// immediately with no intermediate review step).
enum AriaVoiceStatus { idle, recording, transcribing }

/// The header speaker button's states (`#riya-speaker-button`,
/// `templates/includes/aria_assistant.html`) — `idle` (nothing playing,
/// tap replays the last reply), `loading` (this app's own addition: the
/// moment between a reply landing and its TTS audio actually starting —
/// the real web has no separate loading state here since `speechSynthesis`
/// starts near-instantly, but a real network fetch to `riyaTts` does not),
/// `speaking` (tap stops). **Deliberately only two tappable outcomes
/// (replay / stop), not the real web's three (replay / pause / resume)** —
/// `flutter_tts` has no true resume primitive to match `speechSynthesis`'s
/// (pausing it and "resuming" would only be able to restart from the
/// beginning, which is not actually resuming), and this task's own UI
/// requirement only asks for a "play/stop" affordance, so reproducing a
/// pause button that can't truly pause would be worse than not having one.
enum AriaSpeakerState { idle, loading, speaking }

const _unreachableMessage = "I couldn't reach the assistant. Please try again.";

/// `<LANG:code>` can appear anywhere inside the model's own streamed text
/// (`static/js/BOTscript.js`'s token-handling branch — not server-stripped,
/// confirmed against `riya_bot/riya_assistant.py`) — matched the same way
/// here: stripped from the displayed/final text, and its `code` becomes the
/// language sent on every subsequent request, same as the real page's
/// `chatbotLanguageSelect` auto-updating.
final _langDirectivePattern = RegExp(r'<LANG:([^>]+)>');

/// Generates a client-side conversation id, close enough to RFC 4122 v4 to
/// be a plausible UUID without pulling in a new package dependency (`uuid`
/// isn't a direct dependency of this project today — only a transitive
/// one). The real web keeps its own equivalent in `sessionStorage`; the
/// non-streaming `/api/riya/chat/` endpoint doesn't actually read this
/// field server-side (see `ApiEndpoints.riyaChat`'s doc comment), so this
/// only needs to be stable and unique per app session, not
/// cryptographically rigorous.
String _generateConversationId() {
  final random = Random.secure();
  String hex(int length) => List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
}

class AriaChatState {
  const AriaChatState({
    required this.conversationId,
    this.messages = const [],
    this.sending = false,
    this.streamingText,
    this.language = 'english',
    this.voiceStatus = AriaVoiceStatus.idle,
    this.voiceError,
    this.speakerState = AriaSpeakerState.idle,
    this.pendingNavigation,
    this.navigationGeneration = 0,
  });

  final String conversationId;
  final List<AriaChatMessage> messages;
  final bool sending;

  /// The in-progress assistant reply's text so far, built up from
  /// `{"t": ...}` events — `null` whenever nothing is currently streaming
  /// (not sending, or a fast-path reply arrived with no token events at
  /// all). Already stripped of any `<LANG:code>` directive.
  final String? streamingText;

  /// `SUPPORTED_LANGUAGES` key (`riya_bot/riya_assistant.py`) sent as the
  /// `language` field on every request — starts at the same default the
  /// real page's `chatbotLanguageSelect` does (`"english"`), and updates
  /// when the assistant's own stream carries a `<LANG:code>` directive.
  final String language;

  /// The mic button's current state — see [AriaVoiceStatus].
  final AriaVoiceStatus voiceStatus;

  /// A one-shot message for the most recent voice failure (permission
  /// denied, empty recording, transcription failure, TTS failure) — shown
  /// once as a snackbar by the UI, not persisted as a chat message (unlike
  /// a send failure, nothing was actually sent to the assistant).
  final String? voiceError;

  /// The header speaker button's current state — see [AriaSpeakerState].
  /// Global, not per-message: at most one reply speaks at a time, matching
  /// the real page's own single `#riya-speaker-button`.
  final AriaSpeakerState speakerState;

  /// The action to auto-navigate to, resolved the moment the speech for the
  /// reply that carried it finishes (see [_onPlaybackComplete]) — mirrors
  /// the real main widget's `commitNavigation` (`BOTscript.js`:
  /// `window.location.href = action.route` once speech ends, for a
  /// single-action reply whose `source` is `"intent"`/`"skillup"`). The UI
  /// layer (which owns a [BuildContext]/router, unlike this controller)
  /// watches [navigationGeneration] to fire exactly once per resolution,
  /// the same edge-triggered pattern [voiceError] already uses.
  final AriaChatAction? pendingNavigation;

  /// Bumped every time [pendingNavigation] is (re)resolved — a plain
  /// nullability/equality check on [pendingNavigation] itself isn't enough
  /// to edge-trigger on two consecutive identical actions (e.g. the user
  /// taps "Post New Job" twice in a row).
  final int navigationGeneration;

  AriaChatState copyWith({
    List<AriaChatMessage>? messages,
    bool? sending,
    String? streamingText,
    bool clearStreamingText = false,
    String? language,
    AriaVoiceStatus? voiceStatus,
    String? voiceError,
    bool clearVoiceError = false,
    AriaSpeakerState? speakerState,
    AriaChatAction? pendingNavigation,
    int? navigationGeneration,
  }) => AriaChatState(
    conversationId: conversationId,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    streamingText: clearStreamingText ? null : (streamingText ?? this.streamingText),
    language: language ?? this.language,
    pendingNavigation: pendingNavigation ?? this.pendingNavigation,
    navigationGeneration: navigationGeneration ?? this.navigationGeneration,
    voiceStatus: voiceStatus ?? this.voiceStatus,
    voiceError: clearVoiceError ? null : (voiceError ?? this.voiceError),
    speakerState: speakerState ?? this.speakerState,
  );
}

/// Holds the in-memory conversation with the chat assistant.
///
/// **Deliberate mobile-equivalent adaptation, not a limitation**: the real
/// web page persists its conversation in browser `sessionStorage` (cleared
/// when the tab closes). There's no direct mobile analogue of "tab
/// lifetime", so this controller instead lives in a plain (non-autoDispose)
/// Riverpod [Notifier] — state survives navigation between screens within
/// the same app session (matching `sessionStorage`'s "same tab" scope) and
/// is naturally cleared the next time the app process starts (matching
/// `sessionStorage`'s "gone when the tab closes" behavior), without needing
/// any on-device persistence.
class AriaChatController extends Notifier<AriaChatState> {
  // Not `late final` — confirmed live (switching from a job-seeker account
  // to an employer account, or back, in the same app session, then opening
  // ARIA chat on both): `_invalidateUserScopedProviders()`
  // (`auth_controller.dart`) can call `ref.invalidate(ariaChatControllerProvider)`
  // twice back to back (once on logout, once on the following login) before
  // anything ever re-reads the provider in between, which can make
  // Riverpod run [build] again on this *same* instance rather than a fresh
  // one — a `late final` field then throws `LateInitializationError` on the
  // second assignment, which silently broke the whole chat panel (no red
  // screen, just a blank panel) rather than visibly crashing. Reassignment
  // is harmless either way: both fields are only ever set here, from the
  // same providers, every time.
  late AudioRecorderService _recorder;
  late AriaVoicePlaybackService _playback;
  int _speakGeneration = 0;

  /// The most recent assistant reply/greeting text spoken — replayed when
  /// the header speaker button is tapped while idle (`onSpeakerButtonClick`
  /// "Idle: replay the latest response from the start", `BOTscript.js`).
  String? _lastAssistantReplyText;

  /// Set by [_autoSpeak] for the one reply currently being spoken, when
  /// that reply is eligible for auto-navigation (exactly one action,
  /// `source` `"intent"`/`"skillup"` — same condition as the real main
  /// widget's `commitNavigation`). Consumed by [_onPlaybackComplete], which
  /// fires once the speech actually finishes — not by [_autoSpeak] itself
  /// returning, since starting playback and *finishing* it are two
  /// different moments (see [AriaVoicePlaybackService.setOnComplete]).
  AriaChatAction? _pendingNavigationAction;

  @override
  AriaChatState build() {
    _recorder = ref.read(ariaAudioRecorderServiceProvider);
    _playback = ref.read(ariaVoicePlaybackServiceProvider);
    _playback.setOnComplete(_onPlaybackComplete);
    ref.onDispose(() {
      unawaited(_safeVoiceCall(_recorder.cancel));
      unawaited(_safeVoiceCall(_playback.stop));
    });
    return AriaChatState(conversationId: _generateConversationId());
  }

  /// Seeds the greeting as the first assistant message the first time the
  /// chat panel is opened with no history yet — matching the real web's
  /// behavior of showing the greeting as the opening turn of the
  /// conversation, **and speaking it** (`speakText(GREETING_TEXT, ...)`,
  /// confirmed directly in `BOTscript.js`'s first-open branch — re-opening
  /// an existing conversation explicitly does **not** re-speak, which this
  /// mirrors via the same "no-op once any message exists" guard). A no-op
  /// once any message exists, so reopening the panel later never re-greets
  /// or re-speaks.
  void ensureGreeted(String greeting) {
    if (state.messages.isNotEmpty) return;
    state = state.copyWith(messages: [AriaChatMessage(role: AriaMessageRole.assistant, content: greeting)]);
    unawaited(_autoSpeak(greeting));
  }

  /// A tap on one of the persistent welcome panel's "predefined question"
  /// cards (`AriaWelcomeCardsPanel` — see its own doc comment, and
  /// `aria_welcome_card.dart`'s for where this feature comes from) — mirrors
  /// `runWelcomeAction()` (`static/js/BOTscript.js`): the card's own
  /// (localized) [questionText] is added as if the user had typed and sent
  /// it, [replyText] (the card's answer plus an "Opening X." confirmation —
  /// see `buildAriaWelcomeReply`) is added as the assistant's turn, and
  /// [action] is spoken then navigated to once speech finishes — the exact
  /// same [_autoSpeak]/[_onPlaybackComplete] pipeline [sendMessage]'s own
  /// completion branch already drives, just without a real network call:
  /// a card already knows its own answer, so (like the real web) this never
  /// touches `/api/riya/chat/` at all.
  void tapWelcomeCard({required String questionText, required String replyText, required AriaChatAction action}) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        AriaChatMessage(role: AriaMessageRole.user, content: questionText),
        AriaChatMessage(role: AriaMessageRole.assistant, content: replyText, actions: [action]),
      ],
    );
    unawaited(_autoSpeak(replyText, navigateTo: action));
  }

  /// The header's manual language dropdown (`#chatbotLanguageSelect`) —
  /// writes the exact same [AriaChatState.language] field the `<LANG:code>`
  /// auto-detect path already writes (see [_stripLanguageDirective]). The
  /// real web has no separate "manual vs. auto" precedence system either:
  /// both paths mutate the identical `<select>.value`/`sessionStorage`
  /// key, so whichever happened most recently simply wins — reproduced
  /// here the same way, by both paths writing the same single field.
  ///
  /// Mirrors the real web's one confirmed side effect of changing language
  /// (`BOTscript.js`'s `langSelect.addEventListener('change', ...)`):
  /// an in-progress recording is cancelled, not transcribed — the real
  /// handler stops both `SpeechRecognition` and `MediaRecorder` with a
  /// `"language_change"` reason and marks that turn as already handled so
  /// nothing gets transcribed from it. **Deliberately does not** touch an
  /// in-flight streaming reply or in-progress TTS playback — the real
  /// handler doesn't touch either of those (it only ever reads/stops mic
  /// state), so the next message/utterance simply picks up the new
  /// language naturally, same as here.
  void setLanguage(String code) {
    if (code == state.language) return;
    state = state.copyWith(language: code);
    if (state.voiceStatus == AriaVoiceStatus.recording) {
      unawaited(cancelRecording());
    }
  }

  /// Sends [text] over the real web's actual default chat path
  /// (`ApiEndpoints.riyaChatStream` — see its doc comment), appending the
  /// user's turn immediately, growing [AriaChatState.streamingText] as
  /// `{"t": ...}` events arrive, then replacing it with a finished
  /// [AriaChatMessage] once the complete event lands (or a friendly local
  /// error turn if the stream fails). [page]/[path] are the caller's
  /// best-effort current-screen identifiers (see `BuddyChatbotOverlay`'s
  /// route-resolution helper) and [isEmployer] mirrors the current auth
  /// state — both sent for contract fidelity, even though the live view
  /// actually recomputes `is_employer` itself from the session (see
  /// `ApiEndpoints.riyaChat`'s doc comment).
  ///
  /// Guarded by [AriaChatState.sending] the same way the non-streaming path
  /// was — a send already in flight blocks a second one, matching the real
  /// page's own single-flight chat input.
  Future<void> sendMessage(
    String text, {
    required String page,
    required String path,
    required bool isEmployer,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    // History sent to the server is every turn that existed *before* this
    // one — captured before the user's new message is appended locally.
    final history = state.messages;

    state = state.copyWith(
      messages: [...state.messages, AriaChatMessage(role: AriaMessageRole.user, content: trimmed)],
      sending: true,
      clearStreamingText: true,
    );

    var buffer = '';
    var detectedLanguage = state.language;
    try {
      final events = ref
          .read(ariaRemoteDataSourceProvider)
          .sendMessageStream(
            message: trimmed,
            page: page,
            path: path,
            isEmployer: isEmployer,
            conversationId: state.conversationId,
            history: history,
            language: state.language,
          );

      await for (final event in events) {
        switch (event) {
          case AriaStreamToken(:final raw):
            buffer += raw;
            final displayText = _stripLanguageDirective(buffer, onDetected: (lang) => detectedLanguage = lang);
            state = state.copyWith(streamingText: displayText, language: detectedLanguage);
          case AriaStreamComplete(:final reply):
            state = state.copyWith(
              messages: [
                ...state.messages,
                AriaChatMessage(role: AriaMessageRole.assistant, content: reply.reply, actions: reply.actions),
              ],
              sending: false,
              clearStreamingText: true,
              language: detectedLanguage,
            );
            // "Navigation now flows through afterSpeak: Riya speaks the
            // confirmation first, then navigates (voice output for every
            // response, including typed)" — a verbatim comment directly
            // above the real web's own unconditional `speak: true` on this
            // exact completion event (`requestAssistantReplyStream`,
            // `BOTscript.js`). Not gated on how the user's turn was sent.
            //
            // Same eligibility rule as the real main widget's own
            // `commitNavigation` call site: exactly one action, and only
            // for a reply whose `source` is `"intent"` or `"skillup"` (an
            // `"ai"`/`"fallback"` reply's action — if any — is never
            // auto-navigated on the real web either).
            final navigateTo = reply.actions.length == 1 && (reply.source == 'intent' || reply.source == 'skillup')
                ? reply.actions.single
                : null;
            unawaited(_autoSpeak(reply.reply, navigateTo: navigateTo));
        }
      }
    } catch (_) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          const AriaChatMessage(role: AriaMessageRole.assistant, content: _unreachableMessage, isError: true),
        ],
        sending: false,
        clearStreamingText: true,
      );
    }
  }

  /// Tap-to-start the mic — mirrors `initializeMediaRecorder`'s permission
  /// prompt (`BOTscript.js`). A no-op unless currently idle, so a second
  /// tap while already recording/transcribing can't start a second
  /// recording from under the first.
  Future<void> startRecording() async {
    if (state.voiceStatus != AriaVoiceStatus.idle) return;
    final granted = await _safeVoiceCall(_recorder.hasPermission) ?? false;
    if (!granted) {
      state = state.copyWith(
        voiceError: 'Microphone access denied. Please allow microphone access and try again.',
      );
      return;
    }
    final started = await _safeVoiceCall(() async {
      await _recorder.start();
      return true;
    });
    if (started != true) {
      state = state.copyWith(voiceError: "Couldn't start recording. Please try again.");
      return;
    }
    state = state.copyWith(voiceStatus: AriaVoiceStatus.recording, clearVoiceError: true);
  }

  /// Tap-to-cancel while recording — discards the in-progress recording
  /// without transcribing it, matching [AudioRecorderService.cancel]'s own
  /// "unsent recordings don't accumulate on device storage" contract.
  Future<void> cancelRecording() async {
    if (state.voiceStatus != AriaVoiceStatus.recording) return;
    await _safeVoiceCall(_recorder.cancel);
    state = state.copyWith(voiceStatus: AriaVoiceStatus.idle);
  }

  /// Tap-to-stop — uploads the recording to
  /// `ApiEndpoints.riyaVoiceTranscribe` and, once transcribed, **sends it
  /// as the user's next message immediately** — the same pipeline
  /// [sendMessage] already drives for typed text.
  ///
  /// **Deliberately auto-sends, which is not this feature's obvious
  /// default** — confirmed by direct re-reading of `BOTscript.js`'s
  /// `MediaRecorder.onstop` handler: it calls
  /// `processTranscript(payload.text, "voice")`, and `processTranscript` is
  /// the exact same single entry point typed messages go through on their
  /// way to `requestAssistantReplyStream` — there is no "fill the box,
  /// wait for Send" step on the real web for voice input at all. Filling
  /// the composer and waiting would be a plausible, reasonable mobile
  /// design, but it would not be what this task asked for ("do NOT
  /// auto-send unless the web actually does so" — the web does).
  Future<void> stopRecordingAndSend({required String page, required String path, required bool isEmployer}) async {
    if (state.voiceStatus != AriaVoiceStatus.recording) return;
    final recordedPath = await _safeVoiceCall(_recorder.stop);
    if (recordedPath == null) {
      state = state.copyWith(voiceStatus: AriaVoiceStatus.idle, voiceError: 'Recording was too short. Please try again.');
      return;
    }

    state = state.copyWith(voiceStatus: AriaVoiceStatus.transcribing);
    String? transcript;
    try {
      final bytes = await File(recordedPath).readAsBytes();
      // 'audio/wav', matching `ariaAudioRecorderServiceProvider`'s WAV
      // encoder — see that provider's doc comment for why ARIA deliberately
      // doesn't use this app's usual m4a recording format.
      final transcription = await ref
          .read(ariaRemoteDataSourceProvider)
          .transcribeVoice(audioBase64: base64Encode(bytes), mimeType: 'audio/wav', language: state.language);
      transcript = transcription.text;
    } catch (_) {
      transcript = null;
    } finally {
      // Never retained on device beyond the single upload — see this
      // task's Security/Privacy requirement not to store production audio
      // unnecessarily.
      try {
        await File(recordedPath).delete();
      } catch (_) {
        // Best-effort cleanup only; a failed delete doesn't affect the
        // transcription result already handled above.
      }
    }

    if (transcript == null) {
      state = state.copyWith(
        voiceStatus: AriaVoiceStatus.idle,
        voiceError: "Couldn't transcribe your recording. Please try again.",
      );
      return;
    }
    if (transcript.trim().isEmpty) {
      state = state.copyWith(voiceStatus: AriaVoiceStatus.idle, voiceError: "Couldn't hear anything. Please try again.");
      return;
    }

    state = state.copyWith(voiceStatus: AriaVoiceStatus.idle, clearVoiceError: true);
    await sendMessage(transcript, page: page, path: path, isEmployer: isEmployer);
  }

  /// The header speaker button's tap handler — idle replays
  /// [_lastAssistantReplyText] from the start, loading/speaking stops.
  /// **Deliberately only two tappable outcomes, not the real web's
  /// three** — see [AriaSpeakerState]'s doc comment.
  void toggleSpeaker() {
    if (state.speakerState == AriaSpeakerState.idle) {
      final text = _lastAssistantReplyText;
      if (text != null) unawaited(_autoSpeak(text));
      return;
    }
    stopSpeaking();
  }

  /// Also called when the panel closes, so a spoken reply never keeps
  /// talking in the background after the user navigates away.
  void stopSpeaking() {
    if (state.speakerState == AriaSpeakerState.idle) return;
    _speakGeneration++;
    unawaited(_safeVoiceCall(_playback.stop));
    state = state.copyWith(speakerState: AriaSpeakerState.idle);
  }

  /// Speaks [text] through real server audio (`ApiEndpoints.riyaTts`),
  /// falling back to on-device synthesis when the server has none to offer
  /// — same decision tree as the real web's own `speakText()`
  /// `.catch(() => speakWithBrowser(text))`. Called automatically after
  /// every assistant reply (see [sendMessage]) and after the greeting (see
  /// [ensureGreeted]) — never gated on how the turn was sent, matching the
  /// real web's own "voice output for every response, including typed."
  ///
  /// Guarded by [_speakGeneration] so a still-in-flight continuation from a
  /// *previous* utterance (its network call landing late, say) recognizes
  /// a newer one has since started or [stopSpeaking] was called, and never
  /// clobbers state that no longer belongs to it.
  ///
  /// [navigateTo], when given, is resolved by [_onPlaybackComplete] once
  /// this utterance actually finishes playing — see
  /// [_pendingNavigationAction]'s doc comment. If [text] is empty (nothing
  /// to speak, so [_onPlaybackComplete] will never fire for this call) it
  /// is resolved immediately instead, so a navigable reply never silently
  /// loses its navigation just because it had no audio to accompany it.
  Future<void> _autoSpeak(String text, {AriaChatAction? navigateTo}) async {
    if (text.trim().isEmpty) {
      _resolveNavigation(navigateTo);
      return;
    }
    _lastAssistantReplyText = text;
    _pendingNavigationAction = navigateTo;

    final generation = ++_speakGeneration;
    await _safeVoiceCall(_playback.stop);
    if (generation != _speakGeneration) return;

    state = state.copyWith(speakerState: AriaSpeakerState.loading);
    String? audio;
    try {
      audio = await ref.read(ariaRemoteDataSourceProvider).synthesizeSpeech(text: text, language: state.language);
    } catch (_) {
      audio = null;
    }
    if (generation != _speakGeneration) return;

    state = state.copyWith(speakerState: AriaSpeakerState.speaking);
    var played = false;
    if (audio != null) played = await _safeVoiceCall(() => _playback.playAudioBytes(audio!)) ?? false;
    if (generation != _speakGeneration) return;
    // Nothing played (no server audio, or on-device synthesis itself
    // failed, e.g. no TTS voices installed) — fail silently into idle
    // rather than leaving the header speaker button stuck mid-state; the
    // reply text is already visible in the transcript either way.
    if (!played) await _safeVoiceCall(() => _playback.speakDeviceVoice(text));
    if (generation != _speakGeneration) return;
  }

  /// Every [_recorder]/[_playback] call goes through here — a platform
  /// plugin failure (microphone unavailable, audio focus denied, no TTS
  /// voices installed, running in a test harness with no real platform
  /// channel) must never leave the chat stuck mid-recording/mid-speaking,
  /// per this task's own "never get stuck" requirement. Returns `null`
  /// (never throws) on any failure, so every call site can treat `null` as
  /// "this step didn't happen, fail gracefully" the same way a `null`
  /// normal result (e.g. "no recording"/"no audio") already is.
  Future<T?> _safeVoiceCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
    }
  }

  void _onPlaybackComplete() {
    _speakGeneration++;
    state = state.copyWith(speakerState: AriaSpeakerState.idle);
    _resolveNavigation(_pendingNavigationAction);
  }

  /// Resolves (consumes) a pending auto-navigation [action], bumping
  /// [AriaChatState.navigationGeneration] so the UI layer's listener
  /// edge-triggers exactly once — see [AriaChatState.pendingNavigation]'s
  /// doc comment. A no-op for `null` (nothing to navigate to), which is the
  /// common case (most replies carry no action, or more than one).
  void _resolveNavigation(AriaChatAction? action) {
    _pendingNavigationAction = null;
    if (action == null) return;
    state = state.copyWith(pendingNavigation: action, navigationGeneration: state.navigationGeneration + 1);
  }

  /// Strips a `<LANG:code>` directive out of [text] (wherever it appears,
  /// matching the real web's own regex interception — see this file's
  /// `_langDirectivePattern` doc comment) and reports the detected code via
  /// [onDetected] if one was found.
  static String _stripLanguageDirective(String text, {required void Function(String language) onDetected}) {
    final match = _langDirectivePattern.firstMatch(text);
    if (match == null) return text;
    onDetected(match.group(1)!.toLowerCase());
    return text.replaceAll(_langDirectivePattern, '').trim();
  }

  /// Computes the "Hello {FirstName}!" / "Hello there! Job seeker or
  /// employer?" greeting, mirroring `riya_bot/views.py:_speakable_user_name`
  /// as closely as this app's [AuthUser] allows — that server helper reads
  /// `first_name`/`username`, which this app doesn't have separately (see
  /// `AuthUser`'s own doc comment: no profile endpoint, only whatever was
  /// submitted at login), so [AuthUser.username] stands in for both.
  static String greetingFor(AuthState authState) {
    if (authState is! AuthAuthenticated) {
      return 'Hello there! Job seeker or employer?';
    }
    var raw = authState.user.username.trim();
    if (raw.isEmpty) return 'Hello there!';
    if (raw.contains('@')) raw = raw.split('@').first;
    raw = raw.replaceAll(RegExp(r'[._\-\d]+'), ' ').trim();
    final tokens = raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (tokens.isEmpty) return 'Hello there!';
    final firstToken = tokens.first;
    final capitalized = firstToken[0].toUpperCase() + firstToken.substring(1).toLowerCase();
    return 'Hello $capitalized!';
  }
}

final ariaChatControllerProvider = NotifierProvider<AriaChatController, AriaChatState>(AriaChatController.new);
