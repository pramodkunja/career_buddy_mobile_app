import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/fill_blank_exercise.dart';
import '../../domain/entities/fill_blank_submission_result.dart';
import '../providers/fill_blank_exercise_providers.dart';

/// Mirrors `McqExerciseController`/`MatchingExerciseController`'s sealed
/// state shape, adapted for Fill in the Blank's own, much simpler
/// interaction model: every question is visible and checkable
/// independently and simultaneously (see `initFillBlank()`,
/// `static/js/exercises.js:197-262`) — there is no "Ready"/round-sequence
/// phase like Bingo, no Start button, no progress bar, no timer.
sealed class FillBlankExerciseState {
  const FillBlankExerciseState();
}

final class FillBlankExerciseLoading extends FillBlankExerciseState {
  const FillBlankExerciseLoading();
}

final class FillBlankExerciseLoadFailed extends FillBlankExerciseState {
  const FillBlankExerciseLoadFailed(this.failure);
  final Failure failure;
}

/// One checked question's outcome. [given] is the **raw, untrimmed**
/// value the user typed — mirrors `answers[q] = { given: input.value,
/// ... }` (`static/js/exercises.js:226`), which stores `input.value`
/// verbatim even though the correctness comparison itself trims it.
typedef FillBlankCheckedResult = ({String given, bool isCorrect});

/// The user is answering questions. Every question starts unchecked and
/// editable; checking one locks it permanently (mirrors
/// `input.disabled = true; this.disabled = true;`,
/// `static/js/exercises.js:223-224` — there is no way back to editing a
/// checked question, by design).
final class FillBlankExerciseInProgress extends FillBlankExerciseState {
  const FillBlankExerciseInProgress({
    required this.exercise,
    this.checkedResults = const {},
    this.emptyErrorPositions = const {},
    this.isSubmitting = false,
    this.submitError,
  });

  final FillBlankExercise exercise;

  /// position -> what was typed + whether it graded correct. A position's
  /// presence here means that question is checked and permanently locked.
  final Map<int, FillBlankCheckedResult> checkedResults;

  /// Positions whose most recent Check attempt was empty — shows the
  /// inline "Please enter an answer first." error
  /// (`static/js/exercises.js:214-221`) without locking the question or
  /// counting it as checked. Cleared the moment that position is
  /// successfully checked (or re-attempted with input).
  final Set<int> emptyErrorPositions;
  final bool isSubmitting;
  final Failure? submitError;

  int get currentScore => checkedResults.values.where((r) => r.isCorrect).length;
  int get checkedCount => checkedResults.length;

  /// Gates "Submit All Answers" — every question **checked**, not every
  /// question **correct** (`checkedCount === inputs.length`,
  /// `static/js/exercises.js:251`). A fully-wrong-but-fully-checked
  /// exercise is submittable.
  bool get allChecked => checkedCount == exercise.questions.length;

