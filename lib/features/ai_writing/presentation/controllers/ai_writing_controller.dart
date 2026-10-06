import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/writing_analysis_result.dart';
import '../../domain/entities/writing_topic.dart';
import '../../domain/services/writing_text_formatting.dart';
import '../../domain/services/writing_validation.dart';
import '../providers/ai_writing_providers.dart';

/// AI Writing's actual web flow (`writing.html` + `writing.js`, read in
/// full) is a **single, continuous page**, unlike AI Speaking's exclusive
/// state-machine screens: the writing textarea and topic stay visible and
/// editable at all times, and the evaluation cards simply appear below
/// once a successful analysis exists — the user can keep editing and
/// resubmitting indefinitely without any explicit "Try Again" action.
/// This controller mirrors that: [WritingResult]/[WritingSubmitFailed]
/// don't replace [WritingIdle] the way `AiSpeakingResult` replaces the
/// recorder card — the caller (`AiWritingScreen`) shows the writing input
/// unconditionally and layers the result/error below it.
///
/// The raw text itself deliberately lives in the screen's own
/// `TextEditingController`, not in this controller's state — matching how
/// the web keeps it in the DOM textarea rather than re-rendering it from
/// JS state on every keystroke.
///
/// Deliberately does **not** reproduce:
/// - The 4-language cosmetic label overlay for Vietnamese/Russian (Arabic
///   has no translation branch in `writing.js` at all) — `language` is
///   still sent to the server for real (it affects the AI's feedback
///   language), only the decorative re-labelling is skipped, same
///   decision as `AiSpeakingController`.
/// - The client-side `computeWritingScore` fallback used only when
///   `score_25` is absent from a successful response — confirmed dead in
///   practice: `analyze_writing` always sets it for every authenticated
///   (i.e. reachable) request, per `activities/views.py:1745`.
/// - The one-exercise-only server-side 150-200 *word* rule for "Proposal
///   Section Writing" (`activities/views.py:1707-1716`) — a title-matched
///   special case with no client-visible signal before submission, exactly
///   the same category of decision as `AiSpeakingController` skipping
///   `isElevatorPitchTimed`. The server still enforces it; a submission
///   that violates it surfaces as a normal, retryable failure.
sealed class WritingState {
  const WritingState({required this.topic, required this.writingType});
  final String topic;

  /// `'general' | 'story' | 'opinion'` — `typeSelect`'s value.
  final String writingType;
}

final class WritingIdle extends WritingState {
  const WritingIdle({required super.topic, required super.writingType});
}

final class WritingSubmitting extends WritingState {
  const WritingSubmitting({required super.topic, required super.writingType});
}

final class WritingResult extends WritingState {
  const WritingResult({required super.topic, required super.writingType, required this.result});
  final WritingAnalysisResult result;
}

final class WritingSubmitFailed extends WritingState {
  const WritingSubmitFailed({required super.topic, required super.writingType, required this.failure});
  final Failure failure;
}

class AiWritingController extends Notifier<WritingState> {
  AiWritingController(this.exerciseId);

  final int exerciseId;

  final Random _random = Random();
  final Map<String, List<String>> _remainingTopicsByType = {};
  String _language = 'english';

  /// Mirrors `window.lastImprovedPassage` — the most recent successful
  /// analysis's (formatted) improved passage, resent as
  /// `previous_improved_passage` on the next submission so the server can
  /// penalise a resubmission that's just a copy of its own last
  /// suggestion. Persists across submissions for the lifetime of this
  /// controller, exactly like the web's page-level JS variable.
  String? _lastImprovedPassage;

  @override
  WritingState build() {
    // Same "exclude the current/initial topic from its own pool" seeding
    // as `refillTopicPool(typeSelect.value, topicText.textContent)` at the
    // bottom of writing.js's IIFE.
    _remainingTopicsByType[kWritingDefaultType] = (kWritingTopicsByType[kWritingDefaultType] ?? const [])
        .where((t) => t != kWritingInitialTopic)
        .toList();
    return const WritingIdle(topic: kWritingInitialTopic, writingType: kWritingDefaultType);
  }

  void setLanguage(String language) => _language = language;

  /// "New Topic" (`getNextTopic()`, `writing.js:188-199`) — picks a random
  /// not-yet-seen topic from the *current* type's pool, refilling
  /// (excluding the current one) once exhausted. Never changes the type.
  void pickNewTopic() {
    final type = state.writingType;
    final currentTopic = state.topic;
    var pool = _remainingTopicsByType[type];
    if (pool == null || pool.isEmpty) {
      pool = (kWritingTopicsByType[type] ?? const []).where((t) => t != currentTopic).toList();
      _remainingTopicsByType[type] = pool;
    }
    if (pool.isEmpty) {
      state = WritingIdle(topic: currentTopic, writingType: type);
      return;
    }
    final next = pool.removeAt(_random.nextInt(pool.length));
    state = WritingIdle(topic: next, writingType: type);
  }

  /// `typeSelect`'s `change` handler (`writing.js:432-435`) — switching
  /// type always refills that type's pool fresh (no exclusion) and picks a
  /// new topic from it, discarding any result/error the same as
  /// `resetCards()`.
  void setWritingType(String type) {
    final list = kWritingTopicsByType[type] ?? const [];
    final pool = List<String>.of(list);
    if (pool.isEmpty) {
      _remainingTopicsByType[type] = pool;
      state = WritingIdle(topic: state.topic, writingType: type);
      return;
    }
    final next = pool.removeAt(_random.nextInt(pool.length));
    _remainingTopicsByType[type] = pool;
    state = WritingIdle(topic: next, writingType: type);
  }

  /// Also used as retry from [WritingSubmitFailed] and as a plain
  /// re-analyze from [WritingResult] — the web allows resubmitting the
  /// (possibly edited) text at any time, not just once.
  Future<void> submit(String text) async {
    if (state is WritingSubmitting) return;
    if (!isWritingLengthValid(text)) return;

    final topic = state.topic;
    final type = state.writingType;
    state = WritingSubmitting(topic: topic, writingType: type);

    final result = await ref
        .read(aiWritingRepositoryProvider)
        .analyze(
          exerciseId: exerciseId,
          text: text,
          language: _language,
          referenceText: topic,
          previousImprovedPassage: _lastImprovedPassage,
        );

    switch (result) {
      case Success(value: final analysis):
        _lastImprovedPassage = formatImprovedPassage(analysis.improvedPassage);
        state = WritingResult(topic: topic, writingType: type, result: analysis);
      case Failed(failure: final failure):
        state = WritingSubmitFailed(topic: topic, writingType: type, failure: failure);
    }
  }
}

final aiWritingControllerProvider = NotifierProvider.family<AiWritingController, WritingState, int>(
  AiWritingController.new,
);
