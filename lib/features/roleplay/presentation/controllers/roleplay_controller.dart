import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../ai_speaking/domain/services/audio_recorder_service.dart';
import '../../data/roleplay_topics_data.dart';
import '../../domain/entities/roleplay_analysis_result.dart';
import '../../domain/entities/roleplay_generated_content.dart';
import '../../domain/entities/roleplay_topic.dart';
import '../../domain/services/roleplay_validation.dart';
import '../providers/roleplay_providers.dart';

/// Drives one Roleplay Workshop practice session for a single sub-feature
/// [topicSlug] (`storytelling`/`situations`/`roleplay`). Mirrors
/// `roleplay.html` + its inline JS (both read in full) as closely as a
/// server-driven Web Speech API flow can be mirrored without one:
///
/// - Setup (scenario prompt input + example chips) -> **one**
///   `roleplay_practice` call generates the session content once — this
///   part is genuinely single-shot, same as the web.
/// - The web then asks its 5 (or 3, offline-fallback) follow-up questions
///   one at a time, live-transcribing each spoken answer with the browser's
///   Web Speech API and concatenating a growing text transcript client-side
///   — genuinely multi-turn, but with **zero** extra network calls per
///   turn.
/// - This controller reproduces that same multi-turn *question* flow
///   client-side (advancing [RoleplayRecording.questionIndex] locally, no
///   network call per question) but — since Flutter has no Web Speech API
///   equivalent — records **one continuous audio take** spanning every
///   question instead of a live text transcript, then sends that single
///   recording to `analyze_roleplay` for server-side transcription +
///   scoring. So: **multi-turn on-screen, but still exactly one `generate`
///   call and one `analyze` call per session — never one call per
///   question**, matching the web's own call count exactly even though the
///   client-side mechanics of collecting each answer differ.
///
/// Not reproduced, and not silently faked: the real page's live per-answer
/// 15-word-minimum check (`speaking.js`'s `validateWordCount`) — that
/// requires a *live* transcript at record time, which only exists after
/// this app's server-side STT runs, i.e. after the whole session is already
/// submitted. No pause/resume either — `roleplay.html`'s own recording UI
/// has no pause control (unlike `speaking.html`'s), confirmed by reading
/// the template directly.
sealed class RoleplayState {
  const RoleplayState({required this.topicSlug});
  final String topicSlug;
}

final class RoleplaySetup extends RoleplayState {
  const RoleplaySetup({required super.topicSlug, this.promptText = '', this.validationError});
  final String promptText;

  /// Set when [RoleplayController.generate] rejects the prompt client-side
  /// (the Roleplay-only two-party check) without ever calling the server —
  /// mirrors the web's `alert(...)` in that same case.
  final String? validationError;
}

final class RoleplayGenerating extends RoleplayState {
  const RoleplayGenerating({required super.topicSlug, required this.promptText});
  final String promptText;
}

/// A `roleplay_practice` failure that was specifically a plan/access denial
/// (`ForbiddenFailure`, HTTP 403 — `_can_access_workshop` returned false).
/// Kept distinct from [RoleplayGenerateFailed] so the screen can show the
/// same "upgrade required" treatment `ActivityDetailScreen`'s own
/// `_LockedState` uses, instead of a generic retry error.
final class RoleplayLocked extends RoleplayState {
  const RoleplayLocked({required super.topicSlug, required this.promptText, required this.message});
  final String promptText;
  final String message;
}

final class RoleplayGenerateFailed extends RoleplayState {
  const RoleplayGenerateFailed({required super.topicSlug, required this.promptText, required this.failure});
  final String promptText;
  final Failure failure;
}

/// The generated content is ready to read (`#reading-stage`) before
/// questions begin.
final class RoleplayReading extends RoleplayState {
  const RoleplayReading({required super.topicSlug, required this.content, this.micErrorMessage});
  final RoleplayGeneratedContent content;
  final String? micErrorMessage;
}

/// One continuous recording spans every question — see this file's top doc
/// comment. [questionIndex] is which of `content.followUps` is currently
/// being shown/answered.
final class RoleplayRecording extends RoleplayState {
  const RoleplayRecording({
    required super.topicSlug,
    required this.content,
    required this.questionIndex,
    required this.elapsedSeconds,
  });

