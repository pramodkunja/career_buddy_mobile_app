import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/mcq_exercise.dart';
import '../../domain/entities/mcq_question_result.dart';
import '../../domain/entities/mcq_submission_result.dart';
import '../providers/activities_providers.dart';

/// Unlike the read-only list/detail screens (plain `AsyncNotifier` is
/// enough there — see `ActivityDetailController`), this screen has state
/// `AsyncValue` doesn't model: the in-flight answers a user is picking,
/// plus a submission that can independently be loading/failed while the
/// underlying exercise data stays loaded. A custom sealed state (same
/// reasoning as `AuthController`) makes each of those states explicit
/// instead of overloading one `AsyncValue`.
sealed class McqExerciseState {
  const McqExerciseState();
}

final class McqExerciseLoading extends McqExerciseState {
  const McqExerciseLoading();
}

final class McqExerciseLoadFailed extends McqExerciseState {
  const McqExerciseLoadFailed(this.failure);
  final Failure failure;
}

/// The user is answering questions. `isSubmitting`/`submitError` track the
/// submission attempt independently of the loaded exercise data, so a
/// failed submit doesn't lose the user's answers or force a reload.
final class McqExerciseInProgress extends McqExerciseState {
  const McqExerciseInProgress({required this.exercise, required this.selectedAnswers, this.isSubmitting = false, this.submitError});

  final McqExercise exercise;

  /// questionId -> selected option letter.
  final Map<int, String> selectedAnswers;
  final bool isSubmitting;
  final Failure? submitError;

  bool get allQuestionsAnswered => selectedAnswers.length == exercise.questions.length;

  McqExerciseInProgress copyWith({
    Map<int, String>? selectedAnswers,
    bool? isSubmitting,
    Failure? submitError,
    bool clearSubmitError = false,
  }) {
    return McqExerciseInProgress(
      exercise: exercise,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

final class McqExerciseSubmitted extends McqExerciseState {
  const McqExerciseSubmitted({required this.exercise, required this.result});
  final McqExercise exercise;
  final McqSubmissionResult result;
}

class McqExerciseController extends Notifier<McqExerciseState> {
  McqExerciseController(this.exerciseId);

  final int exerciseId;

  @override
  McqExerciseState build() {
    _load();
    return const McqExerciseLoading();
  }

  Future<void> _load() async {
    final result = await ref.read(mcqExerciseRepositoryProvider).getMcqExercise(exerciseId);
    state = switch (result) {
      Success(value: final exercise) => McqExerciseInProgress(exercise: exercise, selectedAnswers: const {}),
      Failed(failure: final failure) => McqExerciseLoadFailed(failure),
    };
  }

  Future<void> retryLoad() async {
    state = const McqExerciseLoading();
    await _load();
  }

  void selectAnswer(int questionId, String letter) {
    final current = state;
    if (current is! McqExerciseInProgress || current.isSubmitting) return;
    state = current.copyWith(
      selectedAnswers: {...current.selectedAnswers, questionId: letter},
      clearSubmitError: true,
    );
  }

  Future<void> submit() async {
    final current = state;
    // Mirrors the web's own "Submit disabled until every question is
    // answered" rule (`exercises.js`) — enforced here too, not only by the
    // UI disabling the button, so this can't be bypassed by calling
    // `submit()` directly.
    if (current is! McqExerciseInProgress || current.isSubmitting || !current.allQuestionsAnswered) return;

    state = current.copyWith(isSubmitting: true, clearSubmitError: true);

    // The server's `submit_exercise` endpoint doesn't grade MCQ itself —
    // it only ever echoes back whatever `score`/`max_score` it's sent (see
    // `McqSubmitEcho`'s doc comment) — so, like every other HTML-scraped
    // exercise type, this computes the authoritative score itself from
    // the question data the initial page load already carried.
    final exercise = current.exercise;
    final selected = current.selectedAnswers;
    final score = exercise.questions.where((q) => selected[q.id] == q.correctAnswer).length;
    final maxScore = exercise.questions.length;

    final result = await ref
        .read(mcqExerciseRepositoryProvider)
        .submitMcqExercise(exercise.id, score: score, maxScore: maxScore, answers: selected);

    state = switch (result) {
      Success(value: final echo) => McqExerciseSubmitted(
        exercise: exercise,
        result: McqSubmissionResult(
          exerciseId: exercise.id,
          score: echo.score,
          maxScore: echo.maxScore,
          percentage: echo.percentage,
          attemptNumber: echo.attemptNumber,
          questions: [
            for (final q in exercise.questions)
              McqQuestionResult(
                questionId: q.id,
                selected: selected[q.id],
                correct: q.correctAnswer,
                isCorrect: selected[q.id] == q.correctAnswer,
                explanation: q.explanation,
              ),
          ],
        ),
      ),
      Failed(failure: final failure) => current.copyWith(isSubmitting: false, submitError: failure),
    };
  }
}

final mcqExerciseControllerProvider = NotifierProvider.family<McqExerciseController, McqExerciseState, int>(
  McqExerciseController.new,
);