  FillBlankExerciseInProgress copyWith({
    Map<int, FillBlankCheckedResult>? checkedResults,
    Set<int>? emptyErrorPositions,
    bool? isSubmitting,
    Failure? submitError,
    bool clearSubmitError = false,
  }) {
    return FillBlankExerciseInProgress(
      exercise: exercise,
      checkedResults: checkedResults ?? this.checkedResults,
      emptyErrorPositions: emptyErrorPositions ?? this.emptyErrorPositions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

final class FillBlankExerciseSubmitted extends FillBlankExerciseState {
  const FillBlankExerciseSubmitted({required this.exercise, required this.checkedResults, required this.result});
  final FillBlankExercise exercise;
  final Map<int, FillBlankCheckedResult> checkedResults;
  final FillBlankSubmissionResult result;
}

class FillBlankExerciseController extends Notifier<FillBlankExerciseState> {
  FillBlankExerciseController(this.arg);

  /// (exerciseId, title, order) — a record, passed straight to this
  /// constructor by [NotifierProvider.family] — same pattern as
  /// `MatchingExerciseController`/`BingoExerciseController`.
  final (int, String, int) arg;

  int get exerciseId => arg.$1;
  String get title => arg.$2;
  int get order => arg.$3;

  @override
  FillBlankExerciseState build() {
    _load();
    return const FillBlankExerciseLoading();
  }

  Future<void> _load() async {
    final result = await ref
        .read(fillBlankExerciseRepositoryProvider)
        .getFillBlankExercise(exerciseId, title: title, order: order);
    state = switch (result) {
      Success(value: final exercise) => FillBlankExerciseInProgress(exercise: exercise),
      Failed(failure: final failure) => FillBlankExerciseLoadFailed(failure),
    };
  }

  Future<void> retryLoad() async {
    state = const FillBlankExerciseLoading();
    await _load();
  }

  /// Full re-run of the flow — mirrors the web's "Try Again"
  /// (`onclick="location.reload()"`), a full page reload that resets
  /// every checked/locked question, every score, and every error back to
  /// the initial state. Deliberately re-fetches rather than merely
  /// clearing local state, matching `MatchingExerciseController.tryAgain`/
  /// `BingoExerciseController.start`'s own reasoning.
  Future<void> tryAgain() async {
    state = const FillBlankExerciseLoading();
    await _load();
  }

  /// Grades [givenRaw] against the question at [position] and locks it —
  /// mirrors `.check-fill-btn`'s click handler
  /// (`static/js/exercises.js:204-254`) exactly: an empty (after trim)
  /// answer shows an inline error and does **not** lock the question or
  /// count it as checked; any non-empty answer is graded via exact
  /// trimmed, case-insensitive comparison and locks permanently — no
  /// re-check is ever possible once a position appears in
  /// [FillBlankExerciseInProgress.checkedResults].
  void checkAnswer(int position, String givenRaw) {
    final current = state;
    if (current is! FillBlankExerciseInProgress || current.isSubmitting) return;
    if (current.checkedResults.containsKey(position)) return; // already locked

    if (givenRaw.trim().isEmpty) {
      state = current.copyWith(emptyErrorPositions: {...current.emptyErrorPositions, position});
      return;
    }

    final question = current.exercise.questions.firstWhere((q) => q.position == position);
    // `given.trim().toLowerCase() === correct.trim().toLowerCase()` —
    // exact match only. No partial credit, no punctuation normalization,
    // no fuzzy matching, no multiple accepted answers.
    final isCorrect = givenRaw.trim().toLowerCase() == question.correctAnswer.trim().toLowerCase();

    final updatedErrors = {...current.emptyErrorPositions}..remove(position);
    state = current.copyWith(
      checkedResults: {...current.checkedResults, position: (given: givenRaw, isCorrect: isCorrect)},
      emptyErrorPositions: updatedErrors,
      clearSubmitError: true,
    );
  }

  Future<void> submit() async {
    final current = state;
    if (current is! FillBlankExerciseInProgress || current.isSubmitting || !current.allChecked) return;

    state = current.copyWith(isSubmitting: true, clearSubmitError: true);
    final answers = {
      for (final entry in current.checkedResults.entries)
        entry.key: (
          given: entry.value.given,
          correct: current.exercise.questions.firstWhere((q) => q.position == entry.key).correctAnswer,
          isCorrect: entry.value.isCorrect,
        ),
    };
    final result = await ref
        .read(fillBlankExerciseRepositoryProvider)
        .submitFillBlankExercise(current.exercise.id, score: current.currentScore, maxScore: current.exercise.questions.length, answers: answers);

    state = switch (result) {
      Success(value: final submissionResult) => FillBlankExerciseSubmitted(
        exercise: current.exercise,
        checkedResults: current.checkedResults,
        result: submissionResult,
      ),
      Failed(failure: final failure) => current.copyWith(isSubmitting: false, submitError: failure),
    };
  }
}

final fillBlankExerciseControllerProvider =
    NotifierProvider.family<FillBlankExerciseController, FillBlankExerciseState, (int, String, int)>(
      FillBlankExerciseController.new,
    );