  final RoleplayGeneratedContent content;
  final int questionIndex;
  final int elapsedSeconds;

  bool get isLastQuestion => questionIndex >= content.followUps.length - 1;

  RoleplayRecording copyWith({int? questionIndex, int? elapsedSeconds}) {
    return RoleplayRecording(
      topicSlug: topicSlug,
      content: content,
      questionIndex: questionIndex ?? this.questionIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

final class RoleplaySubmitting extends RoleplayState {
  const RoleplaySubmitting({
    required super.topicSlug,
    required this.content,
    required this.audioFilePath,
    required this.elapsedSeconds,
  });
  final RoleplayGeneratedContent content;
  final String audioFilePath;
  final int elapsedSeconds;
}

/// Preserves the recording so [RoleplayController.retryAnalysis] can resend
/// the exact same file without re-recording — same resilience pattern as
/// `AiSpeakingSubmitFailed`.
final class RoleplaySubmitFailed extends RoleplayState {
  const RoleplaySubmitFailed({
    required super.topicSlug,
    required this.content,
    required this.audioFilePath,
    required this.elapsedSeconds,
    required this.failure,
  });
  final RoleplayGeneratedContent content;
  final String audioFilePath;
  final int elapsedSeconds;
  final Failure failure;
}

final class RoleplayResult extends RoleplayState {
  const RoleplayResult({required super.topicSlug, required this.content, required this.result});
  final RoleplayGeneratedContent content;
  final RoleplayAnalysisResult result;
}

class RoleplayController extends Notifier<RoleplayState> {
  RoleplayController(this.topicSlug);

  final String topicSlug;

  late final AudioRecorderService _recorder;
  Timer? _timer;
  String _language = 'english';

  @override
  RoleplayState build() {
    _recorder = ref.read(roleplayAudioRecorderServiceProvider);
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_recorder.cancel());
    });
    return RoleplaySetup(topicSlug: topicSlug);
  }

  RoleplayTopic get _topic => RoleplayTopicsData.bySlug(topicSlug)!;

  void setLanguage(String language) => _language = language;

  void updatePrompt(String value) {
    final current = state;
    switch (current) {
      case RoleplaySetup():
        state = RoleplaySetup(topicSlug: topicSlug, promptText: value);
      case RoleplayGenerateFailed():
        state = RoleplaySetup(topicSlug: topicSlug, promptText: value);
      case RoleplayLocked():
        state = RoleplaySetup(topicSlug: topicSlug, promptText: value);
      default:
        return;
    }
  }

  /// "Create Session" (`start-btn`'s click handler, `roleplay.html:525-567`).
  Future<void> generate() async {
    final current = state;
    final String promptText;
    switch (current) {
      case RoleplaySetup():
        promptText = current.promptText;
      case RoleplayGenerateFailed():
        promptText = current.promptText;
      case RoleplayLocked():
        promptText = current.promptText;
      default:
        return;
    }

    final prompt = promptText.trim();
    if (_topic.slug == 'roleplay' && roleplayPromptMissingSecondCharacter(prompt)) {
      state = RoleplaySetup(
        topicSlug: topicSlug,
        promptText: promptText,
        validationError: 'Please provide another character to start the roleplay.',
      );
      return;
    }

    state = RoleplayGenerating(topicSlug: topicSlug, promptText: promptText);
    final result = await ref
        .read(roleplayRepositoryProvider)
        .generatePractice(topicSlug: topicSlug, prompt: prompt, language: _language);

    switch (result) {
      case Success(value: final content):
        // `roleplay.html:550,553` — the web explicitly guards this exact
        // case (`if (questions.length === 0) throw new Error("No questions
        // generated")`) rather than entering the reading/recording stage,
        // since a later `followUps[questionIndex]` access would otherwise
        // be unguarded. Mirrors that guard here instead of assuming the AI
        // response always contains at least one follow-up.
        if (content.followUps.isEmpty) {
          state = RoleplayGenerateFailed(
            topicSlug: topicSlug,
            promptText: promptText,
            failure: const UnexpectedFailure('No questions were generated. Please try again.'),
          );
        } else {
          state = RoleplayReading(topicSlug: topicSlug, content: content);
        }
      case Failed(failure: final failure):
        if (failure is ForbiddenFailure) {
          state = RoleplayLocked(topicSlug: topicSlug, promptText: promptText, message: failure.message);
        } else {
          state = RoleplayGenerateFailed(topicSlug: topicSlug, promptText: promptText, failure: failure);
        }
    }
  }

