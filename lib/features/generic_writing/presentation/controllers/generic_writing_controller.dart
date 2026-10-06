import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/generic_writing_exercise.dart';
import '../../domain/entities/generic_writing_submission_result.dart';
import '../../domain/entities/writing_prompt.dart';
import '../../domain/services/writing_client_scorer.dart';
import '../../domain/services/writing_limits.dart';
import '../../domain/services/writing_word_count.dart';
import '../providers/generic_writing_providers.dart';

/// Mirrors `FillBlankExerciseController`/`MatchingExerciseController`'s
/// sealed state shape, adapted for Generic Writing's own interaction model:
/// every prompt is visible and editable simultaneously
/// (`initWriting()`, `static/js/exercises.js:731-1108`) — there is a single
/// Submit button gated on every prompt's live word count, not a per-prompt
/// Check button like Fill in the Blank.
sealed class GenericWritingState {
  const GenericWritingState();
}

final class GenericWritingLoading extends GenericWritingState {
  const GenericWritingLoading();
}

final class GenericWritingLoadFailed extends GenericWritingState {
  const GenericWritingLoadFailed(this.failure);
  final Failure failure;
}

/// The user is drafting responses. Every prompt starts empty and remains
/// editable up to submission — unlike Fill in the Blank, nothing ever
/// locks (the web has no per-prompt "Check", only a single final Submit).
final class GenericWritingInProgress extends GenericWritingState {
  const GenericWritingInProgress({required this.exercise, this.drafts = const {}, this.isSubmitting = false, this.submitError});

  final GenericWritingExercise exercise;

  /// position -> current textarea value (untrimmed, live as typed).
  final Map<int, String> drafts;
  final bool isSubmitting;
  final Failure? submitError;

  String draftFor(int position) => drafts[position] ?? '';
  int wordCountFor(int position) => countWritingWords(draftFor(position));
  WritingLimits limitsFor(WritingPrompt prompt) => exercise.limitsFor(prompt);

  bool isValid(WritingPrompt prompt) {
    final words = wordCountFor(prompt.position);
    final limits = limitsFor(prompt);
    if (words < limits.min) return false;
    if (limits.max != null && words > limits.max!) return false;
    return true;
  }

  /// Gates "Submit Writing" — mirrors `refreshWritingState()`'s
  /// `requirementsMet` (`static/js/exercises.js:759-802`): every prompt's
  /// live word count must fall within its own min/max range. An exercise
  /// with no prompts is never submittable either
  /// (`requirementsMet = prompts.length > 0`,
  /// `static/js/exercises.js:760`).
  bool get allValid => exercise.prompts.isNotEmpty && exercise.prompts.every(isValid);

  GenericWritingInProgress copyWith({
    Map<int, String>? drafts,
    bool? isSubmitting,
    Failure? submitError,
    bool clearSubmitError = false,
  }) {
    return GenericWritingInProgress(
      exercise: exercise,
      drafts: drafts ?? this.drafts,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

final class GenericWritingSubmitted extends GenericWritingState {
  const GenericWritingSubmitted({required this.exercise, required this.drafts, required this.result});
  final GenericWritingExercise exercise;
  final Map<int, String> drafts;
  final GenericWritingSubmissionResult result;
}

class GenericWritingController extends Notifier<GenericWritingState> {
  GenericWritingController(this.arg);

  /// (exerciseId, title, order) — a record, passed straight to this
  /// constructor by [NotifierProvider.family] — same pattern as
  /// `FillBlankExerciseController`/`MatchingExerciseController`.
  final (int, String, int) arg;

  int get exerciseId => arg.$1;
  String get title => arg.$2;
  int get order => arg.$3;

  @override
  GenericWritingState build() {
    _load();
    return const GenericWritingLoading();
  }

  Future<void> _load() async {
    final result = await ref
        .read(genericWritingRepositoryProvider)
        .getGenericWritingExercise(exerciseId, title: title, order: order);
    state = switch (result) {
      Success(value: final exercise) => GenericWritingInProgress(exercise: exercise),
      Failed(failure: final failure) => GenericWritingLoadFailed(failure),
    };
  }

  Future<void> retryLoad() async {
    state = const GenericWritingLoading();
    await _load();
  }

  /// Full re-run of the flow — mirrors the web's "Try Again"
  /// (`onclick="location.reload()"`), a full page reload that resets every
  /// draft back to empty. Deliberately re-fetches rather than merely
  /// clearing local state, matching
  /// `FillBlankExerciseController.tryAgain`'s own reasoning.
  Future<void> tryAgain() async {
    state = const GenericWritingLoading();
    await _load();
  }

  /// Mirrors a textarea's `input` listener
  /// (`static/js/exercises.js:804-806`) — updates live word count/
  /// validation on every keystroke.
  void updateDraft(int position, String text) {
    final current = state;
    if (current is! GenericWritingInProgress || current.isSubmitting) return;
    state = current.copyWith(drafts: {...current.drafts, position: text}, clearSubmitError: true);
  }

  Future<void> submit() async {
    final current = state;
    if (current is! GenericWritingInProgress || current.isSubmitting || !current.allValid) return;

    state = current.copyWith(isSubmitting: true, clearSubmitError: true);

    final score = computeGenericWritingClientScore(
      exerciseTitle: current.exercise.title,
      answers: [
        for (final prompt in current.exercise.prompts)
          WritingScoreInput(text: current.draftFor(prompt.position), questionText: prompt.questionText, guide: prompt.guide),
      ],
    );
    // `answers[q] = text` where `text = ta.value.trim()`
    // (`static/js/exercises.js:847,850`) — the stored answer is trimmed.
    final answers = {for (final prompt in current.exercise.prompts) prompt.position: current.draftFor(prompt.position).trim()};

    final result = await ref
        .read(genericWritingRepositoryProvider)
        .submitGenericWritingExercise(current.exercise.id, score: score, maxScore: 100, answers: answers);

    state = switch (result) {
      Success(value: final submissionResult) => GenericWritingSubmitted(
        exercise: current.exercise,
        drafts: current.drafts,
        result: submissionResult,
      ),
      Failed(failure: final failure) => current.copyWith(isSubmitting: false, submitError: failure),
    };
  }
}

final genericWritingControllerProvider =
    NotifierProvider.family<GenericWritingController, GenericWritingState, (int, String, int)>(GenericWritingController.new);