  /// "I'm Ready - Start Questions" (`ready-btn`, `roleplay.html:569-573`) —
  /// starts the single continuous recording covering every question.
  Future<void> startQuestions() async {
    final current = state;
    if (current is! RoleplayReading) return;
    final granted = await _recorder.hasPermission();
    if (!granted) {
      state = RoleplayReading(
        topicSlug: topicSlug,
        content: current.content,
        micErrorMessage: 'Microphone access denied. Please allow microphone access in your device settings and try again.',
      );
      return;
    }
    await _recorder.start();
    state = RoleplayRecording(topicSlug: topicSlug, content: current.content, questionIndex: 0, elapsedSeconds: 0);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state;
      if (s is! RoleplayRecording) return;
      state = s.copyWith(elapsedSeconds: s.elapsedSeconds + 1);
    });
  }

  /// "Done - Next Question" (`done-btn`, `roleplay.html:636-672`) when not
  /// yet on the last question.
  void nextQuestion() {
    final current = state;
    if (current is! RoleplayRecording || current.isLastQuestion) return;
    state = current.copyWith(questionIndex: current.questionIndex + 1);
  }

  /// "Analyze Performance" (`analyze-btn`, `roleplay.html:674-701`) — stops
  /// the recording and submits it. Only meaningful once
  /// [RoleplayRecording.isLastQuestion] is true (the practice screen only
  /// shows this action then), but harmless to call earlier too.
  Future<void> finishAndAnalyze() async {
    final current = state;
    if (current is! RoleplayRecording) return;
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path == null) {
      state = RoleplayReading(
        topicSlug: topicSlug,
        content: current.content,
        micErrorMessage: 'Recording failed. Please try again.',
      );
      return;
    }
    await _submit(content: current.content, audioFilePath: path, elapsedSeconds: current.elapsedSeconds);
  }

  /// Retry from [RoleplaySubmitFailed] — resends the exact same recording.
  Future<void> retryAnalysis() async {
    final current = state;
    if (current is! RoleplaySubmitFailed) return;
    await _submit(content: current.content, audioFilePath: current.audioFilePath, elapsedSeconds: current.elapsedSeconds);
  }

  Future<void> _submit({
    required RoleplayGeneratedContent content,
    required String audioFilePath,
    required int elapsedSeconds,
  }) async {
    state = RoleplaySubmitting(topicSlug: topicSlug, content: content, audioFilePath: audioFilePath, elapsedSeconds: elapsedSeconds);

    // Mirrors `formData.append("topic", promptInput.value || "{{ active_topic }}")`
    // — the *scenario prompt*, not the slug, with the slug only as fallback.
    final usedPrompt = content.usedPrompt.trim();
    final topicLabel = usedPrompt.isNotEmpty ? usedPrompt : topicSlug;

    final result = await ref
        .read(roleplayRepositoryProvider)
        .analyze(
          topicLabel: topicLabel,
          audioFilePath: audioFilePath,
          durationSeconds: elapsedSeconds.toDouble(),
          pauseCount: 0,
          language: _language,
          referenceText: content.content,
        );

    switch (result) {
      case Success(value: final analysis):
        state = RoleplayResult(topicSlug: topicSlug, content: content, result: analysis);
      case Failed(failure: final failure):
        state = RoleplaySubmitFailed(
          topicSlug: topicSlug,
          content: content,
          audioFilePath: audioFilePath,
          elapsedSeconds: elapsedSeconds,
          failure: failure,
        );
    }
  }

  /// "Practice Again" (`location.reload()`, `roleplay.html:450-455`) —
  /// discards the whole session, back to an empty Setup on the same
  /// sub-feature.
  void tryAgain() {
    _timer?.cancel();
    state = RoleplaySetup(topicSlug: topicSlug);
  }
}

final roleplayControllerProvider = NotifierProvider.family<RoleplayController, RoleplayState, String>(
  RoleplayController.new,
);
